/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-07
*/

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: migrations/Migration_EltaninOptimism.sol
*
* Latest source (may be newer): https://github.com/Synthetixio/synthetix/blob/master/contracts/migrations/Migration_EltaninOptimism.sol
* Docs: https://docs.synthetix.io/contracts/migrations/Migration_EltaninOptimism
*
* Contract Dependencies: 
*	- BaseMigration
*	- IAddressResolver
*	- IExchangeRates
*	- IFuturesMarketManager
*	- IPerpsV2MarketSettings
*	- ISystemStatus
*	- MixinPerpsV2MarketSettings
*	- MixinResolver
*	- MixinSystemSettings
*	- Owned
*	- ReentrancyGuard
* Libraries: 
*	- AddressSetLib
*	- SafeDecimalMath
*	- SafeMath
*
* MIT License
* ===========
*
* Copyright (c) 2023 Synthetix
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/



pragma solidity ^0.5.16;

// https://docs.synthetix.io/contracts/source/contracts/owned
contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
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


contract BaseMigration is Owned {
    constructor(address _owner) internal Owned(_owner) {}

    // safety value to return ownership (anyone can invoke)
    function returnOwnership(address forContract) public {
        bytes memory payload = abi.encodeWithSignature("nominateNewOwner(address)", owner);

        // solhint-disable avoid-low-level-calls
        (bool success, ) = forContract.call(payload);

        if (!success) {
            // then try legacy way
            bytes memory legacyPayload = abi.encodeWithSignature("nominateOwner(address)", owner);

            // solhint-disable avoid-low-level-calls
            (bool legacySuccess, ) = forContract.call(legacyPayload);

            require(legacySuccess, "Legacy nomination failed");
        }
    }
}


// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getSynth(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}


// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ISynth {
    // Views
    function currencyKey() external view returns (bytes32);

    function transferableSynths(address account) external view returns (uint);

    // Mutative functions
    function transferAndSettle(address to, uint value) external returns (bool);

    function transferFromAndSettle(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Restricted: used internally to Synthetix
    function burn(address account, uint amount) external;

    function issue(address account, uint amount) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/iissuer
interface IIssuer {
    // Views

    function allNetworksDebtInfo()
        external
        view
        returns (
            uint256 debt,
            uint256 sharesSupply,
            bool isStale
        );

    function anySynthOrSNXRateIsInvalid() external view returns (bool anyRateInvalid);

    function availableCurrencyKeys() external view returns (bytes32[] memory);

    function availableSynthCount() external view returns (uint);

    function availableSynths(uint index) external view returns (ISynth);

    function canBurnSynths(address account) external view returns (bool);

    function collateral(address account) external view returns (uint);

    function collateralisationRatio(address issuer) external view returns (uint);

    function collateralisationRatioAndAnyRatesInvalid(address _issuer)
        external
        view
        returns (uint cratio, bool anyRateIsInvalid);

    function debtBalanceOf(address issuer, bytes32 currencyKey) external view returns (uint debtBalance);

    function issuanceRatio() external view returns (uint);

    function lastIssueEvent(address account) external view returns (uint);

    function maxIssuableSynths(address issuer) external view returns (uint maxIssuable);

    function minimumStakeTime() external view returns (uint);

    function remainingIssuableSynths(address issuer)
        external
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt
        );

    function synths(bytes32 currencyKey) external view returns (ISynth);

    function getSynths(bytes32[] calldata currencyKeys) external view returns (ISynth[] memory);

    function synthsByAddress(address synthAddress) external view returns (bytes32);

    function totalIssuedSynths(bytes32 currencyKey, bool excludeOtherCollateral) external view returns (uint);

    function transferableSynthetixAndAnyRateIsInvalid(address account, uint balance)
        external
        view
        returns (uint transferable, bool anyRateIsInvalid);

    function liquidationAmounts(address account, bool isSelfLiquidation)
        external
        view
        returns (
            uint totalRedeemed,
            uint debtToRemove,
            uint escrowToLiquidate,
            uint initialDebtBalance
        );

    // Restricted: used internally to Synthetix
    function addSynths(ISynth[] calldata synthsToAdd) external;

    function issueSynths(address from, uint amount) external;

    function issueSynthsOnBehalf(
        address issueFor,
        address from,
        uint amount
    ) external;

    function issueMaxSynths(address from) external;

    function issueMaxSynthsOnBehalf(address issueFor, address from) external;

    function burnSynths(address from, uint amount) external;

    function burnSynthsOnBehalf(
        address burnForAddress,
        address from,
        uint amount
    ) external;

    function burnSynthsToTarget(address from) external;

    function burnSynthsToTargetOnBehalf(address burnForAddress, address from) external;

    function burnForRedemption(
        address deprecatedSynthProxy,
        address account,
        uint balance
    ) external;

    function setCurrentPeriodId(uint128 periodId) external;

    function liquidateAccount(address account, bool isSelfLiquidation)
        external
        returns (
            uint totalRedeemed,
            uint debtRemoved,
            uint escrowToLiquidate
        );

    function issueSynthsWithoutDebt(
        bytes32 currencyKey,
        address to,
        uint amount
    ) external returns (bool rateInvalid);

    function burnSynthsWithoutDebt(
        bytes32 currencyKey,
        address to,
        uint amount
    ) external returns (bool rateInvalid);
}


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/addressresolver
contract AddressResolver is Owned, IAddressResolver {
    mapping(bytes32 => address) public repository;

    constructor(address _owner) public Owned(_owner) {}

    /* ========== RESTRICTED FUNCTIONS ========== */

    function importAddresses(bytes32[] calldata names, address[] calldata destinations) external onlyOwner {
        require(names.length == destinations.length, "Input lengths must match");

        for (uint i = 0; i < names.length; i++) {
            bytes32 name = names[i];
            address destination = destinations[i];
            repository[name] = destination;
            emit AddressImported(name, destination);
        }
    }

    /* ========= PUBLIC FUNCTIONS ========== */

    function rebuildCaches(MixinResolver[] calldata destinations) external {
        for (uint i = 0; i < destinations.length; i++) {
            destinations[i].rebuildCache();
        }
    }

    /* ========== VIEWS ========== */

    function areAddressesImported(bytes32[] calldata names, address[] calldata destinations) external view returns (bool) {
        for (uint i = 0; i < names.length; i++) {
            if (repository[names[i]] != destinations[i]) {
                return false;
            }
        }
        return true;
    }

    function getAddress(bytes32 name) external view returns (address) {
        return repository[name];
    }

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address) {
        address _foundAddress = repository[name];
        require(_foundAddress != address(0), reason);
        return _foundAddress;
    }

    function getSynth(bytes32 key) external view returns (address) {
        IIssuer issuer = IIssuer(repository["Issuer"]);
        require(address(issuer) != address(0), "Cannot find Issuer address");
        return address(issuer.synths(key));
    }

    /* ========== EVENTS ========== */

    event AddressImported(bytes32 name, address destination);
}


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/mixinresolver
contract MixinResolver {
    AddressResolver public resolver;

    mapping(bytes32 => address) private addressCache;

    constructor(address _resolver) internal {
        resolver = AddressResolver(_resolver);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function combineArrays(bytes32[] memory first, bytes32[] memory second)
        internal
        pure
        returns (bytes32[] memory combination)
    {
        combination = new bytes32[](first.length + second.length);

        for (uint i = 0; i < first.length; i++) {
            combination[i] = first[i];
        }

        for (uint j = 0; j < second.length; j++) {
            combination[first.length + j] = second[j];
        }
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    // Note: this function is public not external in order for it to be overridden and invoked via super in subclasses
    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {}

    function rebuildCache() public {
        bytes32[] memory requiredAddresses = resolverAddressesRequired();
        // The resolver must call this function whenver it updates its state
        for (uint i = 0; i < requiredAddresses.length; i++) {
            bytes32 name = requiredAddresses[i];
            // Note: can only be invoked once the resolver has all the targets needed added
            address destination =
                resolver.requireAndGetAddress(name, string(abi.encodePacked("Resolver missing target: ", name)));
            addressCache[name] = destination;
            emit CacheUpdated(name, destination);
        }
    }

    /* ========== VIEWS ========== */

    function isResolverCached() external view returns (bool) {
        bytes32[] memory requiredAddresses = resolverAddressesRequired();
        for (uint i = 0; i < requiredAddresses.length; i++) {
            bytes32 name = requiredAddresses[i];
            // false if our cache is invalid or if the resolver doesn't have the required address
            if (resolver.getAddress(name) != addressCache[name] || addressCache[name] == address(0)) {
                return false;
            }
        }

        return true;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function requireAndGetAddress(bytes32 name) internal view returns (address) {
        address _foundAddress = addressCache[name];
        require(_foundAddress != address(0), string(abi.encodePacked("Missing address: ", name)));
        return _foundAddress;
    }

    /* ========== EVENTS ========== */

    event CacheUpdated(bytes32 name, address destination);
}


// https://docs.synthetix.io/contracts/source/interfaces/iflexiblestorage
interface IFlexibleStorage {
    // Views
    function getUIntValue(bytes32 contractName, bytes32 record) external view returns (uint);

    function getUIntValues(bytes32 contractName, bytes32[] calldata records) external view returns (uint[] memory);

    function getIntValue(bytes32 contractName, bytes32 record) external view returns (int);

    function getIntValues(bytes32 contractName, bytes32[] calldata records) external view returns (int[] memory);

    function getAddressValue(bytes32 contractName, bytes32 record) external view returns (address);

    function getAddressValues(bytes32 contractName, bytes32[] calldata records) external view returns (address[] memory);

    function getBoolValue(bytes32 contractName, bytes32 record) external view returns (bool);

    function getBoolValues(bytes32 contractName, bytes32[] calldata records) external view returns (bool[] memory);

    function getBytes32Value(bytes32 contractName, bytes32 record) external view returns (bytes32);

    function getBytes32Values(bytes32 contractName, bytes32[] calldata records) external view returns (bytes32[] memory);

    // Mutative functions
    function deleteUIntValue(bytes32 contractName, bytes32 record) external;

    function deleteIntValue(bytes32 contractName, bytes32 record) external;

    function deleteAddressValue(bytes32 contractName, bytes32 record) external;

    function deleteBoolValue(bytes32 contractName, bytes32 record) external;

    function deleteBytes32Value(bytes32 contractName, bytes32 record) external;

    function setUIntValue(
        bytes32 contractName,
        bytes32 record,
        uint value
    ) external;

    function setUIntValues(
        bytes32 contractName,
        bytes32[] calldata records,
        uint[] calldata values
    ) external;

    function setIntValue(
        bytes32 contractName,
        bytes32 record,
        int value
    ) external;

    function setIntValues(
        bytes32 contractName,
        bytes32[] calldata records,
        int[] calldata values
    ) external;

    function setAddressValue(
        bytes32 contractName,
        bytes32 record,
        address value
    ) external;

    function setAddressValues(
        bytes32 contractName,
        bytes32[] calldata records,
        address[] calldata values
    ) external;

    function setBoolValue(
        bytes32 contractName,
        bytes32 record,
        bool value
    ) external;

    function setBoolValues(
        bytes32 contractName,
        bytes32[] calldata records,
        bool[] calldata values
    ) external;

    function setBytes32Value(
        bytes32 contractName,
        bytes32 record,
        bytes32 value
    ) external;

    function setBytes32Values(
        bytes32 contractName,
        bytes32[] calldata records,
        bytes32[] calldata values
    ) external;
}


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/mixinsystemsettings
contract MixinSystemSettings is MixinResolver {
    // must match the one defined SystemSettingsLib, defined in both places due to sol v0.5 limitations
    bytes32 internal constant SETTING_CONTRACT_NAME = "SystemSettings";

    bytes32 internal constant SETTING_WAITING_PERIOD_SECS = "waitingPeriodSecs";
    bytes32 internal constant SETTING_PRICE_DEVIATION_THRESHOLD_FACTOR = "priceDeviationThresholdFactor";
    bytes32 internal constant SETTING_ISSUANCE_RATIO = "issuanceRatio";
    bytes32 internal constant SETTING_FEE_PERIOD_DURATION = "feePeriodDuration";
    bytes32 internal constant SETTING_TARGET_THRESHOLD = "targetThreshold";
    bytes32 internal constant SETTING_LIQUIDATION_DELAY = "liquidationDelay";
    bytes32 internal constant SETTING_LIQUIDATION_RATIO = "liquidationRatio";
    bytes32 internal constant SETTING_LIQUIDATION_ESCROW_DURATION = "liquidationEscrowDuration";
    bytes32 internal constant SETTING_LIQUIDATION_PENALTY = "liquidationPenalty";
    bytes32 internal constant SETTING_SNX_LIQUIDATION_PENALTY = "snxLiquidationPenalty";
    bytes32 internal constant SETTING_SELF_LIQUIDATION_PENALTY = "selfLiquidationPenalty";
    bytes32 internal constant SETTING_FLAG_REWARD = "flagReward";
    bytes32 internal constant SETTING_LIQUIDATE_REWARD = "liquidateReward";
    bytes32 internal constant SETTING_RATE_STALE_PERIOD = "rateStalePeriod";
    /* ========== Exchange Fees Related ========== */
    bytes32 internal constant SETTING_EXCHANGE_FEE_RATE = "exchangeFeeRate";
    bytes32 internal constant SETTING_EXCHANGE_DYNAMIC_FEE_THRESHOLD = "exchangeDynamicFeeThreshold";
    bytes32 internal constant SETTING_EXCHANGE_DYNAMIC_FEE_WEIGHT_DECAY = "exchangeDynamicFeeWeightDecay";
    bytes32 internal constant SETTING_EXCHANGE_DYNAMIC_FEE_ROUNDS = "exchangeDynamicFeeRounds";
    bytes32 internal constant SETTING_EXCHANGE_MAX_DYNAMIC_FEE = "exchangeMaxDynamicFee";
    /* ========== End Exchange Fees Related ========== */
    bytes32 internal constant SETTING_MINIMUM_STAKE_TIME = "minimumStakeTime";
    bytes32 internal constant SETTING_AGGREGATOR_WARNING_FLAGS = "aggregatorWarningFlags";
    bytes32 internal constant SETTING_TRADING_REWARDS_ENABLED = "tradingRewardsEnabled";
    bytes32 internal constant SETTING_DEBT_SNAPSHOT_STALE_TIME = "debtSnapshotStaleTime";
    bytes32 internal constant SETTING_CROSS_DOMAIN_DEPOSIT_GAS_LIMIT = "crossDomainDepositGasLimit";
    bytes32 internal constant SETTING_CROSS_DOMAIN_ESCROW_GAS_LIMIT = "crossDomainEscrowGasLimit";
    bytes32 internal constant SETTING_CROSS_DOMAIN_REWARD_GAS_LIMIT = "crossDomainRewardGasLimit";
    bytes32 internal constant SETTING_CROSS_DOMAIN_WITHDRAWAL_GAS_LIMIT = "crossDomainWithdrawalGasLimit";
    bytes32 internal constant SETTING_CROSS_DOMAIN_FEE_PERIOD_CLOSE_GAS_LIMIT = "crossDomainCloseGasLimit";
    bytes32 internal constant SETTING_CROSS_DOMAIN_RELAY_GAS_LIMIT = "crossDomainRelayGasLimit";
    bytes32 internal constant SETTING_ETHER_WRAPPER_MAX_ETH = "etherWrapperMaxETH";
    bytes32 internal constant SETTING_ETHER_WRAPPER_MINT_FEE_RATE = "etherWrapperMintFeeRate";
    bytes32 internal constant SETTING_ETHER_WRAPPER_BURN_FEE_RATE = "etherWrapperBurnFeeRate";
    bytes32 internal constant SETTING_WRAPPER_MAX_TOKEN_AMOUNT = "wrapperMaxTokens";
    bytes32 internal constant SETTING_WRAPPER_MINT_FEE_RATE = "wrapperMintFeeRate";
    bytes32 internal constant SETTING_WRAPPER_BURN_FEE_RATE = "wrapperBurnFeeRate";
    bytes32 internal constant SETTING_INTERACTION_DELAY = "interactionDelay";
    bytes32 internal constant SETTING_COLLAPSE_FEE_RATE = "collapseFeeRate";
    bytes32 internal constant SETTING_ATOMIC_MAX_VOLUME_PER_BLOCK = "atomicMaxVolumePerBlock";
    bytes32 internal constant SETTING_ATOMIC_TWAP_WINDOW = "atomicTwapWindow";
    bytes32 internal constant SETTING_ATOMIC_EQUIVALENT_FOR_DEX_PRICING = "atomicEquivalentForDexPricing";
    bytes32 internal constant SETTING_ATOMIC_EXCHANGE_FEE_RATE = "atomicExchangeFeeRate";
    bytes32 internal constant SETTING_ATOMIC_VOLATILITY_CONSIDERATION_WINDOW = "atomicVolConsiderationWindow";
    bytes32 internal constant SETTING_ATOMIC_VOLATILITY_UPDATE_THRESHOLD = "atomicVolUpdateThreshold";
    bytes32 internal constant SETTING_PURE_CHAINLINK_PRICE_FOR_ATOMIC_SWAPS_ENABLED = "pureChainlinkForAtomicsEnabled";
    bytes32 internal constant SETTING_CROSS_SYNTH_TRANSFER_ENABLED = "crossChainSynthTransferEnabled";

    bytes32 internal constant CONTRACT_FLEXIBLESTORAGE = "FlexibleStorage";

    enum CrossDomainMessageGasLimits {Deposit, Escrow, Reward, Withdrawal, CloseFeePeriod, Relay}

    struct DynamicFeeConfig {
        uint threshold;
        uint weightDecay;
        uint rounds;
        uint maxFee;
    }

    constructor(address _resolver) internal MixinResolver(_resolver) {}

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        addresses = new bytes32[](1);
        addresses[0] = CONTRACT_FLEXIBLESTORAGE;
    }

    function flexibleStorage() internal view returns (IFlexibleStorage) {
        return IFlexibleStorage(requireAndGetAddress(CONTRACT_FLEXIBLESTORAGE));
    }

    function _getGasLimitSetting(CrossDomainMessageGasLimits gasLimitType) internal pure returns (bytes32) {
        if (gasLimitType == CrossDomainMessageGasLimits.Deposit) {
            return SETTING_CROSS_DOMAIN_DEPOSIT_GAS_LIMIT;
        } else if (gasLimitType == CrossDomainMessageGasLimits.Escrow) {
            return SETTING_CROSS_DOMAIN_ESCROW_GAS_LIMIT;
        } else if (gasLimitType == CrossDomainMessageGasLimits.Reward) {
            return SETTING_CROSS_DOMAIN_REWARD_GAS_LIMIT;
        } else if (gasLimitType == CrossDomainMessageGasLimits.Withdrawal) {
            return SETTING_CROSS_DOMAIN_WITHDRAWAL_GAS_LIMIT;
        } else if (gasLimitType == CrossDomainMessageGasLimits.Relay) {
            return SETTING_CROSS_DOMAIN_RELAY_GAS_LIMIT;
        } else if (gasLimitType == CrossDomainMessageGasLimits.CloseFeePeriod) {
            return SETTING_CROSS_DOMAIN_FEE_PERIOD_CLOSE_GAS_LIMIT;
        } else {
            revert("Unknown gas limit type");
        }
    }

    function getCrossDomainMessageGasLimit(CrossDomainMessageGasLimits gasLimitType) internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, _getGasLimitSetting(gasLimitType));
    }

    function getTradingRewardsEnabled() internal view returns (bool) {
        return flexibleStorage().getBoolValue(SETTING_CONTRACT_NAME, SETTING_TRADING_REWARDS_ENABLED);
    }

    function getWaitingPeriodSecs() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_WAITING_PERIOD_SECS);
    }

    function getPriceDeviationThresholdFactor() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_PRICE_DEVIATION_THRESHOLD_FACTOR);
    }

    function getIssuanceRatio() internal view returns (uint) {
        // lookup on flexible storage directly for gas savings (rather than via SystemSettings)
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_ISSUANCE_RATIO);
    }

    function getFeePeriodDuration() internal view returns (uint) {
        // lookup on flexible storage directly for gas savings (rather than via SystemSettings)
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_FEE_PERIOD_DURATION);
    }

    function getTargetThreshold() internal view returns (uint) {
        // lookup on flexible storage directly for gas savings (rather than via SystemSettings)
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_TARGET_THRESHOLD);
    }

    function getLiquidationDelay() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_DELAY);
    }

    function getLiquidationRatio() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_RATIO);
    }

    function getLiquidationEscrowDuration() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_ESCROW_DURATION);
    }

    function getLiquidationPenalty() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_PENALTY);
    }

    function getSnxLiquidationPenalty() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_SNX_LIQUIDATION_PENALTY);
    }

    function getSelfLiquidationPenalty() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_SELF_LIQUIDATION_PENALTY);
    }

    function getFlagReward() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_FLAG_REWARD);
    }

    function getLiquidateReward() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATE_REWARD);
    }

    function getRateStalePeriod() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_RATE_STALE_PERIOD);
    }

    /* ========== Exchange Related Fees ========== */
    function getExchangeFeeRate(bytes32 currencyKey) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_EXCHANGE_FEE_RATE, currencyKey))
            );
    }

    /// @notice Get exchange dynamic fee related keys
    /// @return threshold, weight decay, rounds, and max fee
    function getExchangeDynamicFeeConfig() internal view returns (DynamicFeeConfig memory) {
        bytes32[] memory keys = new bytes32[](4);
        keys[0] = SETTING_EXCHANGE_DYNAMIC_FEE_THRESHOLD;
        keys[1] = SETTING_EXCHANGE_DYNAMIC_FEE_WEIGHT_DECAY;
        keys[2] = SETTING_EXCHANGE_DYNAMIC_FEE_ROUNDS;
        keys[3] = SETTING_EXCHANGE_MAX_DYNAMIC_FEE;
        uint[] memory values = flexibleStorage().getUIntValues(SETTING_CONTRACT_NAME, keys);
        return DynamicFeeConfig({threshold: values[0], weightDecay: values[1], rounds: values[2], maxFee: values[3]});
    }

    /* ========== End Exchange Related Fees ========== */

    function getMinimumStakeTime() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_MINIMUM_STAKE_TIME);
    }

    function getAggregatorWarningFlags() internal view returns (address) {
        return flexibleStorage().getAddressValue(SETTING_CONTRACT_NAME, SETTING_AGGREGATOR_WARNING_FLAGS);
    }

    function getDebtSnapshotStaleTime() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_DEBT_SNAPSHOT_STALE_TIME);
    }

    function getEtherWrapperMaxETH() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_ETHER_WRAPPER_MAX_ETH);
    }

    function getEtherWrapperMintFeeRate() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_ETHER_WRAPPER_MINT_FEE_RATE);
    }

    function getEtherWrapperBurnFeeRate() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_ETHER_WRAPPER_BURN_FEE_RATE);
    }

    function getWrapperMaxTokenAmount(address wrapper) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_WRAPPER_MAX_TOKEN_AMOUNT, wrapper))
            );
    }

    function getWrapperMintFeeRate(address wrapper) internal view returns (int) {
        return
            flexibleStorage().getIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_WRAPPER_MINT_FEE_RATE, wrapper))
            );
    }

    function getWrapperBurnFeeRate(address wrapper) internal view returns (int) {
        return
            flexibleStorage().getIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_WRAPPER_BURN_FEE_RATE, wrapper))
            );
    }

    function getInteractionDelay(address collateral) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_INTERACTION_DELAY, collateral))
            );
    }

    function getCollapseFeeRate(address collateral) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_COLLAPSE_FEE_RATE, collateral))
            );
    }

    function getAtomicMaxVolumePerBlock() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_ATOMIC_MAX_VOLUME_PER_BLOCK);
    }

    function getAtomicTwapWindow() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_ATOMIC_TWAP_WINDOW);
    }

    function getAtomicEquivalentForDexPricing(bytes32 currencyKey) internal view returns (address) {
        return
            flexibleStorage().getAddressValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_ATOMIC_EQUIVALENT_FOR_DEX_PRICING, currencyKey))
            );
    }

    function getAtomicExchangeFeeRate(bytes32 currencyKey) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_ATOMIC_EXCHANGE_FEE_RATE, currencyKey))
            );
    }

    function getAtomicVolatilityConsiderationWindow(bytes32 currencyKey) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_ATOMIC_VOLATILITY_CONSIDERATION_WINDOW, currencyKey))
            );
    }

    function getAtomicVolatilityUpdateThreshold(bytes32 currencyKey) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_ATOMIC_VOLATILITY_UPDATE_THRESHOLD, currencyKey))
            );
    }

    function getPureChainlinkPriceForAtomicSwapsEnabled(bytes32 currencyKey) internal view returns (bool) {
        return
            flexibleStorage().getBoolValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_PURE_CHAINLINK_PRICE_FOR_ATOMIC_SWAPS_ENABLED, currencyKey))
            );
    }

    function getCrossChainSynthTransferEnabled(bytes32 currencyKey) internal view returns (uint) {
        return
            flexibleStorage().getUIntValue(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_CROSS_SYNTH_TRANSFER_ENABLED, currencyKey))
            );
    }

    function getExchangeMaxDynamicFee() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_EXCHANGE_MAX_DYNAMIC_FEE);
    }

    function getExchangeDynamicFeeRounds() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_EXCHANGE_DYNAMIC_FEE_ROUNDS);
    }

    function getExchangeDynamicFeeThreshold() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_EXCHANGE_DYNAMIC_FEE_THRESHOLD);
    }

    function getExchangeDynamicFeeWeightDecay() internal view returns (uint) {
        return flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_EXCHANGE_DYNAMIC_FEE_WEIGHT_DECAY);
    }
}


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
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
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


// import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythStructs {
    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        // The price ID.
        bytes32 id;
        // Latest available price
        Price price;
        // Latest available exponentially-weighted moving average price
        Price emaPrice;
    }
}


pragma experimental ABIEncoderV2;


// import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

/// @title Consume prices from the Pyth Network (https://pyth.network/).
/// @dev Please refer to the guidance at https://docs.pyth.network/consumers/best-practices for how to consume prices safely.
/// @author Pyth Data Association
interface IPyth {
    /// @dev Emitted when the price feed with `id` has received a fresh update.
    /// @param id The Pyth Price Feed ID.
    /// @param publishTime Publish time of the given price update.
    /// @param price Price of the given price update.
    /// @param conf Confidence interval of the given price update.
    event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf);

    /// @dev Emitted when a batch price update is processed successfully.
    /// @param chainId ID of the source chain that the batch price update comes from.
    /// @param sequenceNumber Sequence number of the batch price update.
    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);

    /// @notice Returns the period (in seconds) that a price feed is considered valid since its publish time
    function getValidTimePeriod() external view returns (uint validTimePeriod);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `getValidTimePeriod()` seconds.
    /// @param id The Pyth Price Feed ID of which to fetch the price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price and confidence interval.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    /// @notice Update price feeds with given update messages.
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. A price update is
    /// necessary if the current on-chain publishTime is older than the given publishTime. It relies solely on the
    /// given `publishTimes` for the price feeds and does not read the actual price update publish time within `updateData`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    /// `priceIds` and `publishTimes` are two arrays with the same size that correspond to senders known publishTime
    /// of each priceId when calling this method. If all of price feeds within `priceIds` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts if update is not needed or the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param publishTimes Array of publishTimes. `publishTimes[i]` corresponds to known `publishTime` of `priceIds[i]`
    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;

    /// @notice Returns the required fee to update an array of price updates.
    /// @param updateData Array of price update data.
    /// @return feeAmount The required fee in Wei.
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);

    /// @notice Parse `updateData` and return price feeds of the given `priceIds` if they are all published
    /// within `minPublishTime` and `maxPublishTime`.
    ///
    /// You can use this method if you want to use a Pyth price at a fixed time and not the most recent price;
    /// otherwise, please consider using `updatePriceFeeds`. This method does not store the price updates on-chain.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    ///
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid or there is
    /// no update for any of the given `priceIds` within the given time range.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param minPublishTime minimum acceptable publishTime for the given `priceIds`.
    /// @param maxPublishTime maximum acceptable publishTime for the given `priceIds`.
    /// @return priceFeeds Array of the price feeds corresponding to the given `priceIds` (with the same order).
    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);
}


// https://docs.synthetix.io/contracts/source/libraries/addresssetlib/
library AddressSetLib {
    struct AddressSet {
        address[] elements;
        mapping(address => uint) indices;
    }

    function contains(AddressSet storage set, address candidate) internal view returns (bool) {
        if (set.elements.length == 0) {
            return false;
        }
        uint index = set.indices[candidate];
        return index != 0 || set.elements[0] == candidate;
    }

    function getPage(
        AddressSet storage set,
        uint index,
        uint pageSize
    ) internal view returns (address[] memory) {
        // NOTE: This implementation should be converted to slice operators if the compiler is updated to v0.6.0+
        uint endIndex = index + pageSize; // The check below that endIndex <= index handles overflow.

        // If the page extends past the end of the list, truncate it.
        if (endIndex > set.elements.length) {
            endIndex = set.elements.length;
        }
        if (endIndex <= index) {
            return new address[](0);
        }

        uint n = endIndex - index; // We already checked for negative overflow.
        address[] memory page = new address[](n);
        for (uint i; i < n; i++) {
            page[i] = set.elements[i + index];
        }
        return page;
    }

    function add(AddressSet storage set, address element) internal {
        // Adding to a set is an idempotent operation.
        if (!contains(set, element)) {
            set.indices[element] = set.elements.length;
            set.elements.push(element);
        }
    }

    function remove(AddressSet storage set, address element) internal {
        require(contains(set, element), "Element not in set.");
        // Replace the removed element with the last element of the list.
        uint index = set.indices[element];
        uint lastIndex = set.elements.length - 1; // We required that element is in the list, so it is not empty.
        if (index != lastIndex) {
            // No need to shift the last element if it is the one we want to delete.
            address shiftedElement = set.elements[lastIndex];
            set.elements[index] = shiftedElement;
            set.indices[shiftedElement] = index;
        }
        set.elements.pop();
        delete set.indices[element];
    }
}


// Inheritance


// Libraries


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2ExchangeRate
contract PerpsV2ExchangeRate is Owned, ReentrancyGuard, MixinSystemSettings {
    using AddressSetLib for AddressSetLib.AddressSet;

    bytes32 public constant CONTRACT_NAME = "PerpsV2ExchangeRate";

    bytes32 internal constant SETTING_OFFCHAIN_ORACLE = "offchainOracle";
    bytes32 internal constant SETTING_OFFCHAIN_PRICE_FEED_ID = "priceFeedId";

    AddressSetLib.AddressSet internal _associatedContracts;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _owner, address _resolver) public Owned(_owner) MixinSystemSettings(_resolver) {}

    /* ========== SETTERS ========== */

    function setOffchainOracle(address offchainOracle) external onlyOwner {
        flexibleStorage().setAddressValue(CONTRACT_NAME, SETTING_OFFCHAIN_ORACLE, offchainOracle);
        emit OffchainOracleUpdated(offchainOracle);
    }

    function setOffchainPriceFeedId(bytes32 assetId, bytes32 priceFeedId) external onlyOwner {
        flexibleStorage().setBytes32Value(
            CONTRACT_NAME,
            keccak256(abi.encodePacked(SETTING_OFFCHAIN_PRICE_FEED_ID, assetId)),
            priceFeedId
        );
        emit OffchainPriceFeedIdUpdated(assetId, priceFeedId);
    }

    /* ========== ACCESS CONTROL ========== */

    // Add associated contracts
    function addAssociatedContracts(address[] calldata associatedContracts) external onlyOwner {
        for (uint i = 0; i < associatedContracts.length; i++) {
            if (!_associatedContracts.contains(associatedContracts[i])) {
                _associatedContracts.add(associatedContracts[i]);
                emit AssociatedContractAdded(associatedContracts[i]);
            }
        }
    }

    // Remove associated contracts
    function removeAssociatedContracts(address[] calldata associatedContracts) external onlyOwner {
        for (uint i = 0; i < associatedContracts.length; i++) {
            if (_associatedContracts.contains(associatedContracts[i])) {
                _associatedContracts.remove(associatedContracts[i]);
                emit AssociatedContractRemoved(associatedContracts[i]);
            }
        }
    }

    function associatedContracts() external view returns (address[] memory) {
        return _associatedContracts.getPage(0, _associatedContracts.elements.length);
    }

    /* ========== VIEWS ========== */

    function offchainOracle() public view returns (IPyth) {
        return IPyth(flexibleStorage().getAddressValue(CONTRACT_NAME, SETTING_OFFCHAIN_ORACLE));
    }

    function offchainPriceFeedId(bytes32 assetId) public view returns (bytes32) {
        return
            flexibleStorage().getBytes32Value(
                CONTRACT_NAME,
                keccak256(abi.encodePacked(SETTING_OFFCHAIN_PRICE_FEED_ID, assetId))
            );
    }

    /* ---------- priceFeeds mutation ---------- */

    function updatePythPrice(address sender, bytes[] calldata priceUpdateData)
        external
        payable
        nonReentrant
        onlyAssociatedContracts
    {
        // Get fee amount to pay to Pyth
        uint fee = offchainOracle().getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Not enough eth for paying the fee");

        // Update the price data (and pay the fee)
        offchainOracle().updatePriceFeeds.value(fee)(priceUpdateData);

        if (msg.value - fee > 0) {
            // Need to refund caller. Try to return unused value, or revert if failed
            // solhint-disable-next-line  avoid-low-level-calls
            (bool success, ) = sender.call.value(msg.value - fee)("");
            require(success, "Failed to refund caller");
        }
    }

    // it is a view but it can revert
    function resolveAndGetPrice(bytes32 assetId, uint maxAge) external view returns (uint price, uint publishTime) {
        bytes32 priceFeedId = offchainPriceFeedId(assetId);
        require(priceFeedId != 0, "No price feed found for asset");

        return _getPythPrice(priceFeedId, maxAge);
    }

    // it is a view but it can revert
    function resolveAndGetLatestPrice(bytes32 assetId) external view returns (uint price, uint publishTime) {
        bytes32 priceFeedId = offchainPriceFeedId(assetId);
        require(priceFeedId != 0, "No price feed found for asset");

        return _getPythPriceUnsafe(priceFeedId);
    }

    function _calculatePrice(PythStructs.Price memory retrievedPrice) internal view returns (uint price) {
        /*
        retrievedPrice.price fixed-point representation base
        retrievedPrice.expo fixed-point representation exponent (to go from base to decimal)
        retrievedPrice.conf fixed-point representation of confidence         
        i.e. 
        .price = 12276250
        .expo = -5
        price = 12276250 * 10^(-5) =  122.76250
        to go to 18 decimals => rebasedPrice = 12276250 * 10^(18-5) = 122762500000000000000
        */

        // Adjust exponent (using base as 18 decimals)
        uint baseConvertion = 10**uint(int(18) + retrievedPrice.expo);

        price = uint(retrievedPrice.price * int(baseConvertion));
    }

    function _getPythPriceUnsafe(bytes32 priceFeedId) internal view returns (uint price, uint publishTime) {
        // It will revert if there's no price for the priceFeedId
        PythStructs.Price memory retrievedPrice = offchainOracle().getPriceUnsafe(priceFeedId);

        price = _calculatePrice(retrievedPrice);
        publishTime = retrievedPrice.publishTime;
    }

    function _getPythPrice(bytes32 priceFeedId, uint maxAge) internal view returns (uint price, uint publishTime) {
        // It will revert if the price is older than maxAge
        PythStructs.Price memory retrievedPrice = offchainOracle().getPriceNoOlderThan(priceFeedId, maxAge);

        price = _calculatePrice(retrievedPrice);
        publishTime = retrievedPrice.publishTime;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAssociatedContracts {
        require(_associatedContracts.contains(msg.sender), "Only an associated contract can perform this action");
        _;
    }

    /* ========== EVENTS ========== */

    event AssociatedContractAdded(address associatedContract);
    event AssociatedContractRemoved(address associatedContract);

    event OffchainOracleUpdated(address offchainOracle);
    event OffchainPriceFeedIdUpdated(bytes32 assetId, bytes32 priceFeedId);
}


interface IFuturesMarketManager {
    function markets(uint index, uint pageSize) external view returns (address[] memory);

    function markets(
        uint index,
        uint pageSize,
        bool proxiedMarkets
    ) external view returns (address[] memory);

    function numMarkets() external view returns (uint);

    function numMarkets(bool proxiedMarkets) external view returns (uint);

    function allMarkets() external view returns (address[] memory);

    function allMarkets(bool proxiedMarkets) external view returns (address[] memory);

    function marketForKey(bytes32 marketKey) external view returns (address);

    function marketsForKeys(bytes32[] calldata marketKeys) external view returns (address[] memory);

    function totalDebt() external view returns (uint debt, bool isInvalid);
}


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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
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
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
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
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}


// https://docs.synthetix.io/contracts/source/interfaces/ifeepool
interface IFeePool {
    // Views

    // solhint-disable-next-line func-name-mixedcase
    function FEE_ADDRESS() external view returns (address);

    function feesAvailable(address account) external view returns (uint, uint);

    function feePeriodDuration() external view returns (uint);

    function isFeesClaimable(address account) external view returns (bool);

    function targetThreshold() external view returns (uint);

    function totalFeesAvailable() external view returns (uint);

    function totalRewardsAvailable() external view returns (uint);

    // Mutative Functions
    function claimFees() external returns (bool);

    function claimOnBehalf(address claimingForAddress) external returns (bool);

    function closeCurrentFeePeriod() external;

    function closeSecondary(uint snxBackedDebt, uint debtShareSupply) external;

    function recordFeePaid(uint sUSDAmount) external;

    function setRewardsToDistribute(uint amount) external;
}


interface IVirtualSynth {
    // Views
    function balanceOfUnderlying(address account) external view returns (uint);

    function rate() external view returns (uint);

    function readyToSettle() external view returns (bool);

    function secsLeftInWaitingPeriod() external view returns (uint);

    function settled() external view returns (bool);

    function synth() external view returns (ISynth);

    // Mutative functions
    function settle(address account) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    struct ExchangeEntrySettlement {
        bytes32 src;
        uint amount;
        bytes32 dest;
        uint reclaim;
        uint rebate;
        uint srcRoundIdAtPeriodEnd;
        uint destRoundIdAtPeriodEnd;
        uint timestamp;
    }

    struct ExchangeEntry {
        uint sourceRate;
        uint destinationRate;
        uint destinationAmount;
        uint exchangeFeeRate;
        uint exchangeDynamicFeeRate;
        uint roundIdForSrc;
        uint roundIdForDest;
        uint sourceAmountAfterSettlement;
    }

    // Views
    function calculateAmountAfterSettlement(
        address from,
        bytes32 currencyKey,
        uint amount,
        uint refunded
    ) external view returns (uint amountAfterSettlement);

    function isSynthRateInvalid(bytes32 currencyKey) external view returns (bool);

    function maxSecsLeftInWaitingPeriod(address account, bytes32 currencyKey) external view returns (uint);

    function settlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (
            uint reclaimAmount,
            uint rebateAmount,
            uint numEntries
        );

    function hasWaitingPeriodOrSettlementOwing(address account, bytes32 currencyKey) external view returns (bool);

    function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view returns (uint);

    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint feeRate, bool tooVolatile);

    function getAmountsForExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint amountReceived,
            uint fee,
            uint exchangeFeeRate
        );

    function priceDeviationThresholdFactor() external view returns (uint);

    function waitingPeriodSecs() external view returns (uint);

    function lastExchangeRate(bytes32 currencyKey) external view returns (uint);

    // Mutative functions
    function exchange(
        address exchangeForAddress,
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bool virtualSynth,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived, IVirtualSynth vSynth);

    function exchangeAtomically(
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bytes32 trackingCode,
        uint minAmount
    ) external returns (uint amountReceived);

    function settle(address from, bytes32 currencyKey)
        external
        returns (
            uint reclaimed,
            uint refunded,
            uint numEntries
        );
}

// Used to have strongly-typed access to internal mutative functions in Synthetix
interface ISynthetixInternal {
    function emitExchangeTracking(
        bytes32 trackingCode,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        uint256 fee
    ) external;

    function emitSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint fromAmount,
        bytes32 toCurrencyKey,
        uint toAmount,
        address toAddress
    ) external;

    function emitAtomicSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint fromAmount,
        bytes32 toCurrencyKey,
        uint toAmount,
        address toAddress
    ) external;

    function emitExchangeReclaim(
        address account,
        bytes32 currencyKey,
        uint amount
    ) external;

    function emitExchangeRebate(
        address account,
        bytes32 currencyKey,
        uint amount
    ) external;
}

interface IExchangerInternalDebtCache {
    function updateCachedSynthDebtsWithRates(bytes32[] calldata currencyKeys, uint[] calldata currencyRates) external;

    function updateCachedSynthDebts(bytes32[] calldata currencyKeys) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/ierc20
interface IERC20 {
    // ERC20 Optional Views
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    // Views
    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    // Mutative functions
    function transfer(address to, uint value) external returns (bool);

    function approve(address spender, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Events
    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);
}


// Inheritance


// Libraries


// Internal references


// basic views that are expected to be supported by v1 (IFuturesMarket) and v2 (via ProxyPerpsV2)
interface IMarketViews {
    function marketKey() external view returns (bytes32);

    function baseAsset() external view returns (bytes32);

    function marketSize() external view returns (uint128);

    function marketSkew() external view returns (int128);

    function assetPrice() external view returns (uint price, bool invalid);

    function marketDebt() external view returns (uint debt, bool isInvalid);

    function currentFundingRate() external view returns (int fundingRate);

    // v1 does not have a this so we never call it but this is here for v2.
    function currentFundingVelocity() external view returns (int fundingVelocity);

    // only supported by PerpsV2 Markets (and implemented in ProxyPerpsV2)
    function getAllTargets() external view returns (address[] memory);
}

// https://docs.synthetix.io/contracts/source/contracts/FuturesMarketManager
contract FuturesMarketManager is Owned, MixinResolver, IFuturesMarketManager {
    using SafeMath for uint;
    using AddressSetLib for AddressSetLib.AddressSet;

    /* ========== STATE VARIABLES ========== */

    AddressSetLib.AddressSet internal _allMarkets;
    AddressSetLib.AddressSet internal _legacyMarkets;
    AddressSetLib.AddressSet internal _proxiedMarkets;
    mapping(bytes32 => address) public marketForKey;

    // PerpsV2 implementations
    AddressSetLib.AddressSet internal _implementations;
    mapping(address => address[]) internal _marketImplementation;

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */

    bytes32 public constant CONTRACT_NAME = "FuturesMarketManager";

    bytes32 internal constant SUSD = "sUSD";
    bytes32 internal constant CONTRACT_SYNTHSUSD = "SynthsUSD";
    bytes32 internal constant CONTRACT_FEEPOOL = "FeePool";
    bytes32 internal constant CONTRACT_EXCHANGER = "Exchanger";

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _resolver) public Owned(_owner) MixinResolver(_resolver) {}

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        addresses = new bytes32[](3);
        addresses[0] = CONTRACT_SYNTHSUSD;
        addresses[1] = CONTRACT_FEEPOOL;
        addresses[2] = CONTRACT_EXCHANGER;
    }

    function _sUSD() internal view returns (ISynth) {
        return ISynth(requireAndGetAddress(CONTRACT_SYNTHSUSD));
    }

    function _feePool() internal view returns (IFeePool) {
        return IFeePool(requireAndGetAddress(CONTRACT_FEEPOOL));
    }

    function _exchanger() internal view returns (IExchanger) {
        return IExchanger(requireAndGetAddress(CONTRACT_EXCHANGER));
    }

    /*
     * Returns slices of the list of all markets.
     */
    function markets(uint index, uint pageSize) external view returns (address[] memory) {
        return _allMarkets.getPage(index, pageSize);
    }

    /*
     * Returns slices of the list of all v1 or v2 (proxied) markets.
     */
    function markets(
        uint index,
        uint pageSize,
        bool proxiedMarkets
    ) external view returns (address[] memory) {
        if (proxiedMarkets) {
            return _proxiedMarkets.getPage(index, pageSize);
        } else {
            return _legacyMarkets.getPage(index, pageSize);
        }
    }

    /*
     * The number of proxied + legacy markets known to the manager.
     */
    function numMarkets() external view returns (uint) {
        return _allMarkets.elements.length;
    }

    /*
     * The number of proxied or legacy markets known to the manager.
     */
    function numMarkets(bool proxiedMarkets) external view returns (uint) {
        if (proxiedMarkets) {
            return _proxiedMarkets.elements.length;
        } else {
            return _legacyMarkets.elements.length;
        }
    }

    /*
     * The list of all proxied AND legacy markets.
     */
    function allMarkets() public view returns (address[] memory) {
        return _allMarkets.getPage(0, _allMarkets.elements.length);
    }

    /*
     * The list of all proxied OR legacy markets.
     */
    function allMarkets(bool proxiedMarkets) public view returns (address[] memory) {
        if (proxiedMarkets) {
            return _proxiedMarkets.getPage(0, _proxiedMarkets.elements.length);
        } else {
            return _legacyMarkets.getPage(0, _legacyMarkets.elements.length);
        }
    }

    function _marketsForKeys(bytes32[] memory marketKeys) internal view returns (address[] memory) {
        uint mMarkets = marketKeys.length;
        address[] memory results = new address[](mMarkets);
        for (uint i; i < mMarkets; i++) {
            results[i] = marketForKey[marketKeys[i]];
        }
        return results;
    }

    /*
     * The market addresses for a given set of market key strings.
     */
    function marketsForKeys(bytes32[] calldata marketKeys) external view returns (address[] memory) {
        return _marketsForKeys(marketKeys);
    }

    /*
     * The accumulated debt contribution of all futures markets.
     */
    function totalDebt() external view returns (uint debt, bool isInvalid) {
        uint total;
        bool anyIsInvalid;
        uint numOfMarkets = _allMarkets.elements.length;
        for (uint i = 0; i < numOfMarkets; i++) {
            (uint marketDebt, bool invalid) = IMarketViews(_allMarkets.elements[i]).marketDebt();
            total = total.add(marketDebt);
            anyIsInvalid = anyIsInvalid || invalid;
        }
        return (total, anyIsInvalid);
    }

    struct MarketSummary {
        address market;
        bytes32 asset;
        bytes32 marketKey;
        uint price;
        uint marketSize;
        int marketSkew;
        uint marketDebt;
        int currentFundingRate;
        int currentFundingVelocity;
        bool priceInvalid;
        bool proxied;
    }

    function _marketSummaries(address[] memory addresses) internal view returns (MarketSummary[] memory) {
        uint nMarkets = addresses.length;
        MarketSummary[] memory summaries = new MarketSummary[](nMarkets);
        for (uint i; i < nMarkets; i++) {
            IMarketViews market = IMarketViews(addresses[i]);
            bytes32 marketKey = market.marketKey();
            bytes32 baseAsset = market.baseAsset();

            (uint price, bool invalid) = market.assetPrice();
            (uint debt, ) = market.marketDebt();

            bool proxied = _proxiedMarkets.contains(addresses[i]);
            summaries[i] = MarketSummary({
                market: address(market),
                asset: baseAsset,
                marketKey: marketKey,
                price: price,
                marketSize: market.marketSize(),
                marketSkew: market.marketSkew(),
                marketDebt: debt,
                currentFundingRate: market.currentFundingRate(),
                currentFundingVelocity: proxied ? market.currentFundingVelocity() : 0, // v1 does not have velocity.
                priceInvalid: invalid,
                proxied: proxied
            });
        }

        return summaries;
    }

    function marketSummaries(address[] calldata addresses) external view returns (MarketSummary[] memory) {
        return _marketSummaries(addresses);
    }

    function marketSummariesForKeys(bytes32[] calldata marketKeys) external view returns (MarketSummary[] memory) {
        return _marketSummaries(_marketsForKeys(marketKeys));
    }

    function allMarketSummaries() external view returns (MarketSummary[] memory) {
        return _marketSummaries(allMarkets());
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _addImplementations(address market) internal {
        address[] memory implementations = IMarketViews(market).getAllTargets();
        for (uint i = 0; i < implementations.length; i++) {
            _implementations.add(implementations[i]);
        }
        _marketImplementation[market] = implementations;
    }

    function _removeImplementations(address market) internal {
        address[] memory implementations = _marketImplementation[market];
        for (uint i = 0; i < implementations.length; i++) {
            if (_implementations.contains(implementations[i])) {
                _implementations.remove(implementations[i]);
            }
        }
        delete _marketImplementation[market];
    }

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function addMarkets(address[] calldata marketsToAdd) external onlyOwner {
        uint numOfMarkets = marketsToAdd.length;
        for (uint i; i < numOfMarkets; i++) {
            _addMarket(marketsToAdd[i], false);
        }
    }

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function addProxiedMarkets(address[] calldata marketsToAdd) external onlyOwner {
        uint numOfMarkets = marketsToAdd.length;
        for (uint i; i < numOfMarkets; i++) {
            _addMarket(marketsToAdd[i], true);
        }
    }

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function _addMarket(address market, bool isProxied) internal onlyOwner {
        require(!_allMarkets.contains(market), "Market already exists");

        bytes32 key = IMarketViews(market).marketKey();
        bytes32 baseAsset = IMarketViews(market).baseAsset();

        require(marketForKey[key] == address(0), "Market already exists for key");
        marketForKey[key] = market;
        _allMarkets.add(market);

        if (isProxied) {
            _proxiedMarkets.add(market);
            // if PerpsV2 market => add implementations
            _addImplementations(market);
        } else {
            _legacyMarkets.add(market);
        }

        // Emit the event
        emit MarketAdded(market, baseAsset, key);
    }

    function _removeMarkets(address[] memory marketsToRemove) internal {
        uint numOfMarkets = marketsToRemove.length;
        for (uint i; i < numOfMarkets; i++) {
            address market = marketsToRemove[i];
            require(market != address(0), "Unknown market");

            bytes32 key = IMarketViews(market).marketKey();
            bytes32 baseAsset = IMarketViews(market).baseAsset();

            require(marketForKey[key] != address(0), "Unknown market");

            // if PerpsV2 market => remove implementations
            if (_proxiedMarkets.contains(market)) {
                _removeImplementations(market);
                _proxiedMarkets.remove(market);
            } else {
                _legacyMarkets.remove(market);
            }

            delete marketForKey[key];
            _allMarkets.remove(market);
            emit MarketRemoved(market, baseAsset, key);
        }
    }

    /*
     * Remove a set of markets. Reverts if any market is not known to the manager.
     */
    function removeMarkets(address[] calldata marketsToRemove) external onlyOwner {
        return _removeMarkets(marketsToRemove);
    }

    /*
     * Remove the markets for a given set of market keys. Reverts if any key has no associated market.
     */
    function removeMarketsByKey(bytes32[] calldata marketKeysToRemove) external onlyOwner {
        _removeMarkets(_marketsForKeys(marketKeysToRemove));
    }

    function updateMarketsImplementations(address[] calldata marketsToUpdate) external onlyOwner {
        uint numOfMarkets = marketsToUpdate.length;
        for (uint i; i < numOfMarkets; i++) {
            address market = marketsToUpdate[i];
            require(market != address(0), "Invalid market");
            require(_allMarkets.contains(market), "Unknown market");

            // Remove old implementations
            _removeImplementations(market);

            // Pull new implementations
            _addImplementations(market);
        }
    }

    /*
     * Allows a market to issue sUSD to an account when it withdraws margin.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function issueSUSD(address account, uint amount) external onlyMarketImplementations {
        // No settlement is required to issue synths into the target account.
        _sUSD().issue(account, amount);
    }

    /*
     * Allows a market to burn sUSD from an account when it deposits margin.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function burnSUSD(address account, uint amount) external onlyMarketImplementations returns (uint postReclamationAmount) {
        // We'll settle first, in order to ensure the user has sufficient balance.
        // If the settlement reduces the user's balance below the requested amount,
        // the settled remainder will be the resulting deposit.

        // Exchanger.settle ensures synth is active
        ISynth sUSD = _sUSD();
        (uint reclaimed, , ) = _exchanger().settle(account, SUSD);

        uint balanceAfter = amount;
        if (0 < reclaimed) {
            balanceAfter = IERC20(address(sUSD)).balanceOf(account);
        }

        // Reduce the value to burn if balance is insufficient after reclamation
        amount = balanceAfter < amount ? balanceAfter : amount;

        sUSD.burn(account, amount);

        return amount;
    }

    /**
     * Allows markets to issue exchange fees into the fee pool and notify it that this occurred.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function payFee(uint amount, bytes32 trackingCode) external onlyMarketImplementations {
        _payFee(amount, trackingCode);
    }

    // backwards compatibility with futures v1
    function payFee(uint amount) external onlyMarketImplementations {
        _payFee(amount, bytes32(0));
    }

    function _payFee(uint amount, bytes32 trackingCode) internal {
        delete trackingCode; // unused for now, will be used SIP 203
        IFeePool pool = _feePool();
        _sUSD().issue(pool.FEE_ADDRESS(), amount);
        pool.recordFeePaid(amount);
    }

    /* ========== MODIFIERS ========== */

    function _requireIsMarketOrImplementation() internal view {
        require(
            _legacyMarkets.contains(msg.sender) || _implementations.contains(msg.sender),
            "Permitted only for market implementations"
        );
    }

    modifier onlyMarketImplementations() {
        _requireIsMarketOrImplementation();
        _;
    }

    /* ========== EVENTS ========== */

    event MarketAdded(address market, bytes32 indexed asset, bytes32 indexed marketKey);

    event MarketRemoved(address market, bytes32 indexed asset, bytes32 indexed marketKey);
}


// https://docs.synthetix.io/contracts/source/interfaces/IDirectIntegration
interface IDirectIntegrationManager {
    struct ParameterIntegrationSettings {
        bytes32 currencyKey;
        address dexPriceAggregator;
        address atomicEquivalentForDexPricing;
        uint atomicExchangeFeeRate;
        uint atomicTwapWindow;
        uint atomicMaxVolumePerBlock;
        uint atomicVolatilityConsiderationWindow;
        uint atomicVolatilityUpdateThreshold;
        uint exchangeFeeRate;
        uint exchangeMaxDynamicFee;
        uint exchangeDynamicFeeRounds;
        uint exchangeDynamicFeeThreshold;
        uint exchangeDynamicFeeWeightDecay;
    }

    function getExchangeParameters(address integration, bytes32 key)
        external
        view
        returns (ParameterIntegrationSettings memory settings);

    function setExchangeParameters(
        address integration,
        bytes32[] calldata currencyKeys,
        ParameterIntegrationSettings calldata params
    ) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
    // Structs
    struct RateAndUpdatedTime {
        uint216 rate;
        uint40 time;
    }

    // Views
    function aggregators(bytes32 currencyKey) external view returns (address);

    function aggregatorWarningFlags() external view returns (address);

    function anyRateIsInvalid(bytes32[] calldata currencyKeys) external view returns (bool);

    function anyRateIsInvalidAtRound(bytes32[] calldata currencyKeys, uint[] calldata roundIds) external view returns (bool);

    function currenciesUsingAggregator(address aggregator) external view returns (bytes32[] memory);

    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view returns (uint value);

    function effectiveValueAndRates(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint value,
            uint sourceRate,
            uint destinationRate
        );

    function effectiveValueAndRatesAtRound(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        uint roundIdForSrc,
        uint roundIdForDest
    )
        external
        view
        returns (
            uint value,
            uint sourceRate,
            uint destinationRate
        );

    function effectiveAtomicValueAndRates(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint value,
            uint systemValue,
            uint systemSourceRate,
            uint systemDestinationRate
        );

    function effectiveAtomicValueAndRates(
        IDirectIntegrationManager.ParameterIntegrationSettings calldata sourceSettings,
        uint sourceAmount,
        IDirectIntegrationManager.ParameterIntegrationSettings calldata destinationSettings,
        IDirectIntegrationManager.ParameterIntegrationSettings calldata usdSettings
    )
        external
        view
        returns (
            uint value,
            uint systemValue,
            uint systemSourceRate,
            uint systemDestinationRate
        );

    function getCurrentRoundId(bytes32 currencyKey) external view returns (uint);

    function getLastRoundIdBeforeElapsedSecs(
        bytes32 currencyKey,
        uint startingRoundId,
        uint startingTimestamp,
        uint timediff
    ) external view returns (uint);

    function lastRateUpdateTimes(bytes32 currencyKey) external view returns (uint256);

    function rateAndTimestampAtRound(bytes32 currencyKey, uint roundId) external view returns (uint rate, uint time);

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time);

    function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);

    function rateForCurrency(bytes32 currencyKey) external view returns (uint);

    function rateIsFlagged(bytes32 currencyKey) external view returns (bool);

    function rateIsInvalid(bytes32 currencyKey) external view returns (bool);

    function rateIsStale(bytes32 currencyKey) external view returns (bool);

    function rateStalePeriod() external view returns (uint);

    function ratesAndUpdatedTimeForCurrencyLastNRounds(
        bytes32 currencyKey,
        uint numRounds,
        uint roundId
    ) external view returns (uint[] memory rates, uint[] memory times);

    function ratesAndInvalidForCurrencies(bytes32[] calldata currencyKeys)
        external
        view
        returns (uint[] memory rates, bool anyRateInvalid);

    function ratesForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint[] memory);

    function synthTooVolatileForAtomicExchange(bytes32 currencyKey) external view returns (bool);

    function synthTooVolatileForAtomicExchange(IDirectIntegrationManager.ParameterIntegrationSettings calldata settings)
        external
        view
        returns (bool);

    function rateWithSafetyChecks(bytes32 currencyKey)
        external
        returns (
            uint rate,
            bool broken,
            bool invalid
        );
}


// Libraries


// https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
library SafeDecimalMath {
    using SafeMath for uint;

    /* Number of decimal places in the representations. */
    uint8 public constant decimals = 18;
    uint8 public constant highPrecisionDecimals = 27;

    /* The number representing 1.0. */
    uint public constant UNIT = 10**uint(decimals);

    /* The number representing 1.0 for higher fidelity numbers. */
    uint public constant PRECISE_UNIT = 10**uint(highPrecisionDecimals);
    uint private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = 10**uint(highPrecisionDecimals - decimals);

    /**
     * @return Provides an interface to UNIT.
     */
    function unit() external pure returns (uint) {
        return UNIT;
    }

    /**
     * @return Provides an interface to PRECISE_UNIT.
     */
    function preciseUnit() external pure returns (uint) {
        return PRECISE_UNIT;
    }

    /**
     * @return The result of multiplying x and y, interpreting the operands as fixed-point
     * decimals.
     *
     * @dev A unit factor is divided out after the product of x and y is evaluated,
     * so that product must be less than 2**256. As this is an integer division,
     * the internal division always rounds down. This helps save on gas. Rounding
     * is more expensive on gas.
     */
    function multiplyDecimal(uint x, uint y) internal pure returns (uint) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return x.mul(y) / UNIT;
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of the specified precision unit.
     *
     * @dev The operands should be in the form of a the specified unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRound(
        uint x,
        uint y,
        uint precisionUnit
    ) private pure returns (uint) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        uint quotientTimesTen = x.mul(y) / (precisionUnit / 10);

        if (quotientTimesTen % 10 >= 5) {
            quotientTimesTen += 10;
        }

        return quotientTimesTen / 10;
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a precise unit.
     *
     * @dev The operands should be in the precise unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function multiplyDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
        return _multiplyDecimalRound(x, y, PRECISE_UNIT);
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a standard unit.
     *
     * @dev The operands should be in the standard unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function multiplyDecimalRound(uint x, uint y) internal pure returns (uint) {
        return _multiplyDecimalRound(x, y, UNIT);
    }

    /**
     * @return The result of safely dividing x and y. The return value is a high
     * precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and UNIT must be less than 2**256. As
     * this is an integer division, the result is always rounded down.
     * This helps save on gas. Rounding is more expensive on gas.
     */
    function divideDecimal(uint x, uint y) internal pure returns (uint) {
        /* Reintroduce the UNIT factor that will be divided out by y. */
        return x.mul(UNIT).div(y);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * decimal in the precision unit specified in the parameter.
     *
     * @dev y is divided after the product of x and the specified precision unit
     * is evaluated, so the product of x and the specified precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRound(
        uint x,
        uint y,
        uint precisionUnit
    ) private pure returns (uint) {
        uint resultTimesTen = x.mul(precisionUnit * 10).div(y);

        if (resultTimesTen % 10 >= 5) {
            resultTimesTen += 10;
        }

        return resultTimesTen / 10;
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * standard precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and the standard precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function divideDecimalRound(uint x, uint y) internal pure returns (uint) {
        return _divideDecimalRound(x, y, UNIT);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * high precision decimal.
     *
     * @dev y is divided after the product of x and the high precision unit
     * is evaluated, so the product of x and the high precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function divideDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
        return _divideDecimalRound(x, y, PRECISE_UNIT);
    }

    /**
     * @dev Convert a standard decimal representation to a high precision one.
     */
    function decimalToPreciseDecimal(uint i) internal pure returns (uint) {
        return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
    }

    /**
     * @dev Convert a high precision decimal to a standard decimal representation.
     */
    function preciseDecimalToDecimal(uint i) internal pure returns (uint) {
        uint quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

        if (quotientTimesTen % 10 >= 5) {
            quotientTimesTen += 10;
        }

        return quotientTimesTen / 10;
    }

    // Computes `a - b`, setting the value to 0 if b > a.
    function floorsub(uint a, uint b) internal pure returns (uint) {
        return b >= a ? 0 : a - b;
    }

    /* ---------- Utilities ---------- */
    /*
     * Absolute value of the input, returned as a signed number.
     */
    function signedAbs(int x) internal pure returns (int) {
        return x < 0 ? -x : x;
    }

    /*
     * Absolute value of the input, returned as an unsigned number.
     */
    function abs(int x) internal pure returns (uint) {
        return uint(signedAbs(x));
    }
}


interface AggregatorInterface {
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}


interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}


/**
 * @title The V2 & V3 Aggregator Interface
 * @notice Solidity V0.5 does not allow interfaces to inherit from other
 * interfaces so this contract is a combination of v0.5 AggregatorInterface.sol
 * and v0.5 AggregatorV3Interface.sol.
 */
interface AggregatorV2V3Interface {
  //
  // V2 Interface:
  //
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);

  //
  // V3 Interface:
  //
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}


interface FlagsInterface {
  function getFlag(address) external view returns (bool);
  function getFlags(address[] calldata) external view returns (bool[] memory);
  function raiseFlag(address) external;
  function raiseFlags(address[] calldata) external;
  function lowerFlags(address[] calldata) external;
  function setRaisingAccessController(address) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/ICircuitBreaker
interface ICircuitBreaker {
    // Views
    function isInvalid(address oracleAddress, uint value) external view returns (bool);

    function priceDeviationThresholdFactor() external view returns (uint);

    function isDeviationAboveThreshold(uint base, uint comparison) external view returns (bool);

    function lastValue(address oracleAddress) external view returns (uint);

    function circuitBroken(address oracleAddress) external view returns (bool);

    // Mutative functions
    function resetLastValue(address[] calldata oracleAddresses, uint[] calldata values) external;

    function probeCircuitBreaker(address oracleAddress, uint value) external returns (bool circuitBroken);
}


// Inheritance


// Libraries


// Internal references
// AggregatorInterface from Chainlink represents a decentralized pricing network for a single currency key

// FlagsInterface from Chainlink addresses SIP-76


// https://docs.synthetix.io/contracts/source/contracts/exchangerates
contract ExchangeRates is Owned, MixinSystemSettings, IExchangeRates {
    using SafeMath for uint;
    using SafeDecimalMath for uint;

    bytes32 public constant CONTRACT_NAME = "ExchangeRates";

    bytes32 internal constant CONTRACT_CIRCUIT_BREAKER = "CircuitBreaker";

    //slither-disable-next-line naming-convention
    bytes32 internal constant sUSD = "sUSD";

    // Decentralized oracle networks that feed into pricing aggregators
    mapping(bytes32 => AggregatorV2V3Interface) public aggregators;

    mapping(bytes32 => uint8) public currencyKeyDecimals;

    // List of aggregator keys for convenient iteration
    bytes32[] public aggregatorKeys;

    // ========== CONSTRUCTOR ==========

    constructor(address _owner, address _resolver) public Owned(_owner) MixinSystemSettings(_resolver) {}

    /* ========== MUTATIVE FUNCTIONS ========== */

    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external onlyOwner {
        AggregatorV2V3Interface aggregator = AggregatorV2V3Interface(aggregatorAddress);
        // This check tries to make sure that a valid aggregator is being added.
        // It checks if the aggregator is an existing smart contract that has implemented `latestTimestamp` function.

        require(aggregator.latestRound() >= 0, "Given Aggregator is invalid");
        uint8 decimals = aggregator.decimals();
        // This contract converts all external rates to 18 decimal rates, so adding external rates with
        // higher precision will result in losing precision internally. 27 decimals will result in losing 9 decimal
        // places, which should leave plenty precision for most things.
        require(decimals <= 27, "Aggregator decimals should be lower or equal to 27");
        if (address(aggregators[currencyKey]) == address(0)) {
            aggregatorKeys.push(currencyKey);
        }
        aggregators[currencyKey] = aggregator;
        currencyKeyDecimals[currencyKey] = decimals;
        emit AggregatorAdded(currencyKey, address(aggregator));
    }

    function removeAggregator(bytes32 currencyKey) external onlyOwner {
        address aggregator = address(aggregators[currencyKey]);
        require(aggregator != address(0), "No aggregator exists for key");
        delete aggregators[currencyKey];
        delete currencyKeyDecimals[currencyKey];

        bool wasRemoved = removeFromArray(currencyKey, aggregatorKeys);

        if (wasRemoved) {
            emit AggregatorRemoved(currencyKey, aggregator);
        }
    }

    function rateWithSafetyChecks(bytes32 currencyKey)
        external
        returns (
            uint rate,
            bool broken,
            bool staleOrInvalid
        )
    {
        address aggregatorAddress = address(aggregators[currencyKey]);
        require(currencyKey == sUSD || aggregatorAddress != address(0), "No aggregator for asset");

        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);

        if (currencyKey == sUSD) {
            return (rateAndTime.rate, false, false);
        }

        rate = rateAndTime.rate;
        broken = circuitBreaker().probeCircuitBreaker(aggregatorAddress, rateAndTime.rate);
        staleOrInvalid =
            _rateIsStaleWithTime(getRateStalePeriod(), rateAndTime.time) ||
            _rateIsFlagged(currencyKey, FlagsInterface(getAggregatorWarningFlags()));
    }

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](1);
        newAddresses[0] = CONTRACT_CIRCUIT_BREAKER;

        return combineArrays(existingAddresses, newAddresses);
    }

    function circuitBreaker() internal view returns (ICircuitBreaker) {
        return ICircuitBreaker(requireAndGetAddress(CONTRACT_CIRCUIT_BREAKER));
    }

    function currenciesUsingAggregator(address aggregator) external view returns (bytes32[] memory currencies) {
        uint count = 0;
        currencies = new bytes32[](aggregatorKeys.length);
        for (uint i = 0; i < aggregatorKeys.length; i++) {
            bytes32 currencyKey = aggregatorKeys[i];
            if (address(aggregators[currencyKey]) == aggregator) {
                currencies[count++] = currencyKey;
            }
        }
    }

    function rateStalePeriod() external view returns (uint) {
        return getRateStalePeriod();
    }

    function aggregatorWarningFlags() external view returns (address) {
        return getAggregatorWarningFlags();
    }

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time) {
        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);
        return (rateAndTime.rate, rateAndTime.time);
    }

    function getLastRoundIdBeforeElapsedSecs(
        bytes32 currencyKey,
        uint startingRoundId,
        uint startingTimestamp,
        uint timediff
    ) external view returns (uint) {
        uint roundId = startingRoundId;
        uint nextTimestamp = 0;
        while (true) {
            (, nextTimestamp) = _getRateAndTimestampAtRound(currencyKey, roundId + 1);
            // if there's no new round, then the previous roundId was the latest
            if (nextTimestamp == 0 || nextTimestamp > startingTimestamp + timediff) {
                return roundId;
            }
            roundId++;
        }
        return roundId;
    }

    function getCurrentRoundId(bytes32 currencyKey) external view returns (uint) {
        return _getCurrentRoundId(currencyKey);
    }

    function effectiveValueAndRatesAtRound(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        uint roundIdForSrc,
        uint roundIdForDest
    )
        external
        view
        returns (
            uint value,
            uint sourceRate,
            uint destinationRate
        )
    {
        (sourceRate, ) = _getRateAndTimestampAtRound(sourceCurrencyKey, roundIdForSrc);
        // If there's no change in the currency, then just return the amount they gave us
        if (sourceCurrencyKey == destinationCurrencyKey) {
            destinationRate = sourceRate;
            value = sourceAmount;
        } else {
            (destinationRate, ) = _getRateAndTimestampAtRound(destinationCurrencyKey, roundIdForDest);
            // prevent divide-by 0 error (this happens if the dest is not a valid rate)
            if (destinationRate > 0) {
                // Calculate the effective value by going from source -> USD -> destination
                value = sourceAmount.multiplyDecimalRound(sourceRate).divideDecimalRound(destinationRate);
            }
        }
    }

    function rateAndTimestampAtRound(bytes32 currencyKey, uint roundId) external view returns (uint rate, uint time) {
        return _getRateAndTimestampAtRound(currencyKey, roundId);
    }

    function lastRateUpdateTimes(bytes32 currencyKey) external view returns (uint256) {
        return _getUpdatedTime(currencyKey);
    }

    function lastRateUpdateTimesForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint[] memory) {
        uint[] memory lastUpdateTimes = new uint[](currencyKeys.length);

        for (uint i = 0; i < currencyKeys.length; i++) {
            lastUpdateTimes[i] = _getUpdatedTime(currencyKeys[i]);
        }

        return lastUpdateTimes;
    }

    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view returns (uint value) {
        (value, , ) = _effectiveValueAndRates(sourceCurrencyKey, sourceAmount, destinationCurrencyKey);
    }

    function effectiveValueAndRates(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint value,
            uint sourceRate,
            uint destinationRate
        )
    {
        return _effectiveValueAndRates(sourceCurrencyKey, sourceAmount, destinationCurrencyKey);
    }

    // SIP-120 Atomic exchanges
    function effectiveAtomicValueAndRates(
        bytes32,
        uint,
        bytes32
    )
        public
        view
        returns (
            uint value,
            uint systemValue,
            uint systemSourceRate,
            uint systemDestinationRate
        )
    {
        _notImplemented();
    }

    function effectiveAtomicValueAndRates(
        IDirectIntegrationManager.ParameterIntegrationSettings memory,
        uint,
        IDirectIntegrationManager.ParameterIntegrationSettings memory,
        IDirectIntegrationManager.ParameterIntegrationSettings memory
    )
        public
        view
        returns (
            uint value,
            uint systemValue,
            uint systemSourceRate,
            uint systemDestinationRate
        )
    {
        _notImplemented();
    }

    function rateForCurrency(bytes32 currencyKey) external view returns (uint) {
        return _getRateAndUpdatedTime(currencyKey).rate;
    }

    /// @notice getting N rounds of rates for a currency at a specific round
    /// @param currencyKey the currency key
    /// @param numRounds the number of rounds to get
    /// @param roundId the round id
    /// @return a list of rates and a list of times
    function ratesAndUpdatedTimeForCurrencyLastNRounds(
        bytes32 currencyKey,
        uint numRounds,
        uint roundId
    ) external view returns (uint[] memory rates, uint[] memory times) {
        rates = new uint[](numRounds);
        times = new uint[](numRounds);

        roundId = roundId > 0 ? roundId : _getCurrentRoundId(currencyKey);
        for (uint i = 0; i < numRounds; i++) {
            // fetch the rate and treat is as current, so inverse limits if frozen will always be applied
            // regardless of current rate
            (rates[i], times[i]) = _getRateAndTimestampAtRound(currencyKey, roundId);

            if (roundId == 0) {
                // if we hit the last round, then return what we have
                return (rates, times);
            } else {
                roundId--;
            }
        }
    }

    function ratesForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint[] memory) {
        uint[] memory _localRates = new uint[](currencyKeys.length);

        for (uint i = 0; i < currencyKeys.length; i++) {
            _localRates[i] = _getRate(currencyKeys[i]);
        }

        return _localRates;
    }

    function rateAndInvalid(bytes32 currencyKey) public view returns (uint rate, bool isInvalid) {
        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);

        if (currencyKey == sUSD) {
            return (rateAndTime.rate, false);
        }
        return (
            rateAndTime.rate,
            _rateIsStaleWithTime(getRateStalePeriod(), rateAndTime.time) ||
                _rateIsFlagged(currencyKey, FlagsInterface(getAggregatorWarningFlags())) ||
                _rateIsCircuitBroken(currencyKey, rateAndTime.rate)
        );
    }

    function ratesAndInvalidForCurrencies(bytes32[] calldata currencyKeys)
        external
        view
        returns (uint[] memory rates, bool anyRateInvalid)
    {
        rates = new uint[](currencyKeys.length);

        uint256 _rateStalePeriod = getRateStalePeriod();

        // fetch all flags at once
        bool[] memory flagList = getFlagsForRates(currencyKeys);

        for (uint i = 0; i < currencyKeys.length; i++) {
            // do one lookup of the rate & time to minimize gas
            RateAndUpdatedTime memory rateEntry = _getRateAndUpdatedTime(currencyKeys[i]);
            rates[i] = rateEntry.rate;
            if (!anyRateInvalid && currencyKeys[i] != sUSD) {
                anyRateInvalid =
                    flagList[i] ||
                    _rateIsStaleWithTime(_rateStalePeriod, rateEntry.time) ||
                    _rateIsCircuitBroken(currencyKeys[i], rateEntry.rate);
            }
        }
    }

    function rateIsStale(bytes32 currencyKey) external view returns (bool) {
        return _rateIsStale(currencyKey, getRateStalePeriod());
    }

    function rateIsInvalid(bytes32 currencyKey) external view returns (bool) {
        (, bool invalid) = rateAndInvalid(currencyKey);
        return invalid;
    }

    function rateIsFlagged(bytes32 currencyKey) external view returns (bool) {
        return _rateIsFlagged(currencyKey, FlagsInterface(getAggregatorWarningFlags()));
    }

    function anyRateIsInvalid(bytes32[] calldata currencyKeys) external view returns (bool) {
        // Loop through each key and check whether the data point is stale.

        uint256 _rateStalePeriod = getRateStalePeriod();
        bool[] memory flagList = getFlagsForRates(currencyKeys);

        for (uint i = 0; i < currencyKeys.length; i++) {
            if (currencyKeys[i] == sUSD) {
                continue;
            }

            RateAndUpdatedTime memory rateEntry = _getRateAndUpdatedTime(currencyKeys[i]);
            if (
                flagList[i] ||
                _rateIsStaleWithTime(_rateStalePeriod, rateEntry.time) ||
                _rateIsCircuitBroken(currencyKeys[i], rateEntry.rate)
            ) {
                return true;
            }
        }

        return false;
    }

    /// this method checks whether any rate is:
    /// 1. flagged
    /// 2. stale with respect to current time (now)
    function anyRateIsInvalidAtRound(bytes32[] calldata currencyKeys, uint[] calldata roundIds)
        external
        view
        returns (bool)
    {
        // Loop through each key and check whether the data point is stale.

        require(roundIds.length == currencyKeys.length, "roundIds must be the same length as currencyKeys");

        uint256 _rateStalePeriod = getRateStalePeriod();
        bool[] memory flagList = getFlagsForRates(currencyKeys);

        for (uint i = 0; i < currencyKeys.length; i++) {
            if (currencyKeys[i] == sUSD) {
                continue;
            }

            // NOTE: technically below `_rateIsStaleWithTime` is supposed to be called with the roundId timestamp in consideration, and `_rateIsCircuitBroken` is supposed to be
            // called with the current rate (or just not called at all)
            // but thats not how the functionality has worked prior to this change so that is why it works this way here
            // if you are adding new code taht calls this function and the rate is a long time ago, note that this function may resolve an invalid rate when its actually valid!
            (uint rate, uint time) = _getRateAndTimestampAtRound(currencyKeys[i], roundIds[i]);
            if (flagList[i] || _rateIsStaleWithTime(_rateStalePeriod, time) || _rateIsCircuitBroken(currencyKeys[i], rate)) {
                return true;
            }
        }

        return false;
    }

    function synthTooVolatileForAtomicExchange(bytes32) public view returns (bool) {
        _notImplemented();
    }

    function synthTooVolatileForAtomicExchange(IDirectIntegrationManager.ParameterIntegrationSettings memory)
        public
        view
        returns (bool)
    {
        _notImplemented();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function getFlagsForRates(bytes32[] memory currencyKeys) internal view returns (bool[] memory flagList) {
        FlagsInterface _flags = FlagsInterface(getAggregatorWarningFlags());

        // fetch all flags at once
        if (_flags != FlagsInterface(0)) {
            address[] memory _aggregators = new address[](currencyKeys.length);

            for (uint i = 0; i < currencyKeys.length; i++) {
                _aggregators[i] = address(aggregators[currencyKeys[i]]);
            }

            flagList = _flags.getFlags(_aggregators);
        } else {
            flagList = new bool[](currencyKeys.length);
        }
    }

    function removeFromArray(bytes32 entry, bytes32[] storage array) internal returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == entry) {
                delete array[i];

                // Copy the last key into the place of the one we just deleted
                // If there's only one key, this is array[0] = array[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                array[i] = array[array.length - 1];

                // Decrease the size of the array by one.
                array.length--;

                return true;
            }
        }
        return false;
    }

    function _formatAggregatorAnswer(bytes32 currencyKey, int256 rate) internal view returns (uint) {
        require(rate >= 0, "Negative rate not supported");
        uint decimals = currencyKeyDecimals[currencyKey];
        uint result = uint(rate);
        if (decimals == 0 || decimals == 18) {
            // do not convert for 0 (part of implicit interface), and not needed for 18
        } else if (decimals < 18) {
            // increase precision to 18
            uint multiplier = 10**(18 - decimals); // SafeMath not needed since decimals is small
            result = result.mul(multiplier);
        } else if (decimals > 18) {
            // decrease precision to 18
            uint divisor = 10**(decimals - 18); // SafeMath not needed since decimals is small
            result = result.div(divisor);
        }
        return result;
    }

    function _getRateAndUpdatedTime(bytes32 currencyKey) internal view returns (RateAndUpdatedTime memory) {
        // sUSD rate is 1.0
        if (currencyKey == sUSD) {
            return RateAndUpdatedTime({rate: uint216(SafeDecimalMath.unit()), time: 0});
        } else {
            AggregatorV2V3Interface aggregator = aggregators[currencyKey];
            if (aggregator != AggregatorV2V3Interface(0)) {
                // this view from the aggregator is the most gas efficient but it can throw when there's no data,
                // so let's call it low-level to suppress any reverts
                bytes memory payload = abi.encodeWithSignature("latestRoundData()");
                // solhint-disable avoid-low-level-calls
                // slither-disable-next-line low-level-calls
                (bool success, bytes memory returnData) = address(aggregator).staticcall(payload);

                if (success) {
                    (, int256 answer, , uint256 updatedAt, ) =
                        abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));
                    return
                        RateAndUpdatedTime({
                            rate: uint216(_formatAggregatorAnswer(currencyKey, answer)),
                            time: uint40(updatedAt)
                        });
                } // else return defaults, to avoid reverting in views
            } // else return defaults, to avoid reverting in views
        }
    }

    function _getCurrentRoundId(bytes32 currencyKey) internal view returns (uint) {
        if (currencyKey == sUSD) {
            return 0;
        }
        AggregatorV2V3Interface aggregator = aggregators[currencyKey];
        if (aggregator != AggregatorV2V3Interface(0)) {
            return aggregator.latestRound();
        } // else return defaults, to avoid reverting in views
    }

    function _getRateAndTimestampAtRound(bytes32 currencyKey, uint roundId) internal view returns (uint rate, uint time) {
        // short circuit sUSD
        if (currencyKey == sUSD) {
            // sUSD has no rounds, and 0 time is preferrable for "volatility" heuristics
            // which are used in atomic swaps and fee reclamation
            return (SafeDecimalMath.unit(), 0);
        } else {
            AggregatorV2V3Interface aggregator = aggregators[currencyKey];
            if (aggregator != AggregatorV2V3Interface(0)) {
                // this view from the aggregator is the most gas efficient but it can throw when there's no data,
                // so let's call it low-level to suppress any reverts
                bytes memory payload = abi.encodeWithSignature("getRoundData(uint80)", roundId);
                // solhint-disable avoid-low-level-calls
                (bool success, bytes memory returnData) = address(aggregator).staticcall(payload);

                if (success) {
                    (, int256 answer, , uint256 updatedAt, ) =
                        abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));
                    return (_formatAggregatorAnswer(currencyKey, answer), updatedAt);
                } // else return defaults, to avoid reverting in views
            } // else return defaults, to avoid reverting in views
        }
    }

    function _getRate(bytes32 currencyKey) internal view returns (uint256) {
        return _getRateAndUpdatedTime(currencyKey).rate;
    }

    function _getUpdatedTime(bytes32 currencyKey) internal view returns (uint256) {
        return _getRateAndUpdatedTime(currencyKey).time;
    }

    function _effectiveValueAndRates(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        internal
        view
        returns (
            uint value,
            uint sourceRate,
            uint destinationRate
        )
    {
        sourceRate = _getRate(sourceCurrencyKey);
        // If there's no change in the currency, then just return the amount they gave us
        if (sourceCurrencyKey == destinationCurrencyKey) {
            destinationRate = sourceRate;
            value = sourceAmount;
        } else {
            // Calculate the effective value by going from source -> USD -> destination
            destinationRate = _getRate(destinationCurrencyKey);
            // prevent divide-by 0 error (this happens if the dest is not a valid rate)
            if (destinationRate > 0) {
                value = sourceAmount.multiplyDecimalRound(sourceRate).divideDecimalRound(destinationRate);
            }
        }
    }

    function _rateIsStale(bytes32 currencyKey, uint _rateStalePeriod) internal view returns (bool) {
        // sUSD is a special case and is never stale (check before an SLOAD of getRateAndUpdatedTime)
        if (currencyKey == sUSD) {
            return false;
        }
        return _rateIsStaleWithTime(_rateStalePeriod, _getUpdatedTime(currencyKey));
    }

    function _rateIsStaleWithTime(uint _rateStalePeriod, uint _time) internal view returns (bool) {
        return _time.add(_rateStalePeriod) < now;
    }

    function _rateIsFlagged(bytes32 currencyKey, FlagsInterface flags) internal view returns (bool) {
        // sUSD is a special case and is never invalid
        if (currencyKey == sUSD) {
            return false;
        }
        address aggregator = address(aggregators[currencyKey]);
        // when no aggregator or when the flags haven't been setup
        if (aggregator == address(0) || flags == FlagsInterface(0)) {
            return false;
        }
        return flags.getFlag(aggregator);
    }

    function _rateIsCircuitBroken(bytes32 currencyKey, uint curRate) internal view returns (bool) {
        return circuitBreaker().isInvalid(address(aggregators[currencyKey]), curRate);
    }

    function _notImplemented() internal pure {
        // slither-disable-next-line dead-code
        revert("Cannot be run on this layer");
    }

    /* ========== EVENTS ========== */

    event AggregatorAdded(bytes32 currencyKey, address aggregator);
    event AggregatorRemoved(bytes32 currencyKey, address aggregator);
}


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/MixinPerpsV2MarketSettings
contract MixinPerpsV2MarketSettings is MixinResolver {
    /* ========== CONSTANTS ========== */

    bytes32 internal constant SETTING_CONTRACT_NAME = "PerpsV2MarketSettings";

    /* ---------- Parameter Names ---------- */

    // Per-market settings
    bytes32 internal constant PARAMETER_TAKER_FEE = "takerFee";
    bytes32 internal constant PARAMETER_MAKER_FEE = "makerFee";
    bytes32 internal constant PARAMETER_OVERRIDE_COMMIT_FEE = "overrideCommitFee";
    bytes32 internal constant PARAMETER_TAKER_FEE_DELAYED_ORDER = "takerFeeDelayedOrder";
    bytes32 internal constant PARAMETER_MAKER_FEE_DELAYED_ORDER = "makerFeeDelayedOrder";
    bytes32 internal constant PARAMETER_TAKER_FEE_OFFCHAIN_DELAYED_ORDER = "takerFeeOffchainDelayedOrder";
    bytes32 internal constant PARAMETER_MAKER_FEE_OFFCHAIN_DELAYED_ORDER = "makerFeeOffchainDelayedOrder";
    bytes32 internal constant PARAMETER_NEXT_PRICE_CONFIRM_WINDOW = "nextPriceConfirmWindow";
    bytes32 internal constant PARAMETER_DELAYED_ORDER_CONFIRM_WINDOW = "delayedOrderConfirmWindow";
    bytes32 internal constant PARAMETER_OFFCHAIN_DELAYED_ORDER_MIN_AGE = "offchainDelayedOrderMinAge";
    bytes32 internal constant PARAMETER_OFFCHAIN_DELAYED_ORDER_MAX_AGE = "offchainDelayedOrderMaxAge";
    bytes32 internal constant PARAMETER_MAX_LEVERAGE = "maxLeverage";
    bytes32 internal constant PARAMETER_MAX_MARKET_VALUE = "maxMarketValue";
    bytes32 internal constant PARAMETER_MAX_FUNDING_VELOCITY = "maxFundingVelocity";
    bytes32 internal constant PARAMETER_MIN_SKEW_SCALE = "skewScale";
    bytes32 internal constant PARAMETER_MIN_DELAY_TIME_DELTA = "minDelayTimeDelta";
    bytes32 internal constant PARAMETER_MAX_DELAY_TIME_DELTA = "maxDelayTimeDelta";
    bytes32 internal constant PARAMETER_OFFCHAIN_MARKET_KEY = "offchainMarketKey";
    bytes32 internal constant PARAMETER_OFFCHAIN_PRICE_DIVERGENCE = "offchainPriceDivergence";
    bytes32 internal constant PARAMETER_LIQUIDATION_PREMIUM_MULTIPLIER = "liquidationPremiumMultiplier";

    // Global settings
    // minimum liquidation fee payable to liquidator
    bytes32 internal constant SETTING_MIN_KEEPER_FEE = "perpsV2MinKeeperFee";
    // maximum liquidation fee payable to liquidator
    bytes32 internal constant SETTING_MAX_KEEPER_FEE = "perpsV2MaxKeeperFee";
    // liquidation fee basis points payed to liquidator
    bytes32 internal constant SETTING_LIQUIDATION_FEE_RATIO = "perpsV2LiquidationFeeRatio";
    // liquidation buffer to prevent negative margin upon liquidation
    bytes32 internal constant SETTING_LIQUIDATION_BUFFER_RATIO = "perpsV2LiquidationBufferRatio";
    bytes32 internal constant SETTING_MIN_INITIAL_MARGIN = "perpsV2MinInitialMargin";

    /* ---------- Address Resolver Configuration ---------- */

    bytes32 internal constant CONTRACT_FLEXIBLESTORAGE = "FlexibleStorage";

    /* ========== CONSTRUCTOR ========== */

    constructor(address _resolver) internal MixinResolver(_resolver) {}

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        addresses = new bytes32[](1);
        addresses[0] = CONTRACT_FLEXIBLESTORAGE;
    }

    function _flexibleStorage() internal view returns (IFlexibleStorage) {
        return IFlexibleStorage(requireAndGetAddress(CONTRACT_FLEXIBLESTORAGE));
    }

    /* ---------- Internals ---------- */

    function _parameter(bytes32 _marketKey, bytes32 key) internal view returns (uint value) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, keccak256(abi.encodePacked(_marketKey, key)));
    }

    function _takerFee(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_TAKER_FEE);
    }

    function _makerFee(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAKER_FEE);
    }

    function _overrideCommitFee(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_OVERRIDE_COMMIT_FEE);
    }

    function _takerFeeDelayedOrder(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_TAKER_FEE_DELAYED_ORDER);
    }

    function _makerFeeDelayedOrder(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAKER_FEE_DELAYED_ORDER);
    }

    function _takerFeeOffchainDelayedOrder(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_TAKER_FEE_OFFCHAIN_DELAYED_ORDER);
    }

    function _makerFeeOffchainDelayedOrder(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAKER_FEE_OFFCHAIN_DELAYED_ORDER);
    }

    function _nextPriceConfirmWindow(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_NEXT_PRICE_CONFIRM_WINDOW);
    }

    function _delayedOrderConfirmWindow(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_DELAYED_ORDER_CONFIRM_WINDOW);
    }

    function _offchainDelayedOrderMinAge(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_OFFCHAIN_DELAYED_ORDER_MIN_AGE);
    }

    function _offchainDelayedOrderMaxAge(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_OFFCHAIN_DELAYED_ORDER_MAX_AGE);
    }

    function _maxLeverage(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_LEVERAGE);
    }

    function _maxMarketValue(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_MARKET_VALUE);
    }

    function _skewScale(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MIN_SKEW_SCALE);
    }

    function _maxFundingVelocity(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_FUNDING_VELOCITY);
    }

    function _minDelayTimeDelta(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MIN_DELAY_TIME_DELTA);
    }

    function _maxDelayTimeDelta(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_DELAY_TIME_DELTA);
    }

    function _offchainMarketKey(bytes32 _marketKey) internal view returns (bytes32) {
        return
            _flexibleStorage().getBytes32Value(
                SETTING_CONTRACT_NAME,
                keccak256(abi.encodePacked(_marketKey, PARAMETER_OFFCHAIN_MARKET_KEY))
            );
    }

    function _offchainPriceDivergence(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_OFFCHAIN_PRICE_DIVERGENCE);
    }

    function _liquidationPremiumMultiplier(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_LIQUIDATION_PREMIUM_MULTIPLIER);
    }

    function _minKeeperFee() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_KEEPER_FEE);
    }

    function _maxKeeperFee() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_MAX_KEEPER_FEE);
    }

    function _liquidationFeeRatio() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_FEE_RATIO);
    }

    function _liquidationBufferRatio() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_BUFFER_RATIO);
    }

    function _minInitialMargin() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_INITIAL_MARGIN);
    }
}


interface IPerpsV2MarketSettings {
    struct Parameters {
        uint takerFee;
        uint makerFee;
        uint overrideCommitFee;
        uint takerFeeDelayedOrder;
        uint makerFeeDelayedOrder;
        uint takerFeeOffchainDelayedOrder;
        uint makerFeeOffchainDelayedOrder;
        uint maxLeverage;
        uint maxMarketValue;
        uint maxFundingVelocity;
        uint skewScale;
        uint nextPriceConfirmWindow;
        uint delayedOrderConfirmWindow;
        uint minDelayTimeDelta;
        uint maxDelayTimeDelta;
        uint offchainDelayedOrderMinAge;
        uint offchainDelayedOrderMaxAge;
        bytes32 offchainMarketKey;
        uint offchainPriceDivergence;
        uint liquidationPremiumMultiplier;
    }

    function takerFee(bytes32 _marketKey) external view returns (uint);

    function makerFee(bytes32 _marketKey) external view returns (uint);

    function takerFeeDelayedOrder(bytes32 _marketKey) external view returns (uint);

    function makerFeeDelayedOrder(bytes32 _marketKey) external view returns (uint);

    function takerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint);

    function makerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint);

    function nextPriceConfirmWindow(bytes32 _marketKey) external view returns (uint);

    function delayedOrderConfirmWindow(bytes32 _marketKey) external view returns (uint);

    function offchainDelayedOrderMinAge(bytes32 _marketKey) external view returns (uint);

    function offchainDelayedOrderMaxAge(bytes32 _marketKey) external view returns (uint);

    function maxLeverage(bytes32 _marketKey) external view returns (uint);

    function maxMarketValue(bytes32 _marketKey) external view returns (uint);

    function maxFundingVelocity(bytes32 _marketKey) external view returns (uint);

    function skewScale(bytes32 _marketKey) external view returns (uint);

    function minDelayTimeDelta(bytes32 _marketKey) external view returns (uint);

    function maxDelayTimeDelta(bytes32 _marketKey) external view returns (uint);

    function parameters(bytes32 _marketKey) external view returns (Parameters memory);

    function offchainMarketKey(bytes32 _marketKey) external view returns (bytes32);

    function offchainPriceDivergence(bytes32 _marketKey) external view returns (uint);

    function liquidationPremiumMultiplier(bytes32 _marketKey) external view returns (uint);

    function minKeeperFee() external view returns (uint);

    function maxKeeperFee() external view returns (uint);

    function liquidationFeeRatio() external view returns (uint);

    function liquidationBufferRatio() external view returns (uint);

    function minInitialMargin() external view returns (uint);
}


interface IPerpsV2MarketBaseTypes {
    /* ========== TYPES ========== */

    enum OrderType {Atomic, Delayed, Offchain}

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderType,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // Delayed order storage
    struct DelayedOrder {
        bool isOffchain; // flag indicating the delayed order is offchain
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 priceImpactDelta; // price impact tolerance as a percentage used on fillPrice at execution
        uint128 targetRoundId; // price oracle roundId using which price this order needs to executed
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint256 executableAtTime; // The timestamp at which this order is executable at
        uint256 intentionTime; // The block timestamp of submission
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }
}


interface IPerpsV2MarketViews {
    /* ---------- Market Details ---------- */

    function marketKey() external view returns (bytes32 key);

    function baseAsset() external view returns (bytes32 key);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingLastRecomputed() external view returns (uint32 timestamp);

    function fundingSequence(uint index) external view returns (int128 netFunding);

    function positions(address account) external view returns (IPerpsV2MarketBaseTypes.Position memory);

    function assetPrice() external view returns (uint price, bool invalid);

    function marketSizes() external view returns (uint long, uint short);

    function marketDebt() external view returns (uint debt, bool isInvalid);

    function currentFundingRate() external view returns (int fundingRate);

    function currentFundingVelocity() external view returns (int fundingVelocity);

    function unrecordedFunding() external view returns (int funding, bool invalid);

    function fundingSequenceLength() external view returns (uint length);

    /* ---------- Position Details ---------- */

    function notionalValue(address account) external view returns (int value, bool invalid);

    function profitLoss(address account) external view returns (int pnl, bool invalid);

    function accruedFunding(address account) external view returns (int funding, bool invalid);

    function remainingMargin(address account) external view returns (uint marginRemaining, bool invalid);

    function accessibleMargin(address account) external view returns (uint marginAccessible, bool invalid);

    function liquidationPrice(address account) external view returns (uint price, bool invalid);

    function liquidationFee(address account) external view returns (uint);

    function canLiquidate(address account) external view returns (bool);

    function orderFee(int sizeDelta, IPerpsV2MarketBaseTypes.OrderType orderType)
        external
        view
        returns (uint fee, bool invalid);

    function postTradeDetails(
        int sizeDelta,
        uint tradePrice,
        IPerpsV2MarketBaseTypes.OrderType orderType,
        address sender
    )
        external
        view
        returns (
            uint margin,
            int size,
            uint price,
            uint liqPrice,
            uint fee,
            IPerpsV2MarketBaseTypes.Status status
        );
}


interface IPerpsV2Market {
    /* ========== FUNCTION INTERFACE ========== */

    /* ---------- Market Operations ---------- */

    function recomputeFunding() external returns (uint lastIndex);

    function transferMargin(int marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPosition(int sizeDelta, uint priceImpactDelta) external;

    function modifyPositionWithTracking(
        int sizeDelta,
        uint priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function closePosition(uint priceImpactDelta) external;

    function closePositionWithTracking(uint priceImpactDelta, bytes32 trackingCode) external;

    function liquidatePosition(address account) external;
}


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketSettings
contract PerpsV2MarketSettings is Owned, MixinPerpsV2MarketSettings, IPerpsV2MarketSettings {
    /* ========== CONSTANTS ========== */

    /* ---------- Address Resolver Configuration ---------- */

    bytes32 internal constant CONTRACT_FUTURES_MARKET_MANAGER = "FuturesMarketManager";

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _resolver) public Owned(_owner) MixinPerpsV2MarketSettings(_resolver) {}

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinPerpsV2MarketSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](1);
        newAddresses[0] = CONTRACT_FUTURES_MARKET_MANAGER;
        addresses = combineArrays(existingAddresses, newAddresses);
    }

    function _futuresMarketManager() internal view returns (IFuturesMarketManager) {
        return IFuturesMarketManager(requireAndGetAddress(CONTRACT_FUTURES_MARKET_MANAGER));
    }

    /* ---------- Getters ---------- */

    /*
     * The fee charged when opening a position on the heavy side of a perpsV2 market.
     */
    function takerFee(bytes32 _marketKey) external view returns (uint) {
        return _takerFee(_marketKey);
    }

    /*
     * The fee charged when opening a position on the light side of a perpsV2 market.
     */
    function makerFee(bytes32 _marketKey) public view returns (uint) {
        return _makerFee(_marketKey);
    }

    /*
     * The fee charged as commit fee if set. It will override the default calculation if this value is larger than  zero.
     */
    function overrideCommitFee(bytes32 _marketKey) external view returns (uint) {
        return _parameter(_marketKey, PARAMETER_OVERRIDE_COMMIT_FEE);
    }

    /*
     * The fee charged when opening a position on the heavy side of a perpsV2 market using delayed order mechanism.
     */
    function takerFeeDelayedOrder(bytes32 _marketKey) external view returns (uint) {
        return _takerFeeDelayedOrder(_marketKey);
    }

    /*
     * The fee charged when opening a position on the light side of a perpsV2 market using delayed order mechanism.
     */
    function makerFeeDelayedOrder(bytes32 _marketKey) public view returns (uint) {
        return _makerFeeDelayedOrder(_marketKey);
    }

    /*
     * The fee charged when opening a position on the heavy side of a perpsV2 market using offchain delayed order mechanism.
     */
    function takerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint) {
        return _takerFeeOffchainDelayedOrder(_marketKey);
    }

    /*
     * The fee charged when opening a position on the light side of a perpsV2 market using offchain delayed order mechanism.
     */
    function makerFeeOffchainDelayedOrder(bytes32 _marketKey) public view returns (uint) {
        return _makerFeeOffchainDelayedOrder(_marketKey);
    }

    /*
     * The number of price update rounds during which confirming next-price is allowed
     */
    function nextPriceConfirmWindow(bytes32 _marketKey) public view returns (uint) {
        return _nextPriceConfirmWindow(_marketKey);
    }

    /*
     * The amount of time in seconds which confirming delayed orders is allow
     */
    function delayedOrderConfirmWindow(bytes32 _marketKey) public view returns (uint) {
        return _delayedOrderConfirmWindow(_marketKey);
    }

    /*
     * The amount of time in seconds which confirming delayed orders is allow
     */
    function offchainDelayedOrderMinAge(bytes32 _marketKey) public view returns (uint) {
        return _offchainDelayedOrderMinAge(_marketKey);
    }

    /*
     * The amount of time in seconds which confirming delayed orders is allow
     */
    function offchainDelayedOrderMaxAge(bytes32 _marketKey) public view returns (uint) {
        return _offchainDelayedOrderMaxAge(_marketKey);
    }

    /*
     * The maximum allowable leverage in a market.
     */
    function maxLeverage(bytes32 _marketKey) public view returns (uint) {
        return _maxLeverage(_marketKey);
    }

    /*
     * The maximum allowable value (base asset) on each side of a market.
     */
    function maxMarketValue(bytes32 _marketKey) public view returns (uint) {
        return _maxMarketValue(_marketKey);
    }

    /*
     * The skew level at which the max funding velocity will be charged.
     */
    function skewScale(bytes32 _marketKey) public view returns (uint) {
        return _skewScale(_marketKey);
    }

    /*
     * The maximum theoretical funding velocity per day charged by a market.
     */
    function maxFundingVelocity(bytes32 _marketKey) public view returns (uint) {
        return _maxFundingVelocity(_marketKey);
    }

    /*
     * The off-chain delayed order lower bound whereby the desired delta must be greater than or equal to.
     */
    function minDelayTimeDelta(bytes32 _marketKey) public view returns (uint) {
        return _minDelayTimeDelta(_marketKey);
    }

    /*
     * The off-chain delayed order upper bound whereby the desired delta must be greater than or equal to.
     */
    function maxDelayTimeDelta(bytes32 _marketKey) public view returns (uint) {
        return _maxDelayTimeDelta(_marketKey);
    }

    /*
     * The off-chain delayed order market key, used to pause and resume offchain markets.
     */
    function offchainMarketKey(bytes32 _marketKey) public view returns (bytes32) {
        return _offchainMarketKey(_marketKey);
    }

    /*
     * The max divergence between onchain and offchain prices for an offchain delayed order execution.
     */
    function offchainPriceDivergence(bytes32 _marketKey) public view returns (uint) {
        return _offchainPriceDivergence(_marketKey);
    }

    /*
     * The liquidation premium multiplier applied when calculating the liquidation premium margin.
     */
    function liquidationPremiumMultiplier(bytes32 _marketKey) public view returns (uint) {
        return _liquidationPremiumMultiplier(_marketKey);
    }

    function parameters(bytes32 _marketKey) external view returns (Parameters memory) {
        return
            Parameters(
                _takerFee(_marketKey),
                _makerFee(_marketKey),
                _overrideCommitFee(_marketKey),
                _takerFeeDelayedOrder(_marketKey),
                _makerFeeDelayedOrder(_marketKey),
                _takerFeeOffchainDelayedOrder(_marketKey),
                _makerFeeOffchainDelayedOrder(_marketKey),
                _maxLeverage(_marketKey),
                _maxMarketValue(_marketKey),
                _maxFundingVelocity(_marketKey),
                _skewScale(_marketKey),
                _nextPriceConfirmWindow(_marketKey),
                _delayedOrderConfirmWindow(_marketKey),
                _minDelayTimeDelta(_marketKey),
                _maxDelayTimeDelta(_marketKey),
                _offchainDelayedOrderMinAge(_marketKey),
                _offchainDelayedOrderMaxAge(_marketKey),
                _offchainMarketKey(_marketKey),
                _offchainPriceDivergence(_marketKey),
                _liquidationPremiumMultiplier(_marketKey)
            );
    }

    /*
     * The minimum amount of sUSD paid to a liquidator when they successfully liquidate a position.
     * This quantity must be no greater than `minInitialMargin`.
     */
    function minKeeperFee() external view returns (uint) {
        return _minKeeperFee();
    }

    /*
     * The maximum amount of sUSD paid to a liquidator when they successfully liquidate a position.
     */
    function maxKeeperFee() external view returns (uint) {
        return _maxKeeperFee();
    }

    /*
     * Liquidation fee basis points paid to liquidator.
     * Use together with minKeeperFee() and maxKeeperFee() to calculate the actual fee paid.
     */
    function liquidationFeeRatio() external view returns (uint) {
        return _liquidationFeeRatio();
    }

    /*
     * Liquidation price buffer in basis points to prevent negative margin on liquidation.
     */
    function liquidationBufferRatio() external view returns (uint) {
        return _liquidationBufferRatio();
    }

    /*
     * The minimum margin required to open a position.
     * This quantity must be no less than `minKeeperFee`.
     */
    function minInitialMargin() external view returns (uint) {
        return _minInitialMargin();
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Setters --------- */

    function _setParameter(
        bytes32 _marketKey,
        bytes32 key,
        uint value
    ) internal {
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, keccak256(abi.encodePacked(_marketKey, key)), value);
        emit ParameterUpdated(_marketKey, key, value);
    }

    function setTakerFee(bytes32 _marketKey, uint _takerFee) public onlyOwner {
        require(_takerFee <= 1e18, "taker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_TAKER_FEE, _takerFee);
    }

    function setMakerFee(bytes32 _marketKey, uint _makerFee) public onlyOwner {
        require(_makerFee <= 1e18, "maker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_MAKER_FEE, _makerFee);
    }

    function setOverrideCommitFee(bytes32 _marketKey, uint _overrideCommitFee) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_OVERRIDE_COMMIT_FEE, _overrideCommitFee);
    }

    function setTakerFeeDelayedOrder(bytes32 _marketKey, uint _takerFeeDelayedOrder) public onlyOwner {
        require(_takerFeeDelayedOrder <= 1e18, "taker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_TAKER_FEE_DELAYED_ORDER, _takerFeeDelayedOrder);
    }

    function setMakerFeeDelayedOrder(bytes32 _marketKey, uint _makerFeeDelayedOrder) public onlyOwner {
        require(_makerFeeDelayedOrder <= 1e18, "maker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_MAKER_FEE_DELAYED_ORDER, _makerFeeDelayedOrder);
    }

    function setTakerFeeOffchainDelayedOrder(bytes32 _marketKey, uint _takerFeeOffchainDelayedOrder) public onlyOwner {
        require(_takerFeeOffchainDelayedOrder <= 1e18, "taker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_TAKER_FEE_OFFCHAIN_DELAYED_ORDER, _takerFeeOffchainDelayedOrder);
    }

    function setMakerFeeOffchainDelayedOrder(bytes32 _marketKey, uint _makerFeeOffchainDelayedOrder) public onlyOwner {
        require(_makerFeeOffchainDelayedOrder <= 1e18, "maker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_MAKER_FEE_OFFCHAIN_DELAYED_ORDER, _makerFeeOffchainDelayedOrder);
    }

    function setNextPriceConfirmWindow(bytes32 _marketKey, uint _nextPriceConfirmWindow) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_NEXT_PRICE_CONFIRM_WINDOW, _nextPriceConfirmWindow);
    }

    function setDelayedOrderConfirmWindow(bytes32 _marketKey, uint _delayedOrderConfirmWindow) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_DELAYED_ORDER_CONFIRM_WINDOW, _delayedOrderConfirmWindow);
    }

    function setOffchainDelayedOrderMinAge(bytes32 _marketKey, uint _offchainDelayedOrderMinAge) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_OFFCHAIN_DELAYED_ORDER_MIN_AGE, _offchainDelayedOrderMinAge);
    }

    function setOffchainDelayedOrderMaxAge(bytes32 _marketKey, uint _offchainDelayedOrderMaxAge) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_OFFCHAIN_DELAYED_ORDER_MAX_AGE, _offchainDelayedOrderMaxAge);
    }

    function setMaxLeverage(bytes32 _marketKey, uint _maxLeverage) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_LEVERAGE, _maxLeverage);
    }

    function setMaxMarketValue(bytes32 _marketKey, uint _maxMarketValue) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_MARKET_VALUE, _maxMarketValue);
    }

    // Before altering parameters relevant to funding rates, outstanding funding on the underlying market
    // must be recomputed, otherwise already-accrued but unrealised funding in the market can change.

    function _recomputeFunding(bytes32 _marketKey) internal {
        address marketAddress = _futuresMarketManager().marketForKey(_marketKey);

        IPerpsV2MarketViews marketView = IPerpsV2MarketViews(marketAddress);
        if (marketView.marketSize() > 0) {
            IPerpsV2Market market = IPerpsV2Market(marketAddress);
            // only recompute funding when market has positions, this check is important for initial setup
            market.recomputeFunding();
        }
    }

    function setMaxFundingVelocity(bytes32 _marketKey, uint _maxFundingVelocity) public onlyOwner {
        _recomputeFunding(_marketKey);
        _setParameter(_marketKey, PARAMETER_MAX_FUNDING_VELOCITY, _maxFundingVelocity);
    }

    function setSkewScale(bytes32 _marketKey, uint _skewScale) public onlyOwner {
        require(_skewScale > 0, "cannot set skew scale 0");
        _recomputeFunding(_marketKey);
        _setParameter(_marketKey, PARAMETER_MIN_SKEW_SCALE, _skewScale);
    }

    function setMinDelayTimeDelta(bytes32 _marketKey, uint _minDelayTimeDelta) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MIN_DELAY_TIME_DELTA, _minDelayTimeDelta);
    }

    function setMaxDelayTimeDelta(bytes32 _marketKey, uint _maxDelayTimeDelta) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_DELAY_TIME_DELTA, _maxDelayTimeDelta);
    }

    function setOffchainMarketKey(bytes32 _marketKey, bytes32 _offchainMarketKey) public onlyOwner {
        _flexibleStorage().setBytes32Value(
            SETTING_CONTRACT_NAME,
            keccak256(abi.encodePacked(_marketKey, PARAMETER_OFFCHAIN_MARKET_KEY)),
            _offchainMarketKey
        );
        emit ParameterUpdatedBytes32(_marketKey, PARAMETER_OFFCHAIN_MARKET_KEY, _offchainMarketKey);
    }

    /*
     * The max divergence between onchain and offchain prices for an offchain delayed order execution.
     */
    function setOffchainPriceDivergence(bytes32 _marketKey, uint _offchainPriceDivergence) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_OFFCHAIN_PRICE_DIVERGENCE, _offchainPriceDivergence);
    }

    function setLiquidationPremiumMultiplier(bytes32 _marketKey, uint _liquidationPremiumMultiplier) public onlyOwner {
        require(_liquidationPremiumMultiplier > 0, "cannot set liquidation premium multiplier 0");
        _setParameter(_marketKey, PARAMETER_LIQUIDATION_PREMIUM_MULTIPLIER, _liquidationPremiumMultiplier);
    }

    function setParameters(bytes32 _marketKey, Parameters calldata _parameters) external onlyOwner {
        _recomputeFunding(_marketKey);
        setTakerFee(_marketKey, _parameters.takerFee);
        setMakerFee(_marketKey, _parameters.makerFee);
        setOverrideCommitFee(_marketKey, _parameters.overrideCommitFee);
        setMaxLeverage(_marketKey, _parameters.maxLeverage);
        setMaxMarketValue(_marketKey, _parameters.maxMarketValue);
        setMaxFundingVelocity(_marketKey, _parameters.maxFundingVelocity);
        setSkewScale(_marketKey, _parameters.skewScale);
        setTakerFeeDelayedOrder(_marketKey, _parameters.takerFeeDelayedOrder);
        setMakerFeeDelayedOrder(_marketKey, _parameters.makerFeeDelayedOrder);
        setNextPriceConfirmWindow(_marketKey, _parameters.nextPriceConfirmWindow);
        setDelayedOrderConfirmWindow(_marketKey, _parameters.delayedOrderConfirmWindow);
        setMinDelayTimeDelta(_marketKey, _parameters.minDelayTimeDelta);
        setMaxDelayTimeDelta(_marketKey, _parameters.maxDelayTimeDelta);
        setTakerFeeOffchainDelayedOrder(_marketKey, _parameters.takerFeeOffchainDelayedOrder);
        setMakerFeeOffchainDelayedOrder(_marketKey, _parameters.makerFeeOffchainDelayedOrder);
        setOffchainDelayedOrderMinAge(_marketKey, _parameters.offchainDelayedOrderMinAge);
        setOffchainDelayedOrderMaxAge(_marketKey, _parameters.offchainDelayedOrderMaxAge);
        setOffchainMarketKey(_marketKey, _parameters.offchainMarketKey);
        setOffchainPriceDivergence(_marketKey, _parameters.offchainPriceDivergence);
        setLiquidationPremiumMultiplier(_marketKey, _parameters.liquidationPremiumMultiplier);
    }

    function setMinKeeperFee(uint _sUSD) external onlyOwner {
        require(_sUSD <= _minInitialMargin(), "min margin < liquidation fee");
        if (_maxKeeperFee() > 0) {
            // only check if already set
            require(_sUSD <= _maxKeeperFee(), "max fee < min fee");
        }
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_KEEPER_FEE, _sUSD);
        emit MinKeeperFeeUpdated(_sUSD);
    }

    function setMaxKeeperFee(uint _sUSD) external onlyOwner {
        require(_sUSD >= _minKeeperFee(), "max fee < min fee");
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_MAX_KEEPER_FEE, _sUSD);
        emit MaxKeeperFeeUpdated(_sUSD);
    }

    function setLiquidationFeeRatio(uint _ratio) external onlyOwner {
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_FEE_RATIO, _ratio);
        emit LiquidationFeeRatioUpdated(_ratio);
    }

    function setLiquidationBufferRatio(uint _ratio) external onlyOwner {
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_LIQUIDATION_BUFFER_RATIO, _ratio);
        emit LiquidationBufferRatioUpdated(_ratio);
    }

    function setMinInitialMargin(uint _minMargin) external onlyOwner {
        require(_minKeeperFee() <= _minMargin, "min margin < liquidation fee");
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_INITIAL_MARGIN, _minMargin);
        emit MinInitialMarginUpdated(_minMargin);
    }

    /* ========== EVENTS ========== */

    event ParameterUpdated(bytes32 indexed marketKey, bytes32 indexed parameter, uint value);
    event ParameterUpdatedBytes32(bytes32 indexed marketKey, bytes32 indexed parameter, bytes32 value);
    event MinKeeperFeeUpdated(uint sUSD);
    event MaxKeeperFeeUpdated(uint sUSD);
    event LiquidationFeeRatioUpdated(uint bps);
    event LiquidationBufferRatioUpdated(uint bps);
    event MinInitialMarginUpdated(uint minMargin);
}


// https://docs.synthetix.io/contracts/source/interfaces/isystemstatus
interface ISystemStatus {
    struct Status {
        bool canSuspend;
        bool canResume;
    }

    struct Suspension {
        bool suspended;
        // reason is an integer code,
        // 0 => no reason, 1 => upgrading, 2+ => defined by system usage
        uint248 reason;
    }

    // Views
    function accessControl(bytes32 section, address account) external view returns (bool canSuspend, bool canResume);

    function requireSystemActive() external view;

    function systemSuspended() external view returns (bool);

    function requireIssuanceActive() external view;

    function requireExchangeActive() external view;

    function requireFuturesActive() external view;

    function requireFuturesMarketActive(bytes32 marketKey) external view;

    function requireExchangeBetweenSynthsAllowed(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view;

    function requireSynthActive(bytes32 currencyKey) external view;

    function synthSuspended(bytes32 currencyKey) external view returns (bool);

    function requireSynthsActive(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view;

    function systemSuspension() external view returns (bool suspended, uint248 reason);

    function issuanceSuspension() external view returns (bool suspended, uint248 reason);

    function exchangeSuspension() external view returns (bool suspended, uint248 reason);

    function futuresSuspension() external view returns (bool suspended, uint248 reason);

    function synthExchangeSuspension(bytes32 currencyKey) external view returns (bool suspended, uint248 reason);

    function synthSuspension(bytes32 currencyKey) external view returns (bool suspended, uint248 reason);

    function futuresMarketSuspension(bytes32 marketKey) external view returns (bool suspended, uint248 reason);

    function getSynthExchangeSuspensions(bytes32[] calldata synths)
        external
        view
        returns (bool[] memory exchangeSuspensions, uint256[] memory reasons);

    function getSynthSuspensions(bytes32[] calldata synths)
        external
        view
        returns (bool[] memory suspensions, uint256[] memory reasons);

    function getFuturesMarketSuspensions(bytes32[] calldata marketKeys)
        external
        view
        returns (bool[] memory suspensions, uint256[] memory reasons);

    // Restricted functions
    function suspendIssuance(uint256 reason) external;

    function suspendSynth(bytes32 currencyKey, uint256 reason) external;

    function suspendFuturesMarket(bytes32 marketKey, uint256 reason) external;

    function updateAccessControl(
        bytes32 section,
        address account,
        bool canSuspend,
        bool canResume
    ) external;
}


// Inheritance


// https://docs.synthetix.io/contracts/source/contracts/systemstatus
contract SystemStatus is Owned, ISystemStatus {
    mapping(bytes32 => mapping(address => Status)) public accessControl;

    uint248 public constant SUSPENSION_REASON_UPGRADE = 1;

    bytes32 public constant SECTION_SYSTEM = "System";
    bytes32 public constant SECTION_ISSUANCE = "Issuance";
    bytes32 public constant SECTION_EXCHANGE = "Exchange";
    bytes32 public constant SECTION_FUTURES = "Futures";
    bytes32 public constant SECTION_SYNTH_EXCHANGE = "SynthExchange";
    bytes32 public constant SECTION_SYNTH = "Synth";

    bytes32 public constant CONTRACT_NAME = "SystemStatus";

    Suspension public systemSuspension;

    Suspension public issuanceSuspension;

    Suspension public exchangeSuspension;

    Suspension public futuresSuspension;

    mapping(bytes32 => Suspension) public synthExchangeSuspension;

    mapping(bytes32 => Suspension) public synthSuspension;

    mapping(bytes32 => Suspension) public futuresMarketSuspension;

    constructor(address _owner) public Owned(_owner) {}

    /* ========== VIEWS ========== */
    function requireSystemActive() external view {
        _internalRequireSystemActive();
    }

    function systemSuspended() external view returns (bool) {
        return systemSuspension.suspended;
    }

    function requireIssuanceActive() external view {
        // Issuance requires the system be active
        _internalRequireSystemActive();

        // and issuance itself of course
        _internalRequireIssuanceActive();
    }

    function requireExchangeActive() external view {
        // Exchanging requires the system be active
        _internalRequireSystemActive();

        // and exchanging itself of course
        _internalRequireExchangeActive();
    }

    function requireSynthExchangeActive(bytes32 currencyKey) external view {
        // Synth exchange and transfer requires the system be active
        _internalRequireSystemActive();
        _internalRequireSynthExchangeActive(currencyKey);
    }

    function requireFuturesActive() external view {
        _internalRequireSystemActive();
        _internalRequireExchangeActive();
        _internalRequireFuturesActive();
    }

    /// @notice marketKey doesn't necessarily correspond to asset key
    function requireFuturesMarketActive(bytes32 marketKey) external view {
        _internalRequireSystemActive();
        _internalRequireExchangeActive(); // exchanging implicitely used
        _internalRequireFuturesActive(); // futures global flag
        _internalRequireFuturesMarketActive(marketKey); // specific futures market flag
    }

    function synthSuspended(bytes32 currencyKey) external view returns (bool) {
        return systemSuspension.suspended || synthSuspension[currencyKey].suspended;
    }

    function requireSynthActive(bytes32 currencyKey) external view {
        // Synth exchange and transfer requires the system be active
        _internalRequireSystemActive();
        _internalRequireSynthActive(currencyKey);
    }

    function requireSynthsActive(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view {
        // Synth exchange and transfer requires the system be active
        _internalRequireSystemActive();
        _internalRequireSynthActive(sourceCurrencyKey);
        _internalRequireSynthActive(destinationCurrencyKey);
    }

    function requireExchangeBetweenSynthsAllowed(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view {
        // Synth exchange and transfer requires the system be active
        _internalRequireSystemActive();

        // and exchanging must be active
        _internalRequireExchangeActive();

        // and the synth exchanging between the synths must be active
        _internalRequireSynthExchangeActive(sourceCurrencyKey);
        _internalRequireSynthExchangeActive(destinationCurrencyKey);

        // and finally, the synths cannot be suspended
        _internalRequireSynthActive(sourceCurrencyKey);
        _internalRequireSynthActive(destinationCurrencyKey);
    }

    function isSystemUpgrading() external view returns (bool) {
        return systemSuspension.suspended && systemSuspension.reason == SUSPENSION_REASON_UPGRADE;
    }

    function getSynthExchangeSuspensions(bytes32[] calldata synths)
        external
        view
        returns (bool[] memory exchangeSuspensions, uint256[] memory reasons)
    {
        exchangeSuspensions = new bool[](synths.length);
        reasons = new uint256[](synths.length);

        for (uint i = 0; i < synths.length; i++) {
            exchangeSuspensions[i] = synthExchangeSuspension[synths[i]].suspended;
            reasons[i] = synthExchangeSuspension[synths[i]].reason;
        }
    }

    function getSynthSuspensions(bytes32[] calldata synths)
        external
        view
        returns (bool[] memory suspensions, uint256[] memory reasons)
    {
        suspensions = new bool[](synths.length);
        reasons = new uint256[](synths.length);

        for (uint i = 0; i < synths.length; i++) {
            suspensions[i] = synthSuspension[synths[i]].suspended;
            reasons[i] = synthSuspension[synths[i]].reason;
        }
    }

    /// @notice marketKey doesn't necessarily correspond to asset key
    function getFuturesMarketSuspensions(bytes32[] calldata marketKeys)
        external
        view
        returns (bool[] memory suspensions, uint256[] memory reasons)
    {
        suspensions = new bool[](marketKeys.length);
        reasons = new uint256[](marketKeys.length);

        for (uint i = 0; i < marketKeys.length; i++) {
            suspensions[i] = futuresMarketSuspension[marketKeys[i]].suspended;
            reasons[i] = futuresMarketSuspension[marketKeys[i]].reason;
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function updateAccessControl(
        bytes32 section,
        address account,
        bool canSuspend,
        bool canResume
    ) external onlyOwner {
        _internalUpdateAccessControl(section, account, canSuspend, canResume);
    }

    function updateAccessControls(
        bytes32[] calldata sections,
        address[] calldata accounts,
        bool[] calldata canSuspends,
        bool[] calldata canResumes
    ) external onlyOwner {
        require(
            sections.length == accounts.length &&
                accounts.length == canSuspends.length &&
                canSuspends.length == canResumes.length,
            "Input array lengths must match"
        );
        for (uint i = 0; i < sections.length; i++) {
            _internalUpdateAccessControl(sections[i], accounts[i], canSuspends[i], canResumes[i]);
        }
    }

    function suspendSystem(uint256 reason) external {
        _requireAccessToSuspend(SECTION_SYSTEM);
        systemSuspension.suspended = true;
        systemSuspension.reason = uint248(reason);
        emit SystemSuspended(systemSuspension.reason);
    }

    function resumeSystem() external {
        _requireAccessToResume(SECTION_SYSTEM);
        systemSuspension.suspended = false;
        emit SystemResumed(uint256(systemSuspension.reason));
        systemSuspension.reason = 0;
    }

    function suspendIssuance(uint256 reason) external {
        _requireAccessToSuspend(SECTION_ISSUANCE);
        issuanceSuspension.suspended = true;
        issuanceSuspension.reason = uint248(reason);
        emit IssuanceSuspended(reason);
    }

    function resumeIssuance() external {
        _requireAccessToResume(SECTION_ISSUANCE);
        issuanceSuspension.suspended = false;
        emit IssuanceResumed(uint256(issuanceSuspension.reason));
        issuanceSuspension.reason = 0;
    }

    function suspendExchange(uint256 reason) external {
        _requireAccessToSuspend(SECTION_EXCHANGE);
        exchangeSuspension.suspended = true;
        exchangeSuspension.reason = uint248(reason);
        emit ExchangeSuspended(reason);
    }

    function resumeExchange() external {
        _requireAccessToResume(SECTION_EXCHANGE);
        exchangeSuspension.suspended = false;
        emit ExchangeResumed(uint256(exchangeSuspension.reason));
        exchangeSuspension.reason = 0;
    }

    function suspendFutures(uint256 reason) external {
        _requireAccessToSuspend(SECTION_FUTURES);
        futuresSuspension.suspended = true;
        futuresSuspension.reason = uint248(reason);
        emit FuturesSuspended(reason);
    }

    function resumeFutures() external {
        _requireAccessToResume(SECTION_FUTURES);
        futuresSuspension.suspended = false;
        emit FuturesResumed(uint256(futuresSuspension.reason));
        futuresSuspension.reason = 0;
    }

    /// @notice marketKey doesn't necessarily correspond to asset key
    function suspendFuturesMarket(bytes32 marketKey, uint256 reason) external {
        bytes32[] memory marketKeys = new bytes32[](1);
        marketKeys[0] = marketKey;
        _internalSuspendFuturesMarkets(marketKeys, reason);
    }

    /// @notice marketKey doesn't necessarily correspond to asset key
    function suspendFuturesMarkets(bytes32[] calldata marketKeys, uint256 reason) external {
        _internalSuspendFuturesMarkets(marketKeys, reason);
    }

    /// @notice marketKey doesn't necessarily correspond to asset key
    function resumeFuturesMarket(bytes32 marketKey) external {
        bytes32[] memory marketKeys = new bytes32[](1);
        marketKeys[0] = marketKey;
        _internalResumeFuturesMarkets(marketKeys);
    }

    /// @notice marketKey doesn't necessarily correspond to asset key
    function resumeFuturesMarkets(bytes32[] calldata marketKeys) external {
        _internalResumeFuturesMarkets(marketKeys);
    }

    function suspendSynthExchange(bytes32 currencyKey, uint256 reason) external {
        bytes32[] memory currencyKeys = new bytes32[](1);
        currencyKeys[0] = currencyKey;
        _internalSuspendSynthExchange(currencyKeys, reason);
    }

    function suspendSynthsExchange(bytes32[] calldata currencyKeys, uint256 reason) external {
        _internalSuspendSynthExchange(currencyKeys, reason);
    }

    function resumeSynthExchange(bytes32 currencyKey) external {
        bytes32[] memory currencyKeys = new bytes32[](1);
        currencyKeys[0] = currencyKey;
        _internalResumeSynthsExchange(currencyKeys);
    }

    function resumeSynthsExchange(bytes32[] calldata currencyKeys) external {
        _internalResumeSynthsExchange(currencyKeys);
    }

    function suspendSynth(bytes32 currencyKey, uint256 reason) external {
        bytes32[] memory currencyKeys = new bytes32[](1);
        currencyKeys[0] = currencyKey;
        _internalSuspendSynths(currencyKeys, reason);
    }

    function suspendSynths(bytes32[] calldata currencyKeys, uint256 reason) external {
        _internalSuspendSynths(currencyKeys, reason);
    }

    function resumeSynth(bytes32 currencyKey) external {
        bytes32[] memory currencyKeys = new bytes32[](1);
        currencyKeys[0] = currencyKey;
        _internalResumeSynths(currencyKeys);
    }

    function resumeSynths(bytes32[] calldata currencyKeys) external {
        _internalResumeSynths(currencyKeys);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _requireAccessToSuspend(bytes32 section) internal view {
        require(accessControl[section][msg.sender].canSuspend, "Restricted to access control list");
    }

    function _requireAccessToResume(bytes32 section) internal view {
        require(accessControl[section][msg.sender].canResume, "Restricted to access control list");
    }

    function _internalRequireSystemActive() internal view {
        require(
            !systemSuspension.suspended,
            systemSuspension.reason == SUSPENSION_REASON_UPGRADE
                ? "Synthetix is suspended, upgrade in progress... please stand by"
                : "Synthetix is suspended. Operation prohibited"
        );
    }

    function _internalRequireIssuanceActive() internal view {
        require(!issuanceSuspension.suspended, "Issuance is suspended. Operation prohibited");
    }

    function _internalRequireExchangeActive() internal view {
        require(!exchangeSuspension.suspended, "Exchange is suspended. Operation prohibited");
    }

    function _internalRequireFuturesActive() internal view {
        require(!futuresSuspension.suspended, "Futures markets are suspended. Operation prohibited");
    }

    function _internalRequireSynthExchangeActive(bytes32 currencyKey) internal view {
        require(!synthExchangeSuspension[currencyKey].suspended, "Synth exchange suspended. Operation prohibited");
    }

    function _internalRequireSynthActive(bytes32 currencyKey) internal view {
        require(!synthSuspension[currencyKey].suspended, "Synth is suspended. Operation prohibited");
    }

    function _internalRequireFuturesMarketActive(bytes32 marketKey) internal view {
        require(!futuresMarketSuspension[marketKey].suspended, "Market suspended");
    }

    function _internalSuspendSynths(bytes32[] memory currencyKeys, uint256 reason) internal {
        _requireAccessToSuspend(SECTION_SYNTH);
        for (uint i = 0; i < currencyKeys.length; i++) {
            bytes32 currencyKey = currencyKeys[i];
            synthSuspension[currencyKey].suspended = true;
            synthSuspension[currencyKey].reason = uint248(reason);
            emit SynthSuspended(currencyKey, reason);
        }
    }

    function _internalResumeSynths(bytes32[] memory currencyKeys) internal {
        _requireAccessToResume(SECTION_SYNTH);
        for (uint i = 0; i < currencyKeys.length; i++) {
            bytes32 currencyKey = currencyKeys[i];
            emit SynthResumed(currencyKey, uint256(synthSuspension[currencyKey].reason));
            delete synthSuspension[currencyKey];
        }
    }

    function _internalSuspendSynthExchange(bytes32[] memory currencyKeys, uint256 reason) internal {
        _requireAccessToSuspend(SECTION_SYNTH_EXCHANGE);
        for (uint i = 0; i < currencyKeys.length; i++) {
            bytes32 currencyKey = currencyKeys[i];
            synthExchangeSuspension[currencyKey].suspended = true;
            synthExchangeSuspension[currencyKey].reason = uint248(reason);
            emit SynthExchangeSuspended(currencyKey, reason);
        }
    }

    function _internalResumeSynthsExchange(bytes32[] memory currencyKeys) internal {
        _requireAccessToResume(SECTION_SYNTH_EXCHANGE);
        for (uint i = 0; i < currencyKeys.length; i++) {
            bytes32 currencyKey = currencyKeys[i];
            emit SynthExchangeResumed(currencyKey, uint256(synthExchangeSuspension[currencyKey].reason));
            delete synthExchangeSuspension[currencyKey];
        }
    }

    function _internalSuspendFuturesMarkets(bytes32[] memory marketKeys, uint256 reason) internal {
        _requireAccessToSuspend(SECTION_FUTURES);
        for (uint i = 0; i < marketKeys.length; i++) {
            bytes32 marketKey = marketKeys[i];
            futuresMarketSuspension[marketKey].suspended = true;
            futuresMarketSuspension[marketKey].reason = uint248(reason);
            emit FuturesMarketSuspended(marketKey, reason);
        }
    }

    function _internalResumeFuturesMarkets(bytes32[] memory marketKeys) internal {
        _requireAccessToResume(SECTION_FUTURES);
        for (uint i = 0; i < marketKeys.length; i++) {
            bytes32 marketKey = marketKeys[i];
            emit FuturesMarketResumed(marketKey, uint256(futuresMarketSuspension[marketKey].reason));
            delete futuresMarketSuspension[marketKey];
        }
    }

    function _internalUpdateAccessControl(
        bytes32 section,
        address account,
        bool canSuspend,
        bool canResume
    ) internal {
        require(
            section == SECTION_SYSTEM ||
                section == SECTION_ISSUANCE ||
                section == SECTION_EXCHANGE ||
                section == SECTION_FUTURES ||
                section == SECTION_SYNTH_EXCHANGE ||
                section == SECTION_SYNTH,
            "Invalid section supplied"
        );
        accessControl[section][account].canSuspend = canSuspend;
        accessControl[section][account].canResume = canResume;
        emit AccessControlUpdated(section, account, canSuspend, canResume);
    }

    /* ========== EVENTS ========== */

    event SystemSuspended(uint256 reason);
    event SystemResumed(uint256 reason);

    event IssuanceSuspended(uint256 reason);
    event IssuanceResumed(uint256 reason);

    event ExchangeSuspended(uint256 reason);
    event ExchangeResumed(uint256 reason);

    event FuturesSuspended(uint256 reason);
    event FuturesResumed(uint256 reason);

    event SynthExchangeSuspended(bytes32 currencyKey, uint256 reason);
    event SynthExchangeResumed(bytes32 currencyKey, uint256 reason);

    event SynthSuspended(bytes32 currencyKey, uint256 reason);
    event SynthResumed(bytes32 currencyKey, uint256 reason);

    event FuturesMarketSuspended(bytes32 marketKey, uint256 reason);
    event FuturesMarketResumed(bytes32 marketKey, uint256 reason);

    event AccessControlUpdated(bytes32 indexed section, address indexed account, bool canSuspend, bool canResume);
}


interface ISynthetixNamedContract {
    // solhint-disable func-name-mixedcase
    function CONTRACT_NAME() external view returns (bytes32);
}

// solhint-disable contract-name-camelcase
contract Migration_EltaninOptimism is BaseMigration {
    // https://explorer.optimism.io/address/0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;
    address public constant OWNER = 0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;

    // ----------------------------
    // EXISTING SYNTHETIX CONTRACTS
    // ----------------------------

    // https://explorer.optimism.io/address/0x4aD2d14Bed21062Ef7B85C378F69cDdf6ED7489C
    PerpsV2ExchangeRate public constant perpsv2exchangerate_i =
        PerpsV2ExchangeRate(0x4aD2d14Bed21062Ef7B85C378F69cDdf6ED7489C);
    // https://explorer.optimism.io/address/0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e
    FuturesMarketManager public constant futuresmarketmanager_i =
        FuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);
    // https://explorer.optimism.io/address/0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C
    AddressResolver public constant addressresolver_i = AddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);
    // https://explorer.optimism.io/address/0x913bd76F7E1572CC8278CeF2D6b06e2140ca9Ce2
    ExchangeRates public constant exchangerates_i = ExchangeRates(0x913bd76F7E1572CC8278CeF2D6b06e2140ca9Ce2);
    // https://explorer.optimism.io/address/0x09793Aad1518B8d8CC72FDd356479E3CBa7B4Ad1
    PerpsV2MarketSettings public constant perpsv2marketsettings_i =
        PerpsV2MarketSettings(0x09793Aad1518B8d8CC72FDd356479E3CBa7B4Ad1);
    // https://explorer.optimism.io/address/0xE8c41bE1A167314ABAF2423b72Bf8da826943FFD
    SystemStatus public constant systemstatus_i = SystemStatus(0xE8c41bE1A167314ABAF2423b72Bf8da826943FFD);

    // ----------------------------------
    // NEW CONTRACTS DEPLOYED TO BE ADDED
    // ----------------------------------

    // https://explorer.optimism.io/address/0xFEAF9e0A57e626f72E1a5fff507D7A2d9A9F0EE9
    address public constant new_PerpsV2MarketStateBTCPERP_contract = 0xFEAF9e0A57e626f72E1a5fff507D7A2d9A9F0EE9;
    // https://explorer.optimism.io/address/0x49dC714eaD0cc585eBaC8A412098914a2CE7B7B2
    address public constant new_PerpsV2MarketStateLINKPERP_contract = 0x49dC714eaD0cc585eBaC8A412098914a2CE7B7B2;
    // https://explorer.optimism.io/address/0x5da48D842542eF497ad68FAEd3480b3B1609Afe5
    address public constant new_PerpsV2MarketStateSOLPERP_contract = 0x5da48D842542eF497ad68FAEd3480b3B1609Afe5;
    // https://explorer.optimism.io/address/0x3d368332c5E5c454f179f36e716b7cfA09906454
    address public constant new_PerpsV2MarketStateAVAXPERP_contract = 0x3d368332c5E5c454f179f36e716b7cfA09906454;
    // https://explorer.optimism.io/address/0x9821CC43096b3F35744423C9B029854064dfe9Ab
    address public constant new_PerpsV2MarketStateAAVEPERP_contract = 0x9821CC43096b3F35744423C9B029854064dfe9Ab;
    // https://explorer.optimism.io/address/0xcF4a5F99902887d6CF5A2271cC1f54b5c2321e29
    address public constant new_PerpsV2MarketStateUNIPERP_contract = 0xcF4a5F99902887d6CF5A2271cC1f54b5c2321e29;
    // https://explorer.optimism.io/address/0xfC99d08D8ff69e31095E7372620369Fa92c82960
    address public constant new_PerpsV2MarketStateMATICPERP_contract = 0xfC99d08D8ff69e31095E7372620369Fa92c82960;
    // https://explorer.optimism.io/address/0xDaA88C67eBA3a95715d678557A4F42e26cd01F1A
    address public constant new_PerpsV2MarketStateAPEPERP_contract = 0xDaA88C67eBA3a95715d678557A4F42e26cd01F1A;
    // https://explorer.optimism.io/address/0xA1c26b1ff002993dD1fd43c0f662C5d93cC5B66E
    address public constant new_PerpsV2MarketStateDYDXPERP_contract = 0xA1c26b1ff002993dD1fd43c0f662C5d93cC5B66E;
    // https://explorer.optimism.io/address/0x7b75C4857E84C8421D422E06447A7Fb03c398eDd
    address public constant new_PerpsV2MarketStateBNBPERP_contract = 0x7b75C4857E84C8421D422E06447A7Fb03c398eDd;
    // https://explorer.optimism.io/address/0xa26c97A0c9788e937986ee6276f3762c20C06ef5
    address public constant new_PerpsV2MarketStateOPPERP_contract = 0xa26c97A0c9788e937986ee6276f3762c20C06ef5;
    // https://explorer.optimism.io/address/0xd6fe35B896FaE8b22AA6E47bE2752CF87eB1FcaC
    address public constant new_PerpsV2MarketStateDOGEPERP_contract = 0xd6fe35B896FaE8b22AA6E47bE2752CF87eB1FcaC;
    // https://explorer.optimism.io/address/0x58e7da4Ee20f1De44F59D3Dd2640D5D844e443cF
    address public constant new_PerpsV2MarketStateXAUPERP_contract = 0x58e7da4Ee20f1De44F59D3Dd2640D5D844e443cF;
    // https://explorer.optimism.io/address/0x90276BA2Ac35D2BE30588b5019CF257f80b89E71
    address public constant new_PerpsV2MarketStateXAGPERP_contract = 0x90276BA2Ac35D2BE30588b5019CF257f80b89E71;
    // https://explorer.optimism.io/address/0x0E48C8662e98f576e84d0ccDb146538269653225
    address public constant new_PerpsV2MarketStateEURPERP_contract = 0x0E48C8662e98f576e84d0ccDb146538269653225;
    // https://explorer.optimism.io/address/0x91a480Bf2518C037E644fE70F207E66fdAA4d948
    address public constant new_PerpsV2MarketStateATOMPERP_contract = 0x91a480Bf2518C037E644fE70F207E66fdAA4d948;
    // https://explorer.optimism.io/address/0x78fC32b982F5f35325996655a8Bd92715CfEfD06
    address public constant new_PerpsV2MarketStateAXSPERP_contract = 0x78fC32b982F5f35325996655a8Bd92715CfEfD06;
    // https://explorer.optimism.io/address/0x49700Eb35841E9CD637B3352A26B7d685aDaFD94
    address public constant new_PerpsV2MarketStateFLOWPERP_contract = 0x49700Eb35841E9CD637B3352A26B7d685aDaFD94;
    // https://explorer.optimism.io/address/0xe76DF4d2554C74B746c5A1Df8EAA4eA8F657916d
    address public constant new_PerpsV2MarketStateFTMPERP_contract = 0xe76DF4d2554C74B746c5A1Df8EAA4eA8F657916d;
    // https://explorer.optimism.io/address/0xea53A19B50C51881C0734a7169Fe9C6E44A09cf9
    address public constant new_PerpsV2MarketStateNEARPERP_contract = 0xea53A19B50C51881C0734a7169Fe9C6E44A09cf9;
    // https://explorer.optimism.io/address/0x973dE36Bb8022942e2658D5d129CbDdCF105a470
    address public constant new_PerpsV2MarketStateAUDPERP_contract = 0x973dE36Bb8022942e2658D5d129CbDdCF105a470;
    // https://explorer.optimism.io/address/0x4E1F44E48D2E87E279d25EEd88ced1Ec7f51438e
    address public constant new_PerpsV2MarketStateGBPPERP_contract = 0x4E1F44E48D2E87E279d25EEd88ced1Ec7f51438e;

    constructor() public BaseMigration(OWNER) {}

    function contractsRequiringOwnership() public pure returns (address[] memory contracts) {
        contracts = new address[](6);
        contracts[0] = address(perpsv2exchangerate_i);
        contracts[1] = address(futuresmarketmanager_i);
        contracts[2] = address(addressresolver_i);
        contracts[3] = address(exchangerates_i);
        contracts[4] = address(perpsv2marketsettings_i);
        contracts[5] = address(systemstatus_i);
    }

    function migrate2() external onlyOwner {
        futuresmarketmanager_addProxiedMarkets_1();
    }

    function migrate3() external onlyOwner {
        futuresmarketmanager_addProxiedMarkets_2();
    }

    function migrate() external onlyOwner {
        // ACCEPT OWNERSHIP for all contracts that require ownership to make changes
        acceptAll();

        // Ensure perpsV2 market is paused according to config;
        bytes32[] memory marketsToSuspend = new bytes32[](44);

        marketsToSuspend[0] = "sBTCPERP";
        marketsToSuspend[1] = "ocBTCPERP";
        marketsToSuspend[2] = "sLINKPERP";
        marketsToSuspend[3] = "ocLINKPERP";
        marketsToSuspend[4] = "sSOLPERP";
        marketsToSuspend[5] = "ocSOLPERP";
        marketsToSuspend[6] = "sAVAXPERP";
        marketsToSuspend[7] = "ocAVAXPERP";
        marketsToSuspend[8] = "sAAVEPERP";
        marketsToSuspend[9] = "ocAAVEPERP";
        marketsToSuspend[10] = "sUNIPERP";
        marketsToSuspend[11] = "ocUNIPERP";
        marketsToSuspend[12] = "sMATICPERP";
        marketsToSuspend[13] = "ocMATICPERP";
        marketsToSuspend[14] = "sAPEPERP";
        marketsToSuspend[15] = "ocAPEPERP";
        marketsToSuspend[16] = "sDYDXPERP";
        marketsToSuspend[17] = "ocDYDXPERP";
        marketsToSuspend[18] = "sBNBPERP";
        marketsToSuspend[19] = "ocBNBPERP";
        marketsToSuspend[20] = "sOPPERP";
        marketsToSuspend[21] = "ocOPPERP";
        marketsToSuspend[22] = "sDOGEPERP";
        marketsToSuspend[23] = "ocDOGEPERP";
        marketsToSuspend[24] = "sXAUPERP";
        marketsToSuspend[25] = "ocXAUPERP";
        marketsToSuspend[26] = "sXAGPERP";
        marketsToSuspend[27] = "ocXAGPERP";
        marketsToSuspend[28] = "sEURPERP";
        marketsToSuspend[29] = "ocEURPERP";
        marketsToSuspend[30] = "sATOMPERP";
        marketsToSuspend[31] = "ocATOMPERP";
        marketsToSuspend[32] = "sAXSPERP";
        marketsToSuspend[33] = "ocAXSPERP";
        marketsToSuspend[34] = "sFLOWPERP";
        marketsToSuspend[35] = "ocFLOWPERP";
        marketsToSuspend[36] = "sFTMPERP";
        marketsToSuspend[37] = "ocFTMPERP";
        marketsToSuspend[38] = "sNEARPERP";
        marketsToSuspend[39] = "ocNEARPERP";
        marketsToSuspend[40] = "sAUDPERP";
        marketsToSuspend[41] = "ocAUDPERP";
        marketsToSuspend[42] = "sGBPPERP";
        marketsToSuspend[43] = "ocGBPPERP";

        systemstatus_i.suspendFuturesMarkets(marketsToSuspend, 80);

        // MIGRATION
        perpsv2exchangerate_addAssociatedContracts_0();
        // Import all new contracts into the address resolver;
        addressresolver_importAddresses_2();
        // Ensure the ExchangeRates contract has the standalone feed for ATOM;
        exchangerates_i.addAggregator("ATOM", 0xEF89db2eA46B4aD4E333466B6A486b809e613F39);
        // Ensure the ExchangeRates contract has the standalone feed for AXS;
        exchangerates_i.addAggregator("AXS", 0x805a61D54bb686e57F02D1EC96A1491C7aF40893);
        // Ensure the ExchangeRates contract has the standalone feed for FLOW;
        exchangerates_i.addAggregator("FLOW", 0x2fF1EB7D0ceC35959F0248E9354c3248c6683D9b);
        // Ensure the ExchangeRates contract has the standalone feed for FTM;
        exchangerates_i.addAggregator("FTM", 0xc19d58652d6BfC6Db6FB3691eDA6Aa7f3379E4E9);
        // Ensure the ExchangeRates contract has the standalone feed for NEAR;
        exchangerates_i.addAggregator("NEAR", 0xca6fa4b8CB365C02cd3Ba70544EFffe78f63ac82);
        // Ensure the ExchangeRates contract has the standalone feed for AUD;
        exchangerates_i.addAggregator("AUD", 0x39be70E93D2D285C9E71be7f70FC5a45A7777B14);
        // Ensure the ExchangeRates contract has the standalone feed for GBP;
        exchangerates_i.addAggregator("GBP", 0x540D48C01F946e729174517E013Ad0bdaE5F08C0);
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for sBTC;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "sBTC",
            0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for LINK;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "LINK",
            0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for SOL;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "SOL",
            0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for AVAX;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "AVAX",
            0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for AAVE;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "AAVE",
            0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for UNI;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "UNI",
            0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for MATIC;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "MATIC",
            0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for APE;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "APE",
            0x15add95022ae13563a11992e727c91bdb6b55bc183d9d747436c80a483d8c864
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for DYDX;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "DYDX",
            0x6489800bb8974169adfe35937bf6736507097d13c190d760c557108c7e93a81b
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for BNB;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "BNB",
            0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for OP;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "OP",
            0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for DOGE;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "DOGE",
            0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for XAU;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "XAU",
            0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for XAG;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "XAG",
            0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for EUR;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "EUR",
            0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for ATOM;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "ATOM",
            0xb00b60f88b03a6a625a8d1c048c3f66653edf217439983d037e7222c4e612819
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for AXS;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "AXS",
            0xb7e3904c08ddd9c0c10c6d207d390fd19e87eb6aab96304f571ed94caebdefa0
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for FLOW;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "FLOW",
            0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for FTM;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "FTM",
            0x5c6c0d2386e3352356c3ab84434fafb5ea067ac2678a38a338c4a69ddc4bdb0c
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for NEAR;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "NEAR",
            0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for AUD;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "AUD",
            0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80
        );
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for GBP;
        perpsv2exchangerate_i.setOffchainPriceFeedId(
            "GBP",
            0x84c2dde9633d93d1bcad84e7dc41c9d56578b7ec52fabedc1f335d673df0a7c1
        );

        // perpsv2marketsettings_i.setTakerFee("sBTCPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sBTCPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sBTCPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sBTCPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sBTCPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sBTCPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sBTCPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sBTCPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sBTCPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sBTCPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sBTCPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sBTCPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sBTCPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sBTCPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sBTCPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sBTCPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sBTCPERP", "ocBTCPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sBTCPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sBTCPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sLINKPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sLINKPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sLINKPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sLINKPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sLINKPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sLINKPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sLINKPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sLINKPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sLINKPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sLINKPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sLINKPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sLINKPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sLINKPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sLINKPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sLINKPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sLINKPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sLINKPERP", "ocLINKPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sLINKPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sLINKPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sSOLPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sSOLPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sSOLPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sSOLPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sSOLPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sSOLPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sSOLPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sSOLPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sSOLPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sSOLPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sSOLPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sSOLPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sSOLPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sSOLPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sSOLPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sSOLPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sSOLPERP", "ocSOLPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sSOLPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sSOLPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sAVAXPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sAVAXPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sAVAXPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sAVAXPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sAVAXPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sAVAXPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sAVAXPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sAVAXPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sAVAXPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sAVAXPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sAVAXPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sAVAXPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sAVAXPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sAVAXPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sAVAXPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sAVAXPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sAVAXPERP", "ocAVAXPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sAVAXPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sAVAXPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sAAVEPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sAAVEPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sAAVEPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sAAVEPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sAAVEPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sAAVEPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sAAVEPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sAAVEPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sAAVEPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sAAVEPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sAAVEPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sAAVEPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sAAVEPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sAAVEPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sAAVEPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sAAVEPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sAAVEPERP", "ocAAVEPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sAAVEPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sAAVEPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sUNIPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sUNIPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sUNIPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sUNIPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sUNIPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sUNIPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sUNIPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sUNIPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sUNIPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sUNIPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sUNIPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sUNIPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sUNIPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sUNIPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sUNIPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sUNIPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sUNIPERP", "ocUNIPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sUNIPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sUNIPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sMATICPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sMATICPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sMATICPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sMATICPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sMATICPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sMATICPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sMATICPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sMATICPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sMATICPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sMATICPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sMATICPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sMATICPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sMATICPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sMATICPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sMATICPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sMATICPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sMATICPERP", "ocMATICPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sMATICPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sMATICPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sAPEPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sAPEPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sAPEPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sAPEPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sAPEPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sAPEPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sAPEPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sAPEPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sAPEPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sAPEPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sAPEPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sAPEPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sAPEPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sAPEPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sAPEPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sAPEPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sAPEPERP", "ocAPEPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sAPEPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sAPEPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sDYDXPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sDYDXPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sDYDXPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sDYDXPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sDYDXPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sDYDXPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sDYDXPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sDYDXPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sDYDXPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sDYDXPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sDYDXPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sDYDXPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sDYDXPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sDYDXPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sDYDXPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sDYDXPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sDYDXPERP", "ocDYDXPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sDYDXPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sDYDXPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sBNBPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sBNBPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sBNBPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sBNBPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sBNBPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sBNBPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sBNBPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sBNBPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sBNBPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sBNBPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sBNBPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sBNBPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sBNBPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sBNBPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sBNBPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sBNBPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sBNBPERP", "ocBNBPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sBNBPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sBNBPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sOPPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sOPPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sOPPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sOPPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sOPPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sOPPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sOPPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sOPPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sOPPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sOPPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sOPPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sOPPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sOPPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sOPPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sOPPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sOPPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sOPPERP", "ocOPPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sOPPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sOPPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sDOGEPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sDOGEPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sDOGEPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sDOGEPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sDOGEPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sDOGEPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sDOGEPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sDOGEPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sDOGEPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sDOGEPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sDOGEPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sDOGEPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sDOGEPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sDOGEPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sDOGEPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sDOGEPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sDOGEPERP", "ocDOGEPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sDOGEPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sDOGEPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sXAUPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sXAUPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sXAUPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sXAUPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sXAUPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sXAUPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sXAUPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sXAUPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sXAUPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sXAUPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sXAUPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sXAUPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sXAUPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sXAUPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sXAUPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sXAUPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sXAUPERP", "ocXAUPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sXAUPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sXAUPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sXAGPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sXAGPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sXAGPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sXAGPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sXAGPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sXAGPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sXAGPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sXAGPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sXAGPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sXAGPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sXAGPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sXAGPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sXAGPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sXAGPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sXAGPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sXAGPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sXAGPERP", "ocXAGPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sXAGPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sXAGPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sEURPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sEURPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sEURPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sEURPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sEURPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sEURPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sEURPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sEURPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sEURPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sEURPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sEURPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sEURPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sEURPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sEURPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sEURPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sEURPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sEURPERP", "ocEURPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sEURPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sEURPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sATOMPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sATOMPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sATOMPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sATOMPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sATOMPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sATOMPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sATOMPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sATOMPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sATOMPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sATOMPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sATOMPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sATOMPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sATOMPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sATOMPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sATOMPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sATOMPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sATOMPERP", "ocATOMPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sATOMPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sATOMPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sAXSPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sAXSPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sAXSPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sAXSPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sAXSPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sAXSPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sAXSPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sAXSPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sAXSPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sAXSPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sAXSPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sAXSPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sAXSPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sAXSPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sAXSPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sAXSPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sAXSPERP", "ocAXSPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sAXSPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sAXSPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sFLOWPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sFLOWPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sFLOWPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sFLOWPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sFLOWPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sFLOWPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sFLOWPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sFLOWPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sFLOWPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sFLOWPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sFLOWPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sFLOWPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sFLOWPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sFLOWPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sFLOWPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sFLOWPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sFLOWPERP", "ocFLOWPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sFLOWPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sFLOWPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sFTMPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sFTMPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sFTMPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sFTMPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sFTMPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sFTMPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sFTMPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sFTMPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sFTMPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sFTMPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sFTMPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sFTMPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sFTMPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sFTMPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sFTMPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sFTMPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sFTMPERP", "ocFTMPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sFTMPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sFTMPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sNEARPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sNEARPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sNEARPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sNEARPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sNEARPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sNEARPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sNEARPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sNEARPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sNEARPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sNEARPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sNEARPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sNEARPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sNEARPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sNEARPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sNEARPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sNEARPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sNEARPERP", "ocNEARPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sNEARPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sNEARPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sAUDPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sAUDPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sAUDPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sAUDPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sAUDPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sAUDPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sAUDPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sAUDPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sAUDPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sAUDPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sAUDPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sAUDPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sAUDPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sAUDPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sAUDPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sAUDPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sAUDPERP", "ocAUDPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sAUDPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sAUDPERP", 1000000000000000000);

        // perpsv2marketsettings_i.setTakerFee("sGBPPERP", 10000000000000000);
        // perpsv2marketsettings_i.setMakerFee("sGBPPERP", 7000000000000000);
        // perpsv2marketsettings_i.setTakerFeeDelayedOrder("sGBPPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeDelayedOrder("sGBPPERP", 500000000000000);
        // perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sGBPPERP", 1000000000000000);
        // perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sGBPPERP", 500000000000000);
        // perpsv2marketsettings_i.setNextPriceConfirmWindow("sGBPPERP", 2);
        // perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sGBPPERP", 120);
        // perpsv2marketsettings_i.setMinDelayTimeDelta("sGBPPERP", 60);
        // perpsv2marketsettings_i.setMaxDelayTimeDelta("sGBPPERP", 6000);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sGBPPERP", 15);
        // perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sGBPPERP", 120);
        // perpsv2marketsettings_i.setMaxLeverage("sGBPPERP", 100000000000000000000);
        // perpsv2marketsettings_i.setMaxMarketValue("sGBPPERP", 1000000000000000000000);
        // perpsv2marketsettings_i.setMaxFundingVelocity("sGBPPERP", 3000000000000000000);
        // perpsv2marketsettings_i.setSkewScale("sGBPPERP", 1000000000000000000000000);
        // perpsv2marketsettings_i.setOffchainMarketKey("sGBPPERP", "ocGBPPERP");
        // perpsv2marketsettings_i.setOffchainPriceDivergence("sGBPPERP", 20000000000000000);
        // perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sGBPPERP", 1000000000000000000);

        // NOMINATE OWNERSHIP back to owner for aforementioned contracts
        nominateAll();
    }

    function acceptAll() internal {
        address[] memory contracts = contractsRequiringOwnership();
        for (uint i = 0; i < contracts.length; i++) {
            Owned(contracts[i]).acceptOwnership();
        }
    }

    function nominateAll() internal {
        address[] memory contracts = contractsRequiringOwnership();
        for (uint i = 0; i < contracts.length; i++) {
            returnOwnership(contracts[i]);
        }
    }

    function perpsv2exchangerate_addAssociatedContracts_0() internal {
        address[] memory perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0 = new address[](22);
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[0] = address(
            0x194ffc3D2cE0552720F24FefDf57a6c534223174
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[1] = address(
            0xf67fDa142f31686523D2b52CE25aD66895f23116
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[2] = address(
            0x139AF9de51Ca2594911502E7A5653D4693EFb4ED
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[3] = address(
            0xF7df260a4F46Eaf5A82589B9e9D3879e6FCee431
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[4] = address(
            0x2BF61b08F3e8DA40799D90C3b1e60f1c4DDb7fDA
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[5] = address(
            0x85875A05bE4db7a21dB6C53CeD09b06a5aD83402
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[6] = address(
            0x1651e832dcc1B9cF697810d822aee35A9f5fFD64
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[7] = address(
            0xE99dB61288A4e8968ee58C03cc142c6ddB500598
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[8] = address(
            0xF612F3098a277cb80Ad03f20cf7787aD1Dc48f4a
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[9] = address(
            0x8c2c26494eAe20A8a22f94ED5Fa4B104FAD6bcca
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[10] = address(
            0xd2471115Be883EA7A32907D78062C323a5E85593
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[11] = address(
            0xfde9d8F4d2fB18823363fdd0E1fF305c4696A19D
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[12] = address(
            0xf8B9Dd242BDAF6242cb783F02b49D1Dd9126DE5c
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[13] = address(
            0x909c690556D8389AEa348377EB27dECFb1b27d29
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[14] = address(
            0xB0A058c7781F6EcA709d4b469FCc522a6fA38E60
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[15] = address(
            0x14688DFAa8b4085DA485579f72F3DE467485411a
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[16] = address(
            0x43406c99fc8a7776F2870800e38FF5c8Cc96a2fE
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[17] = address(
            0xF40482B4DA5509d6a9fb3Bed08E2356D72c31028
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[18] = address(
            0x08941749026fF010c22E8B9d93a76EEBFC61C13b
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[19] = address(
            0xBF3B13F155070a61156f261b26D0Eb06f629C2e6
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[20] = address(
            0x2A656E9618185782A638c86C64b5702854DDB11A
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0[21] = address(
            0x0BB25623946960D8FB1696a9D70466766F2C8aa7
        );
        perpsv2exchangerate_i.addAssociatedContracts(perpsv2exchangerate_addAssociatedContracts_associatedContracts_0_0);
    }

    function futuresmarketmanager_addProxiedMarkets_1() internal {
        address[] memory futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0 = new address[](11);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[0] = address(0x59b007E9ea8F89b069c43F8f45834d30853e3699);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[1] = address(0x31A1659Ca00F617E86Dc765B6494Afe70a5A9c1A);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[2] = address(0x0EA09D97b4084d859328ec4bF8eBCF9ecCA26F1D);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[3] = address(0xc203A12F298CE73E44F7d45A4f59a43DBfFe204D);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[4] = address(0x5374761526175B59f1E583246E20639909E189cE);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[5] = address(0x4308427C463CAEAaB50FFf98a9deC569C31E4E87);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[6] = address(0x074B8F19fc91d6B2eb51143E1f186Ca0DDB88042);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[7] = address(0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[8] = address(0x139F94E4f0e1101c1464a321CBA815c34d58B5D9);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[9] = address(0x0940B0A96C5e1ba33AEE331a9f950Bb2a6F2Fb25);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[10] = address(0x442b69937a0daf9D46439a71567fABE6Cb69FBaf);
        futuresmarketmanager_i.addProxiedMarkets(futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0);
    }

    function futuresmarketmanager_addProxiedMarkets_2() internal {
        address[] memory futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0 = new address[](11);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[0] = address(0x98cCbC721cc05E28a125943D69039B39BE6A21e9);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[1] = address(0x549dbDFfbd47bD5639f9348eBE82E63e2f9F777A);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[2] = address(0xdcB8438c979fA030581314e5A5Df42bbFEd744a0);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[3] = address(0x87AE62c5720DAB812BDacba66cc24839440048d1);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[4] = address(0xbB16C7B3244DFA1a6BF83Fcce3EE4560837763CD);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[5] = address(0x3a52b21816168dfe35bE99b7C5fc209f17a0aDb1);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[6] = address(0x27665271210aCff4Fab08AD9Bb657E91866471F0);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[7] = address(0xC18f85A6DD3Bcd0516a1CA08d3B1f0A4E191A2C4);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[8] = address(0xC8fCd6fB4D15dD7C455373297dEF375a08942eCe);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[9] = address(0x9De146b5663b82F44E5052dEDe2aA3Fd4CBcDC99);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0[10] = address(0x1dAd8808D8aC58a0df912aDC4b215ca3B93D6C49);
        futuresmarketmanager_i.addProxiedMarkets(futuresmarketmanager_addProxiedMarkets_marketsToAdd_1_0);
    }

    function addressresolver_importAddresses_2() internal {
        bytes32[] memory addressresolver_importAddresses_names_2_0 = new bytes32[](22);
        addressresolver_importAddresses_names_2_0[0] = bytes32("PerpsV2MarketStateBTCPERP");
        addressresolver_importAddresses_names_2_0[1] = bytes32("PerpsV2MarketStateLINKPERP");
        addressresolver_importAddresses_names_2_0[2] = bytes32("PerpsV2MarketStateSOLPERP");
        addressresolver_importAddresses_names_2_0[3] = bytes32("PerpsV2MarketStateAVAXPERP");
        addressresolver_importAddresses_names_2_0[4] = bytes32("PerpsV2MarketStateAAVEPERP");
        addressresolver_importAddresses_names_2_0[5] = bytes32("PerpsV2MarketStateUNIPERP");
        addressresolver_importAddresses_names_2_0[6] = bytes32("PerpsV2MarketStateMATICPERP");
        addressresolver_importAddresses_names_2_0[7] = bytes32("PerpsV2MarketStateAPEPERP");
        addressresolver_importAddresses_names_2_0[8] = bytes32("PerpsV2MarketStateDYDXPERP");
        addressresolver_importAddresses_names_2_0[9] = bytes32("PerpsV2MarketStateBNBPERP");
        addressresolver_importAddresses_names_2_0[10] = bytes32("PerpsV2MarketStateOPPERP");
        addressresolver_importAddresses_names_2_0[11] = bytes32("PerpsV2MarketStateDOGEPERP");
        addressresolver_importAddresses_names_2_0[12] = bytes32("PerpsV2MarketStateXAUPERP");
        addressresolver_importAddresses_names_2_0[13] = bytes32("PerpsV2MarketStateXAGPERP");
        addressresolver_importAddresses_names_2_0[14] = bytes32("PerpsV2MarketStateEURPERP");
        addressresolver_importAddresses_names_2_0[15] = bytes32("PerpsV2MarketStateATOMPERP");
        addressresolver_importAddresses_names_2_0[16] = bytes32("PerpsV2MarketStateAXSPERP");
        addressresolver_importAddresses_names_2_0[17] = bytes32("PerpsV2MarketStateFLOWPERP");
        addressresolver_importAddresses_names_2_0[18] = bytes32("PerpsV2MarketStateFTMPERP");
        addressresolver_importAddresses_names_2_0[19] = bytes32("PerpsV2MarketStateNEARPERP");
        addressresolver_importAddresses_names_2_0[20] = bytes32("PerpsV2MarketStateAUDPERP");
        addressresolver_importAddresses_names_2_0[21] = bytes32("PerpsV2MarketStateGBPPERP");
        address[] memory addressresolver_importAddresses_destinations_2_1 = new address[](22);
        addressresolver_importAddresses_destinations_2_1[0] = address(new_PerpsV2MarketStateBTCPERP_contract);
        addressresolver_importAddresses_destinations_2_1[1] = address(new_PerpsV2MarketStateLINKPERP_contract);
        addressresolver_importAddresses_destinations_2_1[2] = address(new_PerpsV2MarketStateSOLPERP_contract);
        addressresolver_importAddresses_destinations_2_1[3] = address(new_PerpsV2MarketStateAVAXPERP_contract);
        addressresolver_importAddresses_destinations_2_1[4] = address(new_PerpsV2MarketStateAAVEPERP_contract);
        addressresolver_importAddresses_destinations_2_1[5] = address(new_PerpsV2MarketStateUNIPERP_contract);
        addressresolver_importAddresses_destinations_2_1[6] = address(new_PerpsV2MarketStateMATICPERP_contract);
        addressresolver_importAddresses_destinations_2_1[7] = address(new_PerpsV2MarketStateAPEPERP_contract);
        addressresolver_importAddresses_destinations_2_1[8] = address(new_PerpsV2MarketStateDYDXPERP_contract);
        addressresolver_importAddresses_destinations_2_1[9] = address(new_PerpsV2MarketStateBNBPERP_contract);
        addressresolver_importAddresses_destinations_2_1[10] = address(new_PerpsV2MarketStateOPPERP_contract);
        addressresolver_importAddresses_destinations_2_1[11] = address(new_PerpsV2MarketStateDOGEPERP_contract);
        addressresolver_importAddresses_destinations_2_1[12] = address(new_PerpsV2MarketStateXAUPERP_contract);
        addressresolver_importAddresses_destinations_2_1[13] = address(new_PerpsV2MarketStateXAGPERP_contract);
        addressresolver_importAddresses_destinations_2_1[14] = address(new_PerpsV2MarketStateEURPERP_contract);
        addressresolver_importAddresses_destinations_2_1[15] = address(new_PerpsV2MarketStateATOMPERP_contract);
        addressresolver_importAddresses_destinations_2_1[16] = address(new_PerpsV2MarketStateAXSPERP_contract);
        addressresolver_importAddresses_destinations_2_1[17] = address(new_PerpsV2MarketStateFLOWPERP_contract);
        addressresolver_importAddresses_destinations_2_1[18] = address(new_PerpsV2MarketStateFTMPERP_contract);
        addressresolver_importAddresses_destinations_2_1[19] = address(new_PerpsV2MarketStateNEARPERP_contract);
        addressresolver_importAddresses_destinations_2_1[20] = address(new_PerpsV2MarketStateAUDPERP_contract);
        addressresolver_importAddresses_destinations_2_1[21] = address(new_PerpsV2MarketStateGBPPERP_contract);
        addressresolver_i.importAddresses(
            addressresolver_importAddresses_names_2_0,
            addressresolver_importAddresses_destinations_2_1
        );
    }
}