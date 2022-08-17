/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-17
*/

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: migrations/Migration_MuhlifainOptimism.sol
*
* Latest source (may be newer): https://github.com/Synthetixio/synthetix/blob/master/contracts/migrations/Migration_MuhlifainOptimism.sol
* Docs: https://docs.synthetix.io/contracts/migrations/Migration_MuhlifainOptimism
*
* Contract Dependencies: 
*	- BaseMigration
*	- IAddressResolver
*	- IExchangeRates
*	- IExchangeState
*	- IFuturesMarketManager
*	- IFuturesMarketSettings
*	- IIssuer
*	- ISystemStatus
*	- MixinFuturesMarketSettings
*	- MixinResolver
*	- MixinSystemSettings
*	- Owned
*	- State
* Libraries: 
*	- AddressSetLib
*	- SafeCast
*	- SafeDecimalMath
*	- SafeMath
*	- VestingEntries
*
* MIT License
* ===========
*
* Copyright (c) 2022 Synthetix
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
        returns (uint totalRedeemed, uint amountToLiquidate);

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


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/proxy
contract Proxy is Owned {
    Proxyable public target;

    constructor(address _owner) public Owned(_owner) {}

    function setTarget(Proxyable _target) external onlyOwner {
        target = _target;
        emit TargetUpdated(_target);
    }

    function _emit(
        bytes calldata callData,
        uint numTopics,
        bytes32 topic1,
        bytes32 topic2,
        bytes32 topic3,
        bytes32 topic4
    ) external onlyTarget {
        uint size = callData.length;
        bytes memory _callData = callData;

        assembly {
            /* The first 32 bytes of callData contain its length (as specified by the abi).
             * Length is assumed to be a uint256 and therefore maximum of 32 bytes
             * in length. It is also leftpadded to be a multiple of 32 bytes.
             * This means moving call_data across 32 bytes guarantees we correctly access
             * the data itself. */
            switch numTopics
                case 0 {
                    log0(add(_callData, 32), size)
                }
                case 1 {
                    log1(add(_callData, 32), size, topic1)
                }
                case 2 {
                    log2(add(_callData, 32), size, topic1, topic2)
                }
                case 3 {
                    log3(add(_callData, 32), size, topic1, topic2, topic3)
                }
                case 4 {
                    log4(add(_callData, 32), size, topic1, topic2, topic3, topic4)
                }
        }
    }

    // solhint-disable no-complex-fallback
    function() external payable {
        // Mutable call setting Proxyable.messageSender as this is using call not delegatecall
        target.setMessageSender(msg.sender);

        assembly {
            let free_ptr := mload(0x40)
            calldatacopy(free_ptr, 0, calldatasize)

            /* We must explicitly forward ether to the underlying contract as well. */
            let result := call(gas, sload(target_slot), callvalue, free_ptr, calldatasize, 0, 0)
            returndatacopy(free_ptr, 0, returndatasize)

            if iszero(result) {
                revert(free_ptr, returndatasize)
            }
            return(free_ptr, returndatasize)
        }
    }

    modifier onlyTarget {
        require(Proxyable(msg.sender) == target, "Must be proxy target");
        _;
    }

    event TargetUpdated(Proxyable newTarget);
}


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/proxyable
contract Proxyable is Owned {
    // This contract should be treated like an abstract contract

    /* The proxy this contract exists behind. */
    Proxy public proxy;

    /* The caller of the proxy, passed through to this contract.
     * Note that every function using this member must apply the onlyProxy or
     * optionalProxy modifiers, otherwise their invocations can use stale values. */
    address public messageSender;

    constructor(address payable _proxy) internal {
        // This contract is abstract, and thus cannot be instantiated directly
        require(owner != address(0), "Owner must be set");

        proxy = Proxy(_proxy);
        emit ProxyUpdated(_proxy);
    }

    function setProxy(address payable _proxy) external onlyOwner {
        proxy = Proxy(_proxy);
        emit ProxyUpdated(_proxy);
    }

    function setMessageSender(address sender) external onlyProxy {
        messageSender = sender;
    }

    modifier onlyProxy {
        _onlyProxy();
        _;
    }

    function _onlyProxy() private view {
        require(Proxy(msg.sender) == proxy, "Only the proxy can call");
    }

    modifier optionalProxy {
        _optionalProxy();
        _;
    }

    function _optionalProxy() private {
        if (Proxy(msg.sender) != proxy && messageSender != msg.sender) {
            messageSender = msg.sender;
        }
    }

    modifier optionalProxy_onlyOwner {
        _optionalProxy_onlyOwner();
        _;
    }

    // solhint-disable-next-line func-name-mixedcase
    function _optionalProxy_onlyOwner() private {
        if (Proxy(msg.sender) != proxy && messageSender != msg.sender) {
            messageSender = msg.sender;
        }
        require(messageSender == owner, "Owner only function");
    }

    event ProxyUpdated(address proxyAddress);
}


interface IFuturesMarketManager {
    function markets(uint index, uint pageSize) external view returns (address[] memory);

    function numMarkets() external view returns (uint);

    function allMarkets() external view returns (address[] memory);

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

    function suspendSynthWithInvalidRate(bytes32 currencyKey) external;
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


pragma experimental ABIEncoderV2;

// Inheritance


// Libraries


// Internal references


// basic views that are expected to be supported by v1 (IFuturesMarket) and v2 markets (IPerpsV2Market)
interface IMarketViews {
    function marketKey() external view returns (bytes32);

    function baseAsset() external view returns (bytes32);

    function marketSize() external view returns (uint128);

    function marketSkew() external view returns (int128);

    function assetPrice() external view returns (uint price, bool invalid);

    function marketDebt() external view returns (uint debt, bool isInvalid);

    function currentFundingRate() external view returns (int fundingRate);
}

// https://docs.synthetix.io/contracts/source/contracts/FuturesMarketManager
contract FuturesMarketManager is Owned, MixinResolver, IFuturesMarketManager {
    using SafeMath for uint;
    using AddressSetLib for AddressSetLib.AddressSet;

    /* ========== STATE VARIABLES ========== */

    AddressSetLib.AddressSet internal _markets;
    mapping(bytes32 => address) public marketForKey;

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
        return _markets.getPage(index, pageSize);
    }

    /*
     * The number of markets known to the manager.
     */
    function numMarkets() external view returns (uint) {
        return _markets.elements.length;
    }

    /*
     * The list of all markets.
     */
    function allMarkets() public view returns (address[] memory) {
        return _markets.getPage(0, _markets.elements.length);
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
        uint numOfMarkets = _markets.elements.length;
        for (uint i = 0; i < numOfMarkets; i++) {
            (uint marketDebt, bool invalid) = IMarketViews(_markets.elements[i]).marketDebt();
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
        bool priceInvalid;
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

            summaries[i] = MarketSummary({
                market: address(market),
                asset: baseAsset,
                marketKey: marketKey,
                price: price,
                marketSize: market.marketSize(),
                marketSkew: market.marketSkew(),
                marketDebt: debt,
                currentFundingRate: market.currentFundingRate(),
                priceInvalid: invalid
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

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function addMarkets(address[] calldata marketsToAdd) external onlyOwner {
        uint numOfMarkets = marketsToAdd.length;
        for (uint i; i < numOfMarkets; i++) {
            address market = marketsToAdd[i];
            require(!_markets.contains(market), "Market already exists");

            bytes32 key = IMarketViews(market).marketKey();
            bytes32 baseAsset = IMarketViews(market).baseAsset();

            require(marketForKey[key] == address(0), "Market already exists for key");
            marketForKey[key] = market;
            _markets.add(market);
            emit MarketAdded(market, baseAsset, key);
        }
    }

    function _removeMarkets(address[] memory marketsToRemove) internal {
        uint numOfMarkets = marketsToRemove.length;
        for (uint i; i < numOfMarkets; i++) {
            address market = marketsToRemove[i];
            require(market != address(0), "Unknown market");

            bytes32 key = IMarketViews(market).marketKey();
            bytes32 baseAsset = IMarketViews(market).baseAsset();

            require(marketForKey[key] != address(0), "Unknown market");
            delete marketForKey[key];
            _markets.remove(market);
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

    /*
     * Allows a market to issue sUSD to an account when it withdraws margin.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function issueSUSD(address account, uint amount) external onlyMarkets {
        // No settlement is required to issue synths into the target account.
        _sUSD().issue(account, amount);
    }

    /*
     * Allows a market to burn sUSD from an account when it deposits margin.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function burnSUSD(address account, uint amount) external onlyMarkets returns (uint postReclamationAmount) {
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
    function payFee(uint amount, bytes32 trackingCode) external onlyMarkets {
        _payFee(amount, trackingCode);
    }

    // backwards compatibility with futures v1
    function payFee(uint amount) external onlyMarkets {
        _payFee(amount, bytes32(0));
    }

    function _payFee(uint amount, bytes32 trackingCode) internal {
        delete trackingCode; // unused for now, will be used SIP 203
        IFeePool pool = _feePool();
        _sUSD().issue(pool.FEE_ADDRESS(), amount);
        pool.recordFeePaid(amount);
    }

    /* ========== MODIFIERS ========== */

    function _requireIsMarket() internal view {
        require(_markets.contains(msg.sender), "Permitted only for markets");
    }

    modifier onlyMarkets() {
        _requireIsMarket();
        _;
    }

    /* ========== EVENTS ========== */

    event MarketAdded(address market, bytes32 indexed asset, bytes32 indexed marketKey);

    event MarketRemoved(address market, bytes32 indexed asset, bytes32 indexed marketKey);
}


// Inheritance


// https://docs.synthetix.io/contracts/source/contracts/state
contract State is Owned {
    // the address of the contract that can modify variables
    // this can only be changed by the owner of this contract
    address public associatedContract;

    constructor(address _associatedContract) internal {
        // This contract is abstract, and thus cannot be instantiated directly
        require(owner != address(0), "Owner must be set");

        associatedContract = _associatedContract;
        emit AssociatedContractUpdated(_associatedContract);
    }

    /* ========== SETTERS ========== */

    // Change the associated contract to a new address
    function setAssociatedContract(address _associatedContract) external onlyOwner {
        associatedContract = _associatedContract;
        emit AssociatedContractUpdated(_associatedContract);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAssociatedContract {
        require(msg.sender == associatedContract, "Only the associated contract can perform this action");
        _;
    }

    /* ========== EVENTS ========== */

    event AssociatedContractUpdated(address associatedContract);
}


// https://docs.synthetix.io/contracts/source/interfaces/iexchangestate
interface IExchangeState {
    // Views
    struct ExchangeEntry {
        bytes32 src;
        uint amount;
        bytes32 dest;
        uint amountReceived;
        uint exchangeFeeRate;
        uint timestamp;
        uint roundIdForSrc;
        uint roundIdForDest;
    }

    function getLengthOfEntries(address account, bytes32 currencyKey) external view returns (uint);

    function getEntryAt(
        address account,
        bytes32 currencyKey,
        uint index
    )
        external
        view
        returns (
            bytes32 src,
            uint amount,
            bytes32 dest,
            uint amountReceived,
            uint exchangeFeeRate,
            uint timestamp,
            uint roundIdForSrc,
            uint roundIdForDest
        );

    function getMaxTimestamp(address account, bytes32 currencyKey) external view returns (uint);

    // Mutative functions
    function appendExchangeEntry(
        address account,
        bytes32 src,
        uint amount,
        bytes32 dest,
        uint amountReceived,
        uint exchangeFeeRate,
        uint timestamp,
        uint roundIdForSrc,
        uint roundIdForDest
    ) external;

    function removeEntries(address account, bytes32 currencyKey) external;
}


// Inheritance


// https://docs.synthetix.io/contracts/source/contracts/exchangestate
contract ExchangeState is Owned, State, IExchangeState {
    mapping(address => mapping(bytes32 => IExchangeState.ExchangeEntry[])) public exchanges;

    uint public maxEntriesInQueue = 12;

    constructor(address _owner, address _associatedContract) public Owned(_owner) State(_associatedContract) {}

    /* ========== SETTERS ========== */

    function setMaxEntriesInQueue(uint _maxEntriesInQueue) external onlyOwner {
        maxEntriesInQueue = _maxEntriesInQueue;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function appendExchangeEntry(
        address account,
        bytes32 src,
        uint amount,
        bytes32 dest,
        uint amountReceived,
        uint exchangeFeeRate,
        uint timestamp,
        uint roundIdForSrc,
        uint roundIdForDest
    ) external onlyAssociatedContract {
        require(exchanges[account][dest].length < maxEntriesInQueue, "Max queue length reached");

        exchanges[account][dest].push(
            ExchangeEntry({
                src: src,
                amount: amount,
                dest: dest,
                amountReceived: amountReceived,
                exchangeFeeRate: exchangeFeeRate,
                timestamp: timestamp,
                roundIdForSrc: roundIdForSrc,
                roundIdForDest: roundIdForDest
            })
        );
    }

    function removeEntries(address account, bytes32 currencyKey) external onlyAssociatedContract {
        delete exchanges[account][currencyKey];
    }

    /* ========== VIEWS ========== */

    function getLengthOfEntries(address account, bytes32 currencyKey) external view returns (uint) {
        return exchanges[account][currencyKey].length;
    }

    function getEntryAt(
        address account,
        bytes32 currencyKey,
        uint index
    )
        external
        view
        returns (
            bytes32 src,
            uint amount,
            bytes32 dest,
            uint amountReceived,
            uint exchangeFeeRate,
            uint timestamp,
            uint roundIdForSrc,
            uint roundIdForDest
        )
    {
        ExchangeEntry storage entry = exchanges[account][currencyKey][index];
        return (
            entry.src,
            entry.amount,
            entry.dest,
            entry.amountReceived,
            entry.exchangeFeeRate,
            entry.timestamp,
            entry.roundIdForSrc,
            entry.roundIdForDest
        );
    }

    function getMaxTimestamp(address account, bytes32 currencyKey) external view returns (uint) {
        ExchangeEntry[] storage userEntries = exchanges[account][currencyKey];
        uint timestamp = 0;
        for (uint i = 0; i < userEntries.length; i++) {
            if (userEntries[i].timestamp > timestamp) {
                timestamp = userEntries[i].timestamp;
            }
        }
        return timestamp;
    }
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
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint
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

    function synthTooVolatileForAtomicExchange(bytes32) external view returns (bool) {
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


// SPDX-License-Identifier: MIT


/**
 * @dev Wrappers over Solidity's uintXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and then downcasting.
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
        require(value < 2**128, "SafeCast: value doesn't fit in 128 bits");
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
        require(value < 2**64, "SafeCast: value doesn't fit in 64 bits");
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
        require(value < 2**32, "SafeCast: value doesn't fit in 32 bits");
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
        require(value < 2**16, "SafeCast: value doesn't fit in 16 bits");
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
        require(value < 2**8, "SafeCast: value doesn't fit in 8 bits");
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


// https://docs.synthetix.io/contracts/source/interfaces/isynthetix
interface ISynthetix {
    // Views
    function anySynthOrSNXRateIsInvalid() external view returns (bool anyRateInvalid);

    function availableCurrencyKeys() external view returns (bytes32[] memory);

    function availableSynthCount() external view returns (uint);

    function availableSynths(uint index) external view returns (ISynth);

    function collateral(address account) external view returns (uint);

    function collateralisationRatio(address issuer) external view returns (uint);

    function debtBalanceOf(address issuer, bytes32 currencyKey) external view returns (uint);

    function isWaitingPeriod(bytes32 currencyKey) external view returns (bool);

    function maxIssuableSynths(address issuer) external view returns (uint maxIssuable);

    function remainingIssuableSynths(address issuer)
        external
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt
        );

    function synths(bytes32 currencyKey) external view returns (ISynth);

    function synthsByAddress(address synthAddress) external view returns (bytes32);

    function totalIssuedSynths(bytes32 currencyKey) external view returns (uint);

    function totalIssuedSynthsExcludeOtherCollateral(bytes32 currencyKey) external view returns (uint);

    function transferableSynthetix(address account) external view returns (uint transferable);

    // Mutative Functions
    function burnSynths(uint amount) external;

    function burnSynthsOnBehalf(address burnForAddress, uint amount) external;

    function burnSynthsToTarget() external;

    function burnSynthsToTargetOnBehalf(address burnForAddress) external;

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
    ) external returns (uint amountReceived);

    function exchangeWithTrackingForInitiator(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);

    function exchangeOnBehalfWithTracking(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);

    function exchangeWithVirtual(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        bytes32 trackingCode
    ) external returns (uint amountReceived, IVirtualSynth vSynth);

    function exchangeAtomically(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        bytes32 trackingCode,
        uint minAmount
    ) external returns (uint amountReceived);

    function issueMaxSynths() external;

    function issueMaxSynthsOnBehalf(address issueForAddress) external;

    function issueSynths(uint amount) external;

    function issueSynthsOnBehalf(address issueForAddress, uint amount) external;

    function mint() external returns (bool);

    function settle(bytes32 currencyKey)
        external
        returns (
            uint reclaimed,
            uint refunded,
            uint numEntries
        );

    // Liquidations
    function liquidateDelinquentAccount(address account) external returns (bool);

    function liquidateSelf() external returns (bool);

    // Restricted Functions

    function mintSecondary(address account, uint amount) external;

    function mintSecondaryRewards(uint amount) external;

    function burnSecondary(address account, uint amount) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/isynthetixdebtshare
interface ISynthetixDebtShare {
    // Views

    function currentPeriodId() external view returns (uint128);

    function allowance(address account, address spender) external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function balanceOfOnPeriod(address account, uint periodId) external view returns (uint);

    function totalSupply() external view returns (uint);

    function sharePercent(address account) external view returns (uint);

    function sharePercentOnPeriod(address account, uint periodId) external view returns (uint);

    // Mutative functions

    function takeSnapshot(uint128 id) external;

    function mintShare(address account, uint256 amount) external;

    function burnShare(address account, uint256 amount) external;

    function approve(address, uint256) external pure returns (bool);

    function transfer(address to, uint256 amount) external pure returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function addAuthorizedBroker(address target) external;

    function removeAuthorizedBroker(address target) external;

    function addAuthorizedToSnapshot(address target) external;

    function removeAuthorizedToSnapshot(address target) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/idelegateapprovals
interface IDelegateApprovals {
    // Views
    function canBurnFor(address authoriser, address delegate) external view returns (bool);

    function canIssueFor(address authoriser, address delegate) external view returns (bool);

    function canClaimFor(address authoriser, address delegate) external view returns (bool);

    function canExchangeFor(address authoriser, address delegate) external view returns (bool);

    // Mutative
    function approveAllDelegatePowers(address delegate) external;

    function removeAllDelegatePowers(address delegate) external;

    function approveBurnOnBehalf(address delegate) external;

    function removeBurnOnBehalf(address delegate) external;

    function approveIssueOnBehalf(address delegate) external;

    function removeIssueOnBehalf(address delegate) external;

    function approveClaimOnBehalf(address delegate) external;

    function removeClaimOnBehalf(address delegate) external;

    function approveExchangeOnBehalf(address delegate) external;

    function removeExchangeOnBehalf(address delegate) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/ihasbalance
interface IHasBalance {
    // Views
    function balanceOf(address account) external view returns (uint);
}


interface ILiquidator {
    // Views
    function issuanceRatio() external view returns (uint);

    function liquidationDelay() external view returns (uint);

    function liquidationRatio() external view returns (uint);

    function liquidationEscrowDuration() external view returns (uint);

    function liquidationPenalty() external view returns (uint);

    function selfLiquidationPenalty() external view returns (uint);

    function liquidateReward() external view returns (uint);

    function flagReward() external view returns (uint);

    function liquidationCollateralRatio() external view returns (uint);

    function getLiquidationDeadlineForAccount(address account) external view returns (uint);

    function getLiquidationCallerForAccount(address account) external view returns (address);

    function isLiquidationOpen(address account, bool isSelfLiquidation) external view returns (bool);

    function isLiquidationDeadlinePassed(address account) external view returns (bool);

    function calculateAmountToFixCollateral(
        uint debtBalance,
        uint collateral,
        uint penalty
    ) external view returns (uint);

    // Mutative Functions
    function flagAccountForLiquidation(address account) external;

    // Restricted: used internally to Synthetix contracts
    function removeAccountInLiquidation(address account) external;

    function checkAndRemoveAccountInLiquidation(address account) external;
}


interface ILiquidatorRewards {
    // Views

    function earned(address account) external view returns (uint256);

    // Mutative

    function getReward(address account) external;

    function notifyRewardAmount(uint256 reward) external;

    function updateEntry(address account) external;
}


interface ICollateralManager {
    // Manager information
    function hasCollateral(address collateral) external view returns (bool);

    function isSynthManaged(bytes32 currencyKey) external view returns (bool);

    // State information
    function long(bytes32 synth) external view returns (uint amount);

    function short(bytes32 synth) external view returns (uint amount);

    function totalLong() external view returns (uint susdValue, bool anyRateIsInvalid);

    function totalShort() external view returns (uint susdValue, bool anyRateIsInvalid);

    function getBorrowRate() external view returns (uint borrowRate, bool anyRateIsInvalid);

    function getShortRate(bytes32 synth) external view returns (uint shortRate, bool rateIsInvalid);

    function getRatesAndTime(uint index)
        external
        view
        returns (
            uint entryRate,
            uint lastRate,
            uint lastUpdated,
            uint newIndex
        );

    function getShortRatesAndTime(bytes32 currency, uint index)
        external
        view
        returns (
            uint entryRate,
            uint lastRate,
            uint lastUpdated,
            uint newIndex
        );

    function exceedsDebtLimit(uint amount, bytes32 currency) external view returns (bool canIssue, bool anyRateIsInvalid);

    function areSynthsAndCurrenciesSet(bytes32[] calldata requiredSynthNamesInResolver, bytes32[] calldata synthKeys)
        external
        view
        returns (bool);

    function areShortableSynthsSet(bytes32[] calldata requiredSynthNamesInResolver, bytes32[] calldata synthKeys)
        external
        view
        returns (bool);

    // Loans
    function getNewLoanId() external returns (uint id);

    // Manager mutative
    function addCollaterals(address[] calldata collaterals) external;

    function removeCollaterals(address[] calldata collaterals) external;

    function addSynths(bytes32[] calldata synthNamesInResolver, bytes32[] calldata synthKeys) external;

    function removeSynths(bytes32[] calldata synths, bytes32[] calldata synthKeys) external;

    function addShortableSynths(bytes32[] calldata requiredSynthNamesInResolver, bytes32[] calldata synthKeys) external;

    function removeShortableSynths(bytes32[] calldata synths) external;

    // State mutative

    function incrementLongs(bytes32 synth, uint amount) external;

    function decrementLongs(bytes32 synth, uint amount) external;

    function incrementShorts(bytes32 synth, uint amount) external;

    function decrementShorts(bytes32 synth, uint amount) external;

    function accrueInterest(
        uint interestIndex,
        bytes32 currency,
        bool isShort
    ) external returns (uint difference, uint index);

    function updateBorrowRatesCollateral(uint rate) external;

    function updateShortRatesCollateral(bytes32 currency, uint rate) external;
}


library VestingEntries {
    struct VestingEntry {
        uint64 endTime;
        uint256 escrowAmount;
    }
    struct VestingEntryWithID {
        uint64 endTime;
        uint256 escrowAmount;
        uint256 entryID;
    }
}

interface IRewardEscrowV2 {
    // Views
    function balanceOf(address account) external view returns (uint);

    function numVestingEntries(address account) external view returns (uint);

    function totalEscrowedAccountBalance(address account) external view returns (uint);

    function totalVestedAccountBalance(address account) external view returns (uint);

    function getVestingQuantity(address account, uint256[] calldata entryIDs) external view returns (uint);

    function getVestingSchedules(
        address account,
        uint256 index,
        uint256 pageSize
    ) external view returns (VestingEntries.VestingEntryWithID[] memory);

    function getAccountVestingEntryIDs(
        address account,
        uint256 index,
        uint256 pageSize
    ) external view returns (uint256[] memory);

    function getVestingEntryClaimable(address account, uint256 entryID) external view returns (uint);

    function getVestingEntry(address account, uint256 entryID) external view returns (uint64, uint256);

    // Mutative functions
    function vest(uint256[] calldata entryIDs) external;

    function createEscrowEntry(
        address beneficiary,
        uint256 deposit,
        uint256 duration
    ) external;

    function appendVestingEntry(
        address account,
        uint256 quantity,
        uint256 duration
    ) external;

    function migrateVestingSchedule(address _addressToMigrate) external;

    function migrateAccountEscrowBalances(
        address[] calldata accounts,
        uint256[] calldata escrowBalances,
        uint256[] calldata vestedBalances
    ) external;

    // Account Merging
    function startMergingWindow() external;

    function mergeAccount(address accountToMerge, uint256[] calldata entryIDs) external;

    function nominateAccountToMerge(address account) external;

    function accountMergingIsOpen() external view returns (bool);

    // L2 Migration
    function importVestingEntries(
        address account,
        uint256 escrowedAmount,
        VestingEntries.VestingEntry[] calldata vestingEntries
    ) external;

    // Return amount of SNX transfered to SynthetixBridgeToOptimism deposit contract
    function burnForMigration(address account, uint256[] calldata entryIDs)
        external
        returns (uint256 escrowedAccountBalance, VestingEntries.VestingEntry[] memory vestingEntries);
}


interface ISynthRedeemer {
    // Rate of redemption - 0 for none
    function redemptions(address synthProxy) external view returns (uint redeemRate);

    // sUSD balance of deprecated token holder
    function balanceOf(IERC20 synthProxy, address account) external view returns (uint balanceOfInsUSD);

    // Full sUSD supply of token
    function totalSupply(IERC20 synthProxy) external view returns (uint totalSupplyInsUSD);

    function redeem(IERC20 synthProxy) external;

    function redeemAll(IERC20[] calldata synthProxies) external;

    function redeemPartial(IERC20 synthProxy, uint amountOfSynth) external;

    // Restricted to Issuer
    function deprecate(IERC20 synthProxy, uint rateToRedeem) external;
}


// Inheritance


// Libraries


// Internal references


interface IProxy {
    function target() external view returns (address);
}

interface IIssuerInternalDebtCache {
    function updateCachedSynthDebtWithRate(bytes32 currencyKey, uint currencyRate) external;

    function updateCachedSynthDebtsWithRates(bytes32[] calldata currencyKeys, uint[] calldata currencyRates) external;

    function updateDebtCacheValidity(bool currentlyInvalid) external;

    function totalNonSnxBackedDebt() external view returns (uint excludedDebt, bool isInvalid);

    function cacheInfo()
        external
        view
        returns (
            uint cachedDebt,
            uint timestamp,
            bool isInvalid,
            bool isStale
        );

    function updateCachedsUSDDebt(int amount) external;
}

// https://docs.synthetix.io/contracts/source/contracts/issuer
contract Issuer is Owned, MixinSystemSettings, IIssuer {
    using SafeMath for uint;
    using SafeDecimalMath for uint;

    bytes32 public constant CONTRACT_NAME = "Issuer";

    // Available Synths which can be used with the system
    ISynth[] public availableSynths;
    mapping(bytes32 => ISynth) public synths;
    mapping(address => bytes32) public synthsByAddress;

    /* ========== ENCODED NAMES ========== */

    bytes32 internal constant sUSD = "sUSD";
    bytes32 internal constant SNX = "SNX";

    // Flexible storage names

    bytes32 internal constant LAST_ISSUE_EVENT = "lastIssueEvent";

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */

    bytes32 private constant CONTRACT_SYNTHETIX = "Synthetix";
    bytes32 private constant CONTRACT_EXCHANGER = "Exchanger";
    bytes32 private constant CONTRACT_EXRATES = "ExchangeRates";
    bytes32 private constant CONTRACT_CIRCUIT_BREAKER = "CircuitBreaker";
    bytes32 private constant CONTRACT_SYNTHETIXDEBTSHARE = "SynthetixDebtShare";
    bytes32 private constant CONTRACT_FEEPOOL = "FeePool";
    bytes32 private constant CONTRACT_DELEGATEAPPROVALS = "DelegateApprovals";
    bytes32 private constant CONTRACT_REWARDESCROW_V2 = "RewardEscrowV2";
    bytes32 private constant CONTRACT_SYNTHETIXESCROW = "SynthetixEscrow";
    bytes32 private constant CONTRACT_LIQUIDATOR = "Liquidator";
    bytes32 private constant CONTRACT_LIQUIDATOR_REWARDS = "LiquidatorRewards";
    bytes32 private constant CONTRACT_DEBTCACHE = "DebtCache";
    bytes32 private constant CONTRACT_SYNTHREDEEMER = "SynthRedeemer";
    bytes32 private constant CONTRACT_SYNTHETIXBRIDGETOOPTIMISM = "SynthetixBridgeToOptimism";
    bytes32 private constant CONTRACT_SYNTHETIXBRIDGETOBASE = "SynthetixBridgeToBase";

    bytes32 private constant CONTRACT_EXT_AGGREGATOR_ISSUED_SYNTHS = "ext:AggregatorIssuedSynths";
    bytes32 private constant CONTRACT_EXT_AGGREGATOR_DEBT_RATIO = "ext:AggregatorDebtRatio";

    constructor(address _owner, address _resolver) public Owned(_owner) MixinSystemSettings(_resolver) {}

    /* ========== VIEWS ========== */
    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](15);
        newAddresses[0] = CONTRACT_SYNTHETIX;
        newAddresses[1] = CONTRACT_EXCHANGER;
        newAddresses[2] = CONTRACT_EXRATES;
        newAddresses[3] = CONTRACT_CIRCUIT_BREAKER;
        newAddresses[4] = CONTRACT_SYNTHETIXDEBTSHARE;
        newAddresses[5] = CONTRACT_FEEPOOL;
        newAddresses[6] = CONTRACT_DELEGATEAPPROVALS;
        newAddresses[7] = CONTRACT_REWARDESCROW_V2;
        newAddresses[8] = CONTRACT_SYNTHETIXESCROW;
        newAddresses[9] = CONTRACT_LIQUIDATOR;
        newAddresses[10] = CONTRACT_LIQUIDATOR_REWARDS;
        newAddresses[11] = CONTRACT_DEBTCACHE;
        newAddresses[12] = CONTRACT_SYNTHREDEEMER;
        newAddresses[13] = CONTRACT_EXT_AGGREGATOR_ISSUED_SYNTHS;
        newAddresses[14] = CONTRACT_EXT_AGGREGATOR_DEBT_RATIO;
        return combineArrays(existingAddresses, newAddresses);
    }

    function synthetix() internal view returns (ISynthetix) {
        return ISynthetix(requireAndGetAddress(CONTRACT_SYNTHETIX));
    }

    function exchanger() internal view returns (IExchanger) {
        return IExchanger(requireAndGetAddress(CONTRACT_EXCHANGER));
    }

    function exchangeRates() internal view returns (IExchangeRates) {
        return IExchangeRates(requireAndGetAddress(CONTRACT_EXRATES));
    }

    function circuitBreaker() internal view returns (ICircuitBreaker) {
        return ICircuitBreaker(requireAndGetAddress(CONTRACT_CIRCUIT_BREAKER));
    }

    function synthetixDebtShare() internal view returns (ISynthetixDebtShare) {
        return ISynthetixDebtShare(requireAndGetAddress(CONTRACT_SYNTHETIXDEBTSHARE));
    }

    function feePool() internal view returns (IFeePool) {
        return IFeePool(requireAndGetAddress(CONTRACT_FEEPOOL));
    }

    function liquidator() internal view returns (ILiquidator) {
        return ILiquidator(requireAndGetAddress(CONTRACT_LIQUIDATOR));
    }

    function liquidatorRewards() internal view returns (ILiquidatorRewards) {
        return ILiquidatorRewards(requireAndGetAddress(CONTRACT_LIQUIDATOR_REWARDS));
    }

    function delegateApprovals() internal view returns (IDelegateApprovals) {
        return IDelegateApprovals(requireAndGetAddress(CONTRACT_DELEGATEAPPROVALS));
    }

    function rewardEscrowV2() internal view returns (IRewardEscrowV2) {
        return IRewardEscrowV2(requireAndGetAddress(CONTRACT_REWARDESCROW_V2));
    }

    function synthetixEscrow() internal view returns (IHasBalance) {
        return IHasBalance(requireAndGetAddress(CONTRACT_SYNTHETIXESCROW));
    }

    function debtCache() internal view returns (IIssuerInternalDebtCache) {
        return IIssuerInternalDebtCache(requireAndGetAddress(CONTRACT_DEBTCACHE));
    }

    function synthRedeemer() internal view returns (ISynthRedeemer) {
        return ISynthRedeemer(requireAndGetAddress(CONTRACT_SYNTHREDEEMER));
    }

    function allNetworksDebtInfo()
        public
        view
        returns (
            uint256 debt,
            uint256 sharesSupply,
            bool isStale
        )
    {
        (, int256 rawIssuedSynths, , uint issuedSynthsUpdatedAt, ) =
            AggregatorV2V3Interface(requireAndGetAddress(CONTRACT_EXT_AGGREGATOR_ISSUED_SYNTHS)).latestRoundData();

        (, int256 rawRatio, , uint ratioUpdatedAt, ) =
            AggregatorV2V3Interface(requireAndGetAddress(CONTRACT_EXT_AGGREGATOR_DEBT_RATIO)).latestRoundData();

        debt = uint(rawIssuedSynths);
        sharesSupply = rawRatio == 0 ? 0 : debt.divideDecimalRoundPrecise(uint(rawRatio));

        uint stalePeriod = getRateStalePeriod();

        isStale =
            stalePeriod < block.timestamp &&
            (block.timestamp - getRateStalePeriod() > issuedSynthsUpdatedAt ||
                block.timestamp - getRateStalePeriod() > ratioUpdatedAt);
    }

    function issuanceRatio() external view returns (uint) {
        return getIssuanceRatio();
    }

    function _sharesForDebt(uint debtAmount) internal view returns (uint) {
        (, int256 rawRatio, , , ) =
            AggregatorV2V3Interface(requireAndGetAddress(CONTRACT_EXT_AGGREGATOR_DEBT_RATIO)).latestRoundData();

        return rawRatio == 0 ? 0 : debtAmount.divideDecimalRoundPrecise(uint(rawRatio));
    }

    function _debtForShares(uint sharesAmount) internal view returns (uint) {
        (, int256 rawRatio, , , ) =
            AggregatorV2V3Interface(requireAndGetAddress(CONTRACT_EXT_AGGREGATOR_DEBT_RATIO)).latestRoundData();

        return sharesAmount.multiplyDecimalRoundPrecise(uint(rawRatio));
    }

    function _availableCurrencyKeysWithOptionalSNX(bool withSNX) internal view returns (bytes32[] memory) {
        bytes32[] memory currencyKeys = new bytes32[](availableSynths.length + (withSNX ? 1 : 0));

        for (uint i = 0; i < availableSynths.length; i++) {
            currencyKeys[i] = synthsByAddress[address(availableSynths[i])];
        }

        if (withSNX) {
            currencyKeys[availableSynths.length] = SNX;
        }

        return currencyKeys;
    }

    // Returns the total value of the debt pool in currency specified by `currencyKey`.
    // To return only the SNX-backed debt, set `excludeCollateral` to true.
    function _totalIssuedSynths(bytes32 currencyKey, bool excludeCollateral)
        internal
        view
        returns (uint totalIssued, bool anyRateIsInvalid)
    {
        (uint debt, , bool cacheIsInvalid, bool cacheIsStale) = debtCache().cacheInfo();
        anyRateIsInvalid = cacheIsInvalid || cacheIsStale;

        IExchangeRates exRates = exchangeRates();

        // Add total issued synths from non snx collateral back into the total if not excluded
        if (!excludeCollateral) {
            (uint nonSnxDebt, bool invalid) = debtCache().totalNonSnxBackedDebt();
            debt = debt.add(nonSnxDebt);
            anyRateIsInvalid = anyRateIsInvalid || invalid;
        }

        if (currencyKey == sUSD) {
            return (debt, anyRateIsInvalid);
        }

        (uint currencyRate, bool currencyRateInvalid) = exRates.rateAndInvalid(currencyKey);
        return (debt.divideDecimalRound(currencyRate), anyRateIsInvalid || currencyRateInvalid);
    }

    function _debtBalanceOfAndTotalDebt(uint debtShareBalance, bytes32 currencyKey)
        internal
        view
        returns (
            uint debtBalance,
            uint totalSystemValue,
            bool anyRateIsInvalid
        )
    {
        // What's the total value of the system excluding ETH backed synths in their requested currency?
        (uint snxBackedAmount, , bool debtInfoStale) = allNetworksDebtInfo();

        if (debtShareBalance == 0) {
            return (0, snxBackedAmount, debtInfoStale);
        }

        // existing functionality requires for us to convert into the exchange rate specified by `currencyKey`
        (uint currencyRate, bool currencyRateInvalid) = exchangeRates().rateAndInvalid(currencyKey);

        debtBalance = _debtForShares(debtShareBalance).divideDecimalRound(currencyRate);
        totalSystemValue = snxBackedAmount;

        anyRateIsInvalid = currencyRateInvalid || debtInfoStale;
    }

    function _canBurnSynths(address account) internal view returns (bool) {
        return now >= _lastIssueEvent(account).add(getMinimumStakeTime());
    }

    function _lastIssueEvent(address account) internal view returns (uint) {
        //  Get the timestamp of the last issue this account made
        return flexibleStorage().getUIntValue(CONTRACT_NAME, keccak256(abi.encodePacked(LAST_ISSUE_EVENT, account)));
    }

    function _remainingIssuableSynths(address _issuer)
        internal
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt,
            bool anyRateIsInvalid
        )
    {
        (alreadyIssued, totalSystemDebt, anyRateIsInvalid) = _debtBalanceOfAndTotalDebt(
            synthetixDebtShare().balanceOf(_issuer),
            sUSD
        );
        (uint issuable, bool isInvalid) = _maxIssuableSynths(_issuer);
        maxIssuable = issuable;
        anyRateIsInvalid = anyRateIsInvalid || isInvalid;

        if (alreadyIssued >= maxIssuable) {
            maxIssuable = 0;
        } else {
            maxIssuable = maxIssuable.sub(alreadyIssued);
        }
    }

    function _snxToUSD(uint amount, uint snxRate) internal pure returns (uint) {
        return amount.multiplyDecimalRound(snxRate);
    }

    function _usdToSnx(uint amount, uint snxRate) internal pure returns (uint) {
        return amount.divideDecimalRound(snxRate);
    }

    function _maxIssuableSynths(address _issuer) internal view returns (uint, bool) {
        // What is the value of their SNX balance in sUSD
        (uint snxRate, bool isInvalid) = exchangeRates().rateAndInvalid(SNX);
        uint destinationValue = _snxToUSD(_collateral(_issuer), snxRate);

        // They're allowed to issue up to issuanceRatio of that value
        return (destinationValue.multiplyDecimal(getIssuanceRatio()), isInvalid);
    }

    function _collateralisationRatio(address _issuer) internal view returns (uint, bool) {
        uint totalOwnedSynthetix = _collateral(_issuer);

        (uint debtBalance, , bool anyRateIsInvalid) =
            _debtBalanceOfAndTotalDebt(synthetixDebtShare().balanceOf(_issuer), SNX);

        // it's more gas intensive to put this check here if they have 0 SNX, but it complies with the interface
        if (totalOwnedSynthetix == 0) return (0, anyRateIsInvalid);

        return (debtBalance.divideDecimalRound(totalOwnedSynthetix), anyRateIsInvalid);
    }

    function _collateral(address account) internal view returns (uint) {
        uint balance = IERC20(address(synthetix())).balanceOf(account);

        if (address(synthetixEscrow()) != address(0)) {
            balance = balance.add(synthetixEscrow().balanceOf(account));
        }

        if (address(rewardEscrowV2()) != address(0)) {
            balance = balance.add(rewardEscrowV2().balanceOf(account));
        }

        if (address(liquidatorRewards()) != address(0)) {
            balance = balance.add(liquidatorRewards().earned(account));
        }

        return balance;
    }

    function minimumStakeTime() external view returns (uint) {
        return getMinimumStakeTime();
    }

    function canBurnSynths(address account) external view returns (bool) {
        return _canBurnSynths(account);
    }

    function availableCurrencyKeys() external view returns (bytes32[] memory) {
        return _availableCurrencyKeysWithOptionalSNX(false);
    }

    function availableSynthCount() external view returns (uint) {
        return availableSynths.length;
    }

    function anySynthOrSNXRateIsInvalid() external view returns (bool anyRateInvalid) {
        (, anyRateInvalid) = exchangeRates().ratesAndInvalidForCurrencies(_availableCurrencyKeysWithOptionalSNX(true));
    }

    function totalIssuedSynths(bytes32 currencyKey, bool excludeOtherCollateral) external view returns (uint totalIssued) {
        (totalIssued, ) = _totalIssuedSynths(currencyKey, excludeOtherCollateral);
    }

    function lastIssueEvent(address account) external view returns (uint) {
        return _lastIssueEvent(account);
    }

    function collateralisationRatio(address _issuer) external view returns (uint cratio) {
        (cratio, ) = _collateralisationRatio(_issuer);
    }

    function collateralisationRatioAndAnyRatesInvalid(address _issuer)
        external
        view
        returns (uint cratio, bool anyRateIsInvalid)
    {
        return _collateralisationRatio(_issuer);
    }

    function collateral(address account) external view returns (uint) {
        return _collateral(account);
    }

    function debtBalanceOf(address _issuer, bytes32 currencyKey) external view returns (uint debtBalance) {
        ISynthetixDebtShare sds = synthetixDebtShare();

        // What was their initial debt ownership?
        uint debtShareBalance = sds.balanceOf(_issuer);

        // If it's zero, they haven't issued, and they have no debt.
        if (debtShareBalance == 0) return 0;

        (debtBalance, , ) = _debtBalanceOfAndTotalDebt(debtShareBalance, currencyKey);
    }

    function remainingIssuableSynths(address _issuer)
        external
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt
        )
    {
        (maxIssuable, alreadyIssued, totalSystemDebt, ) = _remainingIssuableSynths(_issuer);
    }

    function maxIssuableSynths(address _issuer) external view returns (uint) {
        (uint maxIssuable, ) = _maxIssuableSynths(_issuer);
        return maxIssuable;
    }

    function transferableSynthetixAndAnyRateIsInvalid(address account, uint balance)
        external
        view
        returns (uint transferable, bool anyRateIsInvalid)
    {
        // How many SNX do they have, excluding escrow?
        // Note: We're excluding escrow here because we're interested in their transferable amount
        // and escrowed SNX are not transferable.

        // How many of those will be locked by the amount they've issued?
        // Assuming issuance ratio is 20%, then issuing 20 SNX of value would require
        // 100 SNX to be locked in their wallet to maintain their collateralisation ratio
        // The locked synthetix value can exceed their balance.
        uint debtBalance;
        (debtBalance, , anyRateIsInvalid) = _debtBalanceOfAndTotalDebt(synthetixDebtShare().balanceOf(account), SNX);
        uint lockedSynthetixValue = debtBalance.divideDecimalRound(getIssuanceRatio());

        // If we exceed the balance, no SNX are transferable, otherwise the difference is.
        if (lockedSynthetixValue >= balance) {
            transferable = 0;
        } else {
            transferable = balance.sub(lockedSynthetixValue);
        }
    }

    function getSynths(bytes32[] calldata currencyKeys) external view returns (ISynth[] memory) {
        uint numKeys = currencyKeys.length;
        ISynth[] memory addresses = new ISynth[](numKeys);

        for (uint i = 0; i < numKeys; i++) {
            addresses[i] = synths[currencyKeys[i]];
        }

        return addresses;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _addSynth(ISynth synth) internal {
        bytes32 currencyKey = synth.currencyKey();
        require(synths[currencyKey] == ISynth(0), "Synth exists");
        require(synthsByAddress[address(synth)] == bytes32(0), "Synth address already exists");

        availableSynths.push(synth);
        synths[currencyKey] = synth;
        synthsByAddress[address(synth)] = currencyKey;

        emit SynthAdded(currencyKey, address(synth));
    }

    function addSynth(ISynth synth) external onlyOwner {
        _addSynth(synth);
        // Invalidate the cache to force a snapshot to be recomputed. If a synth were to be added
        // back to the system and it still somehow had cached debt, this would force the value to be
        // updated.
        debtCache().updateDebtCacheValidity(true);
    }

    function addSynths(ISynth[] calldata synthsToAdd) external onlyOwner {
        uint numSynths = synthsToAdd.length;
        for (uint i = 0; i < numSynths; i++) {
            _addSynth(synthsToAdd[i]);
        }

        // Invalidate the cache to force a snapshot to be recomputed.
        debtCache().updateDebtCacheValidity(true);
    }

    function _removeSynth(bytes32 currencyKey) internal {
        address synthToRemove = address(synths[currencyKey]);
        require(synthToRemove != address(0), "Synth does not exist");
        require(currencyKey != sUSD, "Cannot remove synth");

        uint synthSupply = IERC20(synthToRemove).totalSupply();

        if (synthSupply > 0) {
            (uint amountOfsUSD, uint rateToRedeem, ) =
                exchangeRates().effectiveValueAndRates(currencyKey, synthSupply, "sUSD");
            require(rateToRedeem > 0, "Cannot remove synth to redeem without rate");
            ISynthRedeemer _synthRedeemer = synthRedeemer();
            synths[sUSD].issue(address(_synthRedeemer), amountOfsUSD);
            // ensure the debt cache is aware of the new sUSD issued
            debtCache().updateCachedsUSDDebt(SafeCast.toInt256(amountOfsUSD));
            _synthRedeemer.deprecate(IERC20(address(Proxyable(address(synthToRemove)).proxy())), rateToRedeem);
        }

        // Remove the synth from the availableSynths array.
        for (uint i = 0; i < availableSynths.length; i++) {
            if (address(availableSynths[i]) == synthToRemove) {
                delete availableSynths[i];

                // Copy the last synth into the place of the one we just deleted
                // If there's only one synth, this is synths[0] = synths[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                availableSynths[i] = availableSynths[availableSynths.length - 1];

                // Decrease the size of the array by one.
                availableSynths.length--;

                break;
            }
        }

        // And remove it from the synths mapping
        delete synthsByAddress[synthToRemove];
        delete synths[currencyKey];

        emit SynthRemoved(currencyKey, synthToRemove);
    }

    function removeSynth(bytes32 currencyKey) external onlyOwner {
        // Remove its contribution from the debt pool snapshot, and
        // invalidate the cache to force a new snapshot.
        IIssuerInternalDebtCache cache = debtCache();
        cache.updateCachedSynthDebtWithRate(currencyKey, 0);
        cache.updateDebtCacheValidity(true);

        _removeSynth(currencyKey);
    }

    function removeSynths(bytes32[] calldata currencyKeys) external onlyOwner {
        uint numKeys = currencyKeys.length;

        // Remove their contributions from the debt pool snapshot, and
        // invalidate the cache to force a new snapshot.
        IIssuerInternalDebtCache cache = debtCache();
        uint[] memory zeroRates = new uint[](numKeys);
        cache.updateCachedSynthDebtsWithRates(currencyKeys, zeroRates);
        cache.updateDebtCacheValidity(true);

        for (uint i = 0; i < numKeys; i++) {
            _removeSynth(currencyKeys[i]);
        }
    }

    function issueSynthsWithoutDebt(
        bytes32 currencyKey,
        address to,
        uint amount
    ) external onlyTrustedMinters returns (bool rateInvalid) {
        require(address(synths[currencyKey]) != address(0), "Issuer: synth doesn't exist");
        require(amount > 0, "Issuer: cannot issue 0 synths");

        // record issue timestamp
        _setLastIssueEvent(to);

        // Create their synths
        synths[currencyKey].issue(to, amount);

        // Account for the issued debt in the cache
        (uint rate, bool rateInvalid) = exchangeRates().rateAndInvalid(currencyKey);
        debtCache().updateCachedsUSDDebt(SafeCast.toInt256(amount.multiplyDecimal(rate)));

        // returned so that the caller can decide what to do if the rate is invalid
        return rateInvalid;
    }

    function burnSynthsWithoutDebt(
        bytes32 currencyKey,
        address from,
        uint amount
    ) external onlyTrustedMinters returns (bool rateInvalid) {
        require(address(synths[currencyKey]) != address(0), "Issuer: synth doesn't exist");
        require(amount > 0, "Issuer: cannot issue 0 synths");

        exchanger().settle(from, currencyKey);

        // Burn some synths
        synths[currencyKey].burn(from, amount);

        // Account for the burnt debt in the cache. If rate is invalid, the user won't be able to exchange
        (uint rate, bool rateInvalid) = exchangeRates().rateAndInvalid(currencyKey);
        debtCache().updateCachedsUSDDebt(-SafeCast.toInt256(amount.multiplyDecimal(rate)));

        // returned so that the caller can decide what to do if the rate is invalid
        return rateInvalid;
    }

    /**
     * Function used to migrate balances from the CollateralShort contract
     * @param short The address of the CollateralShort contract to be upgraded
     * @param amount The amount of sUSD collateral to be burnt
     */
    function upgradeCollateralShort(address short, uint amount) external onlyOwner {
        require(short != address(0), "Issuer: invalid address");
        require(short == resolver.getAddress("CollateralShortLegacy"), "Issuer: wrong short address");
        require(address(synths[sUSD]) != address(0), "Issuer: synth doesn't exist");
        require(amount > 0, "Issuer: cannot burn 0 synths");

        exchanger().settle(short, sUSD);

        synths[sUSD].burn(short, amount);
    }

    function issueSynths(address from, uint amount) external onlySynthetix {
        require(amount > 0, "Issuer: cannot issue 0 synths");

        _issueSynths(from, amount, false);
    }

    function issueMaxSynths(address from) external onlySynthetix {
        _issueSynths(from, 0, true);
    }

    function issueSynthsOnBehalf(
        address issueForAddress,
        address from,
        uint amount
    ) external onlySynthetix {
        _requireCanIssueOnBehalf(issueForAddress, from);
        _issueSynths(issueForAddress, amount, false);
    }

    function issueMaxSynthsOnBehalf(address issueForAddress, address from) external onlySynthetix {
        _requireCanIssueOnBehalf(issueForAddress, from);
        _issueSynths(issueForAddress, 0, true);
    }

    function burnSynths(address from, uint amount) external onlySynthetix {
        _voluntaryBurnSynths(from, amount, false);
    }

    function burnSynthsOnBehalf(
        address burnForAddress,
        address from,
        uint amount
    ) external onlySynthetix {
        _requireCanBurnOnBehalf(burnForAddress, from);
        _voluntaryBurnSynths(burnForAddress, amount, false);
    }

    function burnSynthsToTarget(address from) external onlySynthetix {
        _voluntaryBurnSynths(from, 0, true);
    }

    function burnSynthsToTargetOnBehalf(address burnForAddress, address from) external onlySynthetix {
        _requireCanBurnOnBehalf(burnForAddress, from);
        _voluntaryBurnSynths(burnForAddress, 0, true);
    }

    function burnForRedemption(
        address deprecatedSynthProxy,
        address account,
        uint balance
    ) external onlySynthRedeemer {
        ISynth(IProxy(deprecatedSynthProxy).target()).burn(account, balance);
    }

    // SIP-148: Upgraded Liquidation Mechanism
    /// @notice This is where the core internal liquidation logic resides. This function can only be invoked by Synthetix.
    /// @param account The account to be liquidated
    /// @param isSelfLiquidation boolean to determine if this is a forced or self-invoked liquidation
    /// @return uint the total amount of collateral (SNX) to redeem
    /// @return uint the amount of debt (sUSD) to burn in order to fix the account's c-ratio
    function liquidateAccount(address account, bool isSelfLiquidation)
        external
        onlySynthetix
        returns (uint totalRedeemed, uint amountToLiquidate)
    {
        require(liquidator().isLiquidationOpen(account, isSelfLiquidation), "Not open for liquidation");

        // Get the penalty for the liquidation type
        uint penalty = isSelfLiquidation ? getSelfLiquidationPenalty() : getSnxLiquidationPenalty();

        // Get the account's debt balance
        (uint debtBalance, , bool anyRateIsInvalid) =
            _debtBalanceOfAndTotalDebt(synthetixDebtShare().balanceOf(account), sUSD);

        // Get the SNX rate
        (uint snxRate, bool snxRateInvalid) = exchangeRates().rateAndInvalid(SNX);
        _requireRatesNotInvalid(anyRateIsInvalid || snxRateInvalid);

        // Get the total amount of SNX collateral (including escrows and rewards)
        uint collateralForAccount = _collateral(account);

        // Calculate the amount of debt to liquidate to fix c-ratio
        amountToLiquidate = liquidator().calculateAmountToFixCollateral(
            debtBalance,
            _snxToUSD(collateralForAccount, snxRate),
            penalty
        );

        // Get the equivalent amount of SNX for the amount to liquidate
        // Note: While amountToLiquidate takes the penalty into account, it does not accommodate for the addition of the penalty in terms of SNX.
        // Therefore, it is correct to add the penalty modification below to the totalRedeemed.
        totalRedeemed = _usdToSnx(amountToLiquidate, snxRate).multiplyDecimal(SafeDecimalMath.unit().add(penalty));

        // The balanceOf here can be considered "transferable" since it's not escrowed,
        // and it is the only SNX that can potentially be transfered if unstaked.
        uint transferableBalance = IERC20(address(synthetix())).balanceOf(account);
        if (totalRedeemed > transferableBalance) {
            // Liquidate the account's debt based on the liquidation penalty.
            amountToLiquidate = amountToLiquidate.multiplyDecimal(transferableBalance).divideDecimal(totalRedeemed);

            // Set totalRedeemed to all transferable collateral.
            // i.e. the value of the account's staking position relative to balanceOf will be unwound.
            totalRedeemed = transferableBalance;
        }

        // Reduce debt shares by amount to liquidate.
        _removeFromDebtRegister(account, amountToLiquidate, debtBalance);

        // Remove liquidation flag
        liquidator().removeAccountInLiquidation(account);
    }

    function setCurrentPeriodId(uint128 periodId) external {
        require(msg.sender == address(feePool()), "Must be fee pool");

        ISynthetixDebtShare sds = synthetixDebtShare();

        if (sds.currentPeriodId() < periodId) {
            sds.takeSnapshot(periodId);
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _requireRatesNotInvalid(bool anyRateIsInvalid) internal pure {
        require(!anyRateIsInvalid, "A synth or SNX rate is invalid");
    }

    function _requireCanIssueOnBehalf(address issueForAddress, address from) internal view {
        require(delegateApprovals().canIssueFor(issueForAddress, from), "Not approved to act on behalf");
    }

    function _requireCanBurnOnBehalf(address burnForAddress, address from) internal view {
        require(delegateApprovals().canBurnFor(burnForAddress, from), "Not approved to act on behalf");
    }

    function _issueSynths(
        address from,
        uint amount,
        bool issueMax
    ) internal {
        if (_verifyCircuitBreakers()) {
            return;
        }

        (uint maxIssuable, , , bool anyRateIsInvalid) = _remainingIssuableSynths(from);
        _requireRatesNotInvalid(anyRateIsInvalid);

        if (!issueMax) {
            require(amount <= maxIssuable, "Amount too large");
        } else {
            amount = maxIssuable;
        }

        // Keep track of the debt they're about to create
        _addToDebtRegister(from, amount);

        // record issue timestamp
        _setLastIssueEvent(from);

        // Create their synths
        synths[sUSD].issue(from, amount);

        // Account for the issued debt in the cache
        debtCache().updateCachedsUSDDebt(SafeCast.toInt256(amount));
    }

    function _burnSynths(
        address debtAccount,
        address burnAccount,
        uint amount,
        uint existingDebt
    ) internal returns (uint amountBurnt) {
        if (_verifyCircuitBreakers()) {
            return 0;
        }

        // liquidation requires sUSD to be already settled / not in waiting period

        // If they're trying to burn more debt than they actually owe, rather than fail the transaction, let's just
        // clear their debt and leave them be.
        amountBurnt = existingDebt < amount ? existingDebt : amount;

        // Remove liquidated debt from the ledger
        _removeFromDebtRegister(debtAccount, amountBurnt, existingDebt);

        // synth.burn does a safe subtraction on balance (so it will revert if there are not enough synths).
        synths[sUSD].burn(burnAccount, amountBurnt);

        // Account for the burnt debt in the cache.
        debtCache().updateCachedsUSDDebt(-SafeCast.toInt256(amountBurnt));
    }

    // If burning to target, `amount` is ignored, and the correct quantity of sUSD is burnt to reach the target
    // c-ratio, allowing fees to be claimed. In this case, pending settlements will be skipped as the user
    // will still have debt remaining after reaching their target.
    function _voluntaryBurnSynths(
        address from,
        uint amount,
        bool burnToTarget
    ) internal {
        if (_verifyCircuitBreakers()) {
            return;
        }

        if (!burnToTarget) {
            // If not burning to target, then burning requires that the minimum stake time has elapsed.
            require(_canBurnSynths(from), "Minimum stake time not reached");
            // First settle anything pending into sUSD as burning or issuing impacts the size of the debt pool
            (, uint refunded, uint numEntriesSettled) = exchanger().settle(from, sUSD);
            if (numEntriesSettled > 0) {
                amount = exchanger().calculateAmountAfterSettlement(from, sUSD, amount, refunded);
            }
        }

        (uint existingDebt, , bool anyRateIsInvalid) =
            _debtBalanceOfAndTotalDebt(synthetixDebtShare().balanceOf(from), sUSD);
        (uint maxIssuableSynthsForAccount, bool snxRateInvalid) = _maxIssuableSynths(from);
        _requireRatesNotInvalid(anyRateIsInvalid || snxRateInvalid);
        require(existingDebt > 0, "No debt to forgive");

        if (burnToTarget) {
            amount = existingDebt.sub(maxIssuableSynthsForAccount);
        }

        uint amountBurnt = _burnSynths(from, from, amount, existingDebt);

        // Check and remove liquidation if existingDebt after burning is <= maxIssuableSynths
        // Issuance ratio is fixed so should remove any liquidations
        if (existingDebt.sub(amountBurnt) <= maxIssuableSynthsForAccount) {
            liquidator().removeAccountInLiquidation(from);
        }
    }

    function _setLastIssueEvent(address account) internal {
        // Set the timestamp of the last issueSynths
        flexibleStorage().setUIntValue(
            CONTRACT_NAME,
            keccak256(abi.encodePacked(LAST_ISSUE_EVENT, account)),
            block.timestamp
        );
    }

    function _addToDebtRegister(address from, uint amount) internal {
        // important: this has to happen before any updates to user's debt shares
        liquidatorRewards().updateEntry(from);

        ISynthetixDebtShare sds = synthetixDebtShare();

        // it is possible (eg in tests, system initialized with extra debt) to have issued debt without any shares issued
        // in which case, the first account to mint gets the debt. yw.
        uint debtShares = _sharesForDebt(amount);
        if (debtShares == 0) {
            sds.mintShare(from, amount);
        } else {
            sds.mintShare(from, debtShares);
        }
    }

    function _removeFromDebtRegister(
        address from,
        uint debtToRemove,
        uint existingDebt
    ) internal {
        // important: this has to happen before any updates to user's debt shares
        liquidatorRewards().updateEntry(from);

        ISynthetixDebtShare sds = synthetixDebtShare();

        uint currentDebtShare = sds.balanceOf(from);

        if (debtToRemove == existingDebt) {
            sds.burnShare(from, currentDebtShare);
        } else {
            uint sharesToRemove = _sharesForDebt(debtToRemove);
            sds.burnShare(from, sharesToRemove < currentDebtShare ? sharesToRemove : currentDebtShare);
        }
    }

    // trips the breaker and returns boolean, where true means the breaker has tripped state
    function _verifyCircuitBreakers() internal returns (bool) {
        address debtRatioAggregator = requireAndGetAddress(CONTRACT_EXT_AGGREGATOR_DEBT_RATIO);
        (, int256 rawRatio, , , ) = AggregatorV2V3Interface(debtRatioAggregator).latestRoundData();
        (, bool broken, ) = exchangeRates().rateWithSafetyChecks(SNX);

        return circuitBreaker().probeCircuitBreaker(debtRatioAggregator, uint(rawRatio)) || broken;
    }

    /* ========== MODIFIERS ========== */
    modifier onlySynthetix() {
        require(msg.sender == address(synthetix()), "Issuer: Only the synthetix contract can perform this action");
        _;
    }

    modifier onlyTrustedMinters() {
        address bridgeL1 = resolver.getAddress(CONTRACT_SYNTHETIXBRIDGETOOPTIMISM);
        address bridgeL2 = resolver.getAddress(CONTRACT_SYNTHETIXBRIDGETOBASE);
        require(msg.sender == bridgeL1 || msg.sender == bridgeL2, "Issuer: only trusted minters");
        require(bridgeL1 == address(0) || bridgeL2 == address(0), "Issuer: one minter must be 0x0");
        _;
    }

    function _onlySynthRedeemer() internal view {
        require(msg.sender == address(synthRedeemer()), "Issuer: Only the SynthRedeemer contract can perform this action");
    }

    modifier onlySynthRedeemer() {
        _onlySynthRedeemer();
        _;
    }

    /* ========== EVENTS ========== */

    event SynthAdded(bytes32 currencyKey, address synth);
    event SynthRemoved(bytes32 currencyKey, address synth);
}


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/MixinFuturesMarketSettings
contract MixinFuturesMarketSettings is MixinResolver {
    /* ========== CONSTANTS ========== */

    bytes32 internal constant SETTING_CONTRACT_NAME = "FuturesMarketSettings";

    /* ---------- Parameter Names ---------- */

    // Per-market settings
    bytes32 internal constant PARAMETER_TAKER_FEE = "takerFee";
    bytes32 internal constant PARAMETER_MAKER_FEE = "makerFee";
    bytes32 internal constant PARAMETER_TAKER_FEE_NEXT_PRICE = "takerFeeNextPrice";
    bytes32 internal constant PARAMETER_MAKER_FEE_NEXT_PRICE = "makerFeeNextPrice";
    bytes32 internal constant PARAMETER_NEXT_PRICE_CONFIRM_WINDOW = "nextPriceConfirmWindow";
    bytes32 internal constant PARAMETER_MAX_LEVERAGE = "maxLeverage";
    bytes32 internal constant PARAMETER_MAX_MARKET_VALUE = "maxMarketValueUSD";
    bytes32 internal constant PARAMETER_MAX_FUNDING_RATE = "maxFundingRate";
    bytes32 internal constant PARAMETER_MIN_SKEW_SCALE = "skewScaleUSD";

    // Global settings
    // minimum liquidation fee payable to liquidator
    bytes32 internal constant SETTING_MIN_KEEPER_FEE = "futuresMinKeeperFee";
    // liquidation fee basis points payed to liquidator
    bytes32 internal constant SETTING_LIQUIDATION_FEE_RATIO = "futuresLiquidationFeeRatio";
    // liquidation buffer to prevent negative margin upon liquidation
    bytes32 internal constant SETTING_LIQUIDATION_BUFFER_RATIO = "futuresLiquidationBufferRatio";
    bytes32 internal constant SETTING_MIN_INITIAL_MARGIN = "futuresMinInitialMargin";

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

    function _takerFeeNextPrice(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_TAKER_FEE_NEXT_PRICE);
    }

    function _makerFeeNextPrice(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAKER_FEE_NEXT_PRICE);
    }

    function _nextPriceConfirmWindow(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_NEXT_PRICE_CONFIRM_WINDOW);
    }

    function _maxLeverage(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_LEVERAGE);
    }

    function _maxMarketValueUSD(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_MARKET_VALUE);
    }

    function _skewScaleUSD(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MIN_SKEW_SCALE);
    }

    function _maxFundingRate(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_FUNDING_RATE);
    }

    function _minKeeperFee() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_KEEPER_FEE);
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


interface IFuturesMarketSettings {
    struct Parameters {
        uint takerFee;
        uint makerFee;
        uint takerFeeNextPrice;
        uint makerFeeNextPrice;
        uint nextPriceConfirmWindow;
        uint maxLeverage;
        uint maxMarketValueUSD;
        uint maxFundingRate;
        uint skewScaleUSD;
    }

    function takerFee(bytes32 _marketKey) external view returns (uint);

    function makerFee(bytes32 _marketKey) external view returns (uint);

    function takerFeeNextPrice(bytes32 _marketKey) external view returns (uint);

    function makerFeeNextPrice(bytes32 _marketKey) external view returns (uint);

    function nextPriceConfirmWindow(bytes32 _marketKey) external view returns (uint);

    function maxLeverage(bytes32 _marketKey) external view returns (uint);

    function maxMarketValueUSD(bytes32 _marketKey) external view returns (uint);

    function maxFundingRate(bytes32 _marketKey) external view returns (uint);

    function skewScaleUSD(bytes32 _marketKey) external view returns (uint);

    function parameters(bytes32 _marketKey)
        external
        view
        returns (
            uint _takerFee,
            uint _makerFee,
            uint _takerFeeNextPrice,
            uint _makerFeeNextPrice,
            uint _nextPriceConfirmWindow,
            uint _maxLeverage,
            uint _maxMarketValueUSD,
            uint _maxFundingRate,
            uint _skewScaleUSD
        );

    function minKeeperFee() external view returns (uint);

    function liquidationFeeRatio() external view returns (uint);

    function liquidationBufferRatio() external view returns (uint);

    function minInitialMargin() external view returns (uint);
}


interface IFuturesMarketBaseTypes {
    /* ========== TYPES ========== */

    enum Status {
        Ok,
        InvalidPrice,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // next-price order storage
    struct NextPriceOrder {
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 targetRoundId; // price oracle roundId using which price this order needs to exucted
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }
}


interface IFuturesMarket {
    /* ========== FUNCTION INTERFACE ========== */

    /* ---------- Market Details ---------- */

    function marketKey() external view returns (bytes32 key);

    function baseAsset() external view returns (bytes32 key);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingLastRecomputed() external view returns (uint32 timestamp);

    function fundingSequence(uint index) external view returns (int128 netFunding);

    function positions(address account)
        external
        view
        returns (
            uint64 id,
            uint64 fundingIndex,
            uint128 margin,
            uint128 lastPrice,
            int128 size
        );

    function assetPrice() external view returns (uint price, bool invalid);

    function marketSizes() external view returns (uint long, uint short);

    function marketDebt() external view returns (uint debt, bool isInvalid);

    function currentFundingRate() external view returns (int fundingRate);

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

    function orderFee(int sizeDelta) external view returns (uint fee, bool invalid);

    function postTradeDetails(int sizeDelta, address sender)
        external
        view
        returns (
            uint margin,
            int size,
            uint price,
            uint liqPrice,
            uint fee,
            IFuturesMarketBaseTypes.Status status
        );

    /* ---------- Market Operations ---------- */

    function recomputeFunding() external returns (uint lastIndex);

    function transferMargin(int marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPosition(int sizeDelta) external;

    function modifyPositionWithTracking(int sizeDelta, bytes32 trackingCode) external;

    function submitNextPriceOrder(int sizeDelta) external;

    function submitNextPriceOrderWithTracking(int sizeDelta, bytes32 trackingCode) external;

    function cancelNextPriceOrder(address account) external;

    function executeNextPriceOrder(address account) external;

    function closePosition() external;

    function closePositionWithTracking(bytes32 trackingCode) external;

    function liquidatePosition(address account) external;
}


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/FuturesMarketSettings
contract FuturesMarketSettings is Owned, MixinFuturesMarketSettings, IFuturesMarketSettings {
    /* ========== CONSTANTS ========== */

    /* ---------- Address Resolver Configuration ---------- */

    bytes32 internal constant CONTRACT_FUTURES_MARKET_MANAGER = "FuturesMarketManager";

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _resolver) public Owned(_owner) MixinFuturesMarketSettings(_resolver) {}

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinFuturesMarketSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](1);
        newAddresses[0] = CONTRACT_FUTURES_MARKET_MANAGER;
        addresses = combineArrays(existingAddresses, newAddresses);
    }

    function _futuresMarketManager() internal view returns (IFuturesMarketManager) {
        return IFuturesMarketManager(requireAndGetAddress(CONTRACT_FUTURES_MARKET_MANAGER));
    }

    /* ---------- Getters ---------- */

    /*
     * The fee charged when opening a position on the heavy side of a futures market.
     */
    function takerFee(bytes32 _marketKey) external view returns (uint) {
        return _takerFee(_marketKey);
    }

    /*
     * The fee charged when opening a position on the light side of a futures market.
     */
    function makerFee(bytes32 _marketKey) public view returns (uint) {
        return _makerFee(_marketKey);
    }

    /*
     * The fee charged when opening a position on the heavy side of a futures market using next price mechanism.
     */
    function takerFeeNextPrice(bytes32 _marketKey) external view returns (uint) {
        return _takerFeeNextPrice(_marketKey);
    }

    /*
     * The fee charged when opening a position on the light side of a futures market using next price mechanism.
     */
    function makerFeeNextPrice(bytes32 _marketKey) public view returns (uint) {
        return _makerFeeNextPrice(_marketKey);
    }

    /*
     * The number of price update rounds during which confirming next-price is allowed
     */
    function nextPriceConfirmWindow(bytes32 _marketKey) public view returns (uint) {
        return _nextPriceConfirmWindow(_marketKey);
    }

    /*
     * The maximum allowable leverage in a market.
     */
    function maxLeverage(bytes32 _marketKey) public view returns (uint) {
        return _maxLeverage(_marketKey);
    }

    /*
     * The maximum allowable notional value on each side of a market.
     */
    function maxMarketValueUSD(bytes32 _marketKey) public view returns (uint) {
        return _maxMarketValueUSD(_marketKey);
    }

    /*
     * The maximum theoretical funding rate per day charged by a market.
     */
    function maxFundingRate(bytes32 _marketKey) public view returns (uint) {
        return _maxFundingRate(_marketKey);
    }

    /*
     * The skew level at which the max funding rate will be charged.
     */
    function skewScaleUSD(bytes32 _marketKey) public view returns (uint) {
        return _skewScaleUSD(_marketKey);
    }

    function parameters(bytes32 _marketKey)
        external
        view
        returns (
            uint takerFee,
            uint makerFee,
            uint takerFeeNextPrice,
            uint makerFeeNextPrice,
            uint nextPriceConfirmWindow,
            uint maxLeverage,
            uint maxMarketValueUSD,
            uint maxFundingRate,
            uint skewScaleUSD
        )
    {
        takerFee = _takerFee(_marketKey);
        makerFee = _makerFee(_marketKey);
        takerFeeNextPrice = _takerFeeNextPrice(_marketKey);
        makerFeeNextPrice = _makerFeeNextPrice(_marketKey);
        nextPriceConfirmWindow = _nextPriceConfirmWindow(_marketKey);
        maxLeverage = _maxLeverage(_marketKey);
        maxMarketValueUSD = _maxMarketValueUSD(_marketKey);
        maxFundingRate = _maxFundingRate(_marketKey);
        skewScaleUSD = _skewScaleUSD(_marketKey);
    }

    /*
     * The minimum amount of sUSD paid to a liquidator when they successfully liquidate a position.
     * This quantity must be no greater than `minInitialMargin`.
     */
    function minKeeperFee() external view returns (uint) {
        return _minKeeperFee();
    }

    /*
     * Liquidation fee basis points paid to liquidator.
     * Use together with minKeeperFee() to calculate the actual fee paid.
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

    function setTakerFeeNextPrice(bytes32 _marketKey, uint _takerFeeNextPrice) public onlyOwner {
        require(_takerFeeNextPrice <= 1e18, "taker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_TAKER_FEE_NEXT_PRICE, _takerFeeNextPrice);
    }

    function setMakerFeeNextPrice(bytes32 _marketKey, uint _makerFeeNextPrice) public onlyOwner {
        require(_makerFeeNextPrice <= 1e18, "maker fee greater than 1");
        _setParameter(_marketKey, PARAMETER_MAKER_FEE_NEXT_PRICE, _makerFeeNextPrice);
    }

    function setNextPriceConfirmWindow(bytes32 _marketKey, uint _nextPriceConfirmWindow) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_NEXT_PRICE_CONFIRM_WINDOW, _nextPriceConfirmWindow);
    }

    function setMaxLeverage(bytes32 _marketKey, uint _maxLeverage) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_LEVERAGE, _maxLeverage);
    }

    function setMaxMarketValueUSD(bytes32 _marketKey, uint _maxMarketValueUSD) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_MARKET_VALUE, _maxMarketValueUSD);
    }

    // Before altering parameters relevant to funding rates, outstanding funding on the underlying market
    // must be recomputed, otherwise already-accrued but unrealised funding in the market can change.

    function _recomputeFunding(bytes32 _marketKey) internal {
        IFuturesMarket market = IFuturesMarket(_futuresMarketManager().marketForKey(_marketKey));
        if (market.marketSize() > 0) {
            // only recompute funding when market has positions, this check is important for initial setup
            market.recomputeFunding();
        }
    }

    function setMaxFundingRate(bytes32 _marketKey, uint _maxFundingRate) public onlyOwner {
        _recomputeFunding(_marketKey);
        _setParameter(_marketKey, PARAMETER_MAX_FUNDING_RATE, _maxFundingRate);
    }

    function setSkewScaleUSD(bytes32 _marketKey, uint _skewScaleUSD) public onlyOwner {
        require(_skewScaleUSD > 0, "cannot set skew scale 0");
        _recomputeFunding(_marketKey);
        _setParameter(_marketKey, PARAMETER_MIN_SKEW_SCALE, _skewScaleUSD);
    }

    function setParameters(
        bytes32 _marketKey,
        uint _takerFee,
        uint _makerFee,
        uint _takerFeeNextPrice,
        uint _makerFeeNextPrice,
        uint _nextPriceConfirmWindow,
        uint _maxLeverage,
        uint _maxMarketValueUSD,
        uint _maxFundingRate,
        uint _skewScaleUSD
    ) external onlyOwner {
        _recomputeFunding(_marketKey);
        setTakerFee(_marketKey, _takerFee);
        setMakerFee(_marketKey, _makerFee);
        setTakerFeeNextPrice(_marketKey, _takerFeeNextPrice);
        setMakerFeeNextPrice(_marketKey, _makerFeeNextPrice);
        setNextPriceConfirmWindow(_marketKey, _nextPriceConfirmWindow);
        setMaxLeverage(_marketKey, _maxLeverage);
        setMaxMarketValueUSD(_marketKey, _maxMarketValueUSD);
        setMaxFundingRate(_marketKey, _maxFundingRate);
        setSkewScaleUSD(_marketKey, _skewScaleUSD);
    }

    function setMinKeeperFee(uint _sUSD) external onlyOwner {
        require(_sUSD <= _minInitialMargin(), "min margin < liquidation fee");
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_KEEPER_FEE, _sUSD);
        emit MinKeeperFeeUpdated(_sUSD);
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
    event MinKeeperFeeUpdated(uint sUSD);
    event LiquidationFeeRatioUpdated(uint bps);
    event LiquidationBufferRatioUpdated(uint bps);
    event MinInitialMarginUpdated(uint minMargin);
}


interface ISynthetixNamedContract {
    // solhint-disable func-name-mixedcase
    function CONTRACT_NAME() external view returns (bytes32);
}

// solhint-disable contract-name-camelcase
contract Migration_MuhlifainOptimism is BaseMigration {
    // https://explorer.optimism.io/address/0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;
    address public constant OWNER = 0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;

    // ----------------------------
    // EXISTING SYNTHETIX CONTRACTS
    // ----------------------------

    // https://explorer.optimism.io/address/0xc704c9AA89d1ca60F67B3075d05fBb92b3B00B3B
    FuturesMarketManager public constant futuresmarketmanager_i =
        FuturesMarketManager(0xc704c9AA89d1ca60F67B3075d05fBb92b3B00B3B);
    // https://explorer.optimism.io/address/0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C
    AddressResolver public constant addressresolver_i = AddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);
    // https://explorer.optimism.io/address/0x7EF87c14f50CFFe2e73d2C87916C3128c56593A8
    ExchangeState public constant exchangestate_i = ExchangeState(0x7EF87c14f50CFFe2e73d2C87916C3128c56593A8);
    // https://explorer.optimism.io/address/0xE8c41bE1A167314ABAF2423b72Bf8da826943FFD
    SystemStatus public constant systemstatus_i = SystemStatus(0xE8c41bE1A167314ABAF2423b72Bf8da826943FFD);
    // https://explorer.optimism.io/address/0x0cA3985f973f044978d2381AFEd9c4D85a762d11
    ExchangeRates public constant exchangerates_i = ExchangeRates(0x0cA3985f973f044978d2381AFEd9c4D85a762d11);
    // https://explorer.optimism.io/address/0x01da457Aa57abc0dBa3fc26d6C350899F04E8417
    Issuer public constant issuer_i = Issuer(0x01da457Aa57abc0dBa3fc26d6C350899F04E8417);
    // https://explorer.optimism.io/address/0xaE55F163337A2A46733AA66dA9F35299f9A46e9e
    FuturesMarketSettings public constant futuresmarketsettings_i =
        FuturesMarketSettings(0xaE55F163337A2A46733AA66dA9F35299f9A46e9e);

    // ----------------------------------
    // NEW CONTRACTS DEPLOYED TO BE ADDED
    // ----------------------------------

    // https://explorer.optimism.io/address/0x0cA3985f973f044978d2381AFEd9c4D85a762d11
    address public constant new_ExchangeRates_contract = 0x0cA3985f973f044978d2381AFEd9c4D85a762d11;
    // https://explorer.optimism.io/address/0x803FD1d99C3a6cbcbABAB79C44e108dC2fb67102
    address public constant new_CircuitBreaker_contract = 0x803FD1d99C3a6cbcbABAB79C44e108dC2fb67102;
    // https://explorer.optimism.io/address/0x01da457Aa57abc0dBa3fc26d6C350899F04E8417
    address public constant new_Issuer_contract = 0x01da457Aa57abc0dBa3fc26d6C350899F04E8417;
    // https://explorer.optimism.io/address/0xC37c47C55d894443493c1e2E615f4F9f4b8fDEa4
    address public constant new_Exchanger_contract = 0xC37c47C55d894443493c1e2E615f4F9f4b8fDEa4;
    // https://explorer.optimism.io/address/0xd325B17d5C9C3f2B6853A760afCF81945b0184d3
    address public constant new_FuturesMarketDebtRatio_contract = 0xd325B17d5C9C3f2B6853A760afCF81945b0184d3;
    // https://explorer.optimism.io/address/0x3Ed04CEfF4c91872F19b1da35740C0Be9CA21558
    address public constant new_FuturesMarketXMR_contract = 0x3Ed04CEfF4c91872F19b1da35740C0Be9CA21558;
    // https://explorer.optimism.io/address/0x9F1C2f0071Bc3b31447AEda9fA3A68d651eB4632
    address public constant new_FuturesMarketOP_contract = 0x9F1C2f0071Bc3b31447AEda9fA3A68d651eB4632;
    // https://explorer.optimism.io/address/0x4Aa0dabd22BC0894975324Bec293443c8538bD08
    address public constant new_FuturesMarketBNB_contract = 0x4Aa0dabd22BC0894975324Bec293443c8538bD08;
    // https://explorer.optimism.io/address/0x9f231dBE53D460f359B2B8CC47574493caA5B7Bf
    address public constant new_FuturesMarketDOGE_contract = 0x9f231dBE53D460f359B2B8CC47574493caA5B7Bf;

    constructor() public BaseMigration(OWNER) {}

    function contractsRequiringOwnership() public pure returns (address[] memory contracts) {
        contracts = new address[](7);
        contracts[0] = address(futuresmarketmanager_i);
        contracts[1] = address(addressresolver_i);
        contracts[2] = address(exchangestate_i);
        contracts[3] = address(systemstatus_i);
        contracts[4] = address(exchangerates_i);
        contracts[5] = address(issuer_i);
        contracts[6] = address(futuresmarketsettings_i);
    }

    function migrate() external onlyOwner {
        require(
            ISynthetixNamedContract(new_ExchangeRates_contract).CONTRACT_NAME() == "ExchangeRates",
            "Invalid contract supplied for ExchangeRates"
        );
        require(
            ISynthetixNamedContract(new_CircuitBreaker_contract).CONTRACT_NAME() == "CircuitBreaker",
            "Invalid contract supplied for CircuitBreaker"
        );
        require(
            ISynthetixNamedContract(new_Issuer_contract).CONTRACT_NAME() == "Issuer",
            "Invalid contract supplied for Issuer"
        );
        require(
            ISynthetixNamedContract(new_Exchanger_contract).CONTRACT_NAME() == "Exchanger",
            "Invalid contract supplied for Exchanger"
        );

        // ACCEPT OWNERSHIP for all contracts that require ownership to make changes
        acceptAll();

        // MIGRATION
        futuresmarketmanager_addMarkets_0();
        // Import all new contracts into the address resolver;
        addressresolver_importAddresses_1();
        // Rebuild the resolver caches in all MixinResolver contracts - batch 1;
        addressresolver_rebuildCaches_2();
        // Rebuild the resolver caches in all MixinResolver contracts - batch 2;
        addressresolver_rebuildCaches_3();
        // Rebuild the resolver caches in all MixinResolver contracts - batch 3;
        addressresolver_rebuildCaches_4();
        // Ensure the Exchanger contract can write to its State;
        exchangestate_i.setAssociatedContract(new_Exchanger_contract);
        // Ensure Issuer contract can suspend issuance - see SIP-165;
        systemstatus_i.updateAccessControl("Issuance", new_Issuer_contract, true, false);
        // Ensure the ExchangeRates contract has the standalone feed for SNX;
        exchangerates_i.addAggregator("SNX", 0x2FCF37343e916eAEd1f1DdaaF84458a359b53877);
        // Ensure the ExchangeRates contract has the standalone feed for ETH;
        exchangerates_i.addAggregator("ETH", 0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        // Ensure the ExchangeRates contract has the standalone feed for BTC;
        exchangerates_i.addAggregator("BTC", 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593);
        // Ensure the ExchangeRates contract has the standalone feed for LINK;
        exchangerates_i.addAggregator("LINK", 0xCc232dcFAAE6354cE191Bd574108c1aD03f86450);
        // Ensure the ExchangeRates contract has the standalone feed for SOL;
        exchangerates_i.addAggregator("SOL", 0xC663315f7aF904fbbB0F785c32046dFA03e85270);
        // Ensure the ExchangeRates contract has the standalone feed for AVAX;
        exchangerates_i.addAggregator("AVAX", 0x5087Dc69Fd3907a016BD42B38022F7f024140727);
        // Ensure the ExchangeRates contract has the standalone feed for MATIC;
        exchangerates_i.addAggregator("MATIC", 0x0ded608AFc23724f614B76955bbd9dFe7dDdc828);
        // Ensure the ExchangeRates contract has the standalone feed for EUR;
        exchangerates_i.addAggregator("EUR", 0x3626369857A10CcC6cc3A6e4f5C2f5984a519F20);
        // Ensure the ExchangeRates contract has the standalone feed for AAVE;
        exchangerates_i.addAggregator("AAVE", 0x338ed6787f463394D24813b297401B9F05a8C9d1);
        // Ensure the ExchangeRates contract has the standalone feed for UNI;
        exchangerates_i.addAggregator("UNI", 0x11429eE838cC01071402f21C219870cbAc0a59A0);
        // Ensure the ExchangeRates contract has the standalone feed for XAU;
        exchangerates_i.addAggregator("XAU", 0x8F7bFb42Bf7421c2b34AAD619be4654bFa7B3B8B);
        // Ensure the ExchangeRates contract has the standalone feed for XAG;
        exchangerates_i.addAggregator("XAG", 0x290dd71254874f0d4356443607cb8234958DEe49);
        // Ensure the ExchangeRates contract has the standalone feed for INR;
        exchangerates_i.addAggregator("INR", 0x5535e67d8f99c8ebe961E1Fc1F6DDAE96FEC82C9);
        // Ensure the ExchangeRates contract has the standalone feed for APE;
        exchangerates_i.addAggregator("APE", 0x89178957E9bD07934d7792fFc0CF39f11c8C2B1F);
        // Ensure the ExchangeRates contract has the standalone feed for DYDX;
        exchangerates_i.addAggregator("DYDX", 0xee35A95c9a064491531493D8b380bC40A4CCd0Da);
        // Ensure the ExchangeRates contract has the standalone feed for DebtRatio;
        exchangerates_i.addAggregator("DebtRatio", 0x94A178f2c480D14F8CdDa908D173d7a73F779cb7);
        // Ensure the ExchangeRates contract has the standalone feed for BNB;
        exchangerates_i.addAggregator("BNB", 0xD38579f7cBD14c22cF1997575eA8eF7bfe62ca2c);
        // Ensure the ExchangeRates contract has the standalone feed for OP;
        exchangerates_i.addAggregator("OP", 0x0D276FC14719f9292D5C1eA2198673d1f4269246);
        // Ensure the ExchangeRates contract has the standalone feed for XMR;
        exchangerates_i.addAggregator("XMR", 0x2a8D91686A048E98e6CCF1A89E82f40D14312672);
        // Ensure the ExchangeRates contract has the standalone feed for DOGE;
        exchangerates_i.addAggregator("DOGE", 0xC6066533917f034Cf610c08e1fe5e9c7eADe0f54);
        // Ensure the ExchangeRates contract has the feed for sETH;
        exchangerates_i.addAggregator("sETH", 0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        // Ensure the ExchangeRates contract has the feed for sBTC;
        exchangerates_i.addAggregator("sBTC", 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593);
        // Ensure the ExchangeRates contract has the feed for sLINK;
        exchangerates_i.addAggregator("sLINK", 0xCc232dcFAAE6354cE191Bd574108c1aD03f86450);
        // Ensure the ExchangeRates contract has the feed for sSOL;
        exchangerates_i.addAggregator("sSOL", 0xC663315f7aF904fbbB0F785c32046dFA03e85270);
        // Ensure the ExchangeRates contract has the feed for sAVAX;
        exchangerates_i.addAggregator("sAVAX", 0x5087Dc69Fd3907a016BD42B38022F7f024140727);
        // Ensure the ExchangeRates contract has the feed for sMATIC;
        exchangerates_i.addAggregator("sMATIC", 0x0ded608AFc23724f614B76955bbd9dFe7dDdc828);
        // Ensure the ExchangeRates contract has the feed for sEUR;
        exchangerates_i.addAggregator("sEUR", 0x3626369857A10CcC6cc3A6e4f5C2f5984a519F20);
        // Ensure the ExchangeRates contract has the feed for sAAVE;
        exchangerates_i.addAggregator("sAAVE", 0x338ed6787f463394D24813b297401B9F05a8C9d1);
        // Ensure the ExchangeRates contract has the feed for sUNI;
        exchangerates_i.addAggregator("sUNI", 0x11429eE838cC01071402f21C219870cbAc0a59A0);
        // Ensure the ExchangeRates contract has the feed for sXAU;
        exchangerates_i.addAggregator("sXAU", 0x8F7bFb42Bf7421c2b34AAD619be4654bFa7B3B8B);
        // Ensure the ExchangeRates contract has the feed for sXAG;
        exchangerates_i.addAggregator("sXAG", 0x290dd71254874f0d4356443607cb8234958DEe49);
        // Ensure the ExchangeRates contract has the feed for sINR;
        exchangerates_i.addAggregator("sINR", 0x5535e67d8f99c8ebe961E1Fc1F6DDAE96FEC82C9);
        // Ensure the ExchangeRates contract has the feed for sAPE;
        exchangerates_i.addAggregator("sAPE", 0x89178957E9bD07934d7792fFc0CF39f11c8C2B1F);
        // Ensure the ExchangeRates contract has the feed for sDYDX;
        exchangerates_i.addAggregator("sDYDX", 0xee35A95c9a064491531493D8b380bC40A4CCd0Da);
        // Ensure the ExchangeRates contract has the feed for sDebtRatio;
        exchangerates_i.addAggregator("sDebtRatio", 0x94A178f2c480D14F8CdDa908D173d7a73F779cb7);
        // Ensure the ExchangeRates contract has the feed for sBNB;
        exchangerates_i.addAggregator("sBNB", 0xD38579f7cBD14c22cF1997575eA8eF7bfe62ca2c);
        // Ensure the ExchangeRates contract has the feed for sOP;
        exchangerates_i.addAggregator("sOP", 0x0D276FC14719f9292D5C1eA2198673d1f4269246);
        // Ensure the ExchangeRates contract has the feed for sXMR;
        exchangerates_i.addAggregator("sXMR", 0x2a8D91686A048E98e6CCF1A89E82f40D14312672);
        // Ensure the ExchangeRates contract has the feed for sDOGE;
        exchangerates_i.addAggregator("sDOGE", 0xC6066533917f034Cf610c08e1fe5e9c7eADe0f54);
        // Add synths to the Issuer contract - batch 1;
        issuer_addSynths_46();
        futuresmarketsettings_i.setTakerFee("sDebtRatio", 6000000000000000);
        futuresmarketsettings_i.setMakerFee("sDebtRatio", 6000000000000000);
        futuresmarketsettings_i.setTakerFeeNextPrice("sDebtRatio", 1500000000000000);
        futuresmarketsettings_i.setMakerFeeNextPrice("sDebtRatio", 1500000000000000);
        futuresmarketsettings_i.setNextPriceConfirmWindow("sDebtRatio", 2);
        futuresmarketsettings_i.setMaxLeverage("sDebtRatio", 10000000000000000000);
        futuresmarketsettings_i.setMaxMarketValueUSD("sDebtRatio", 1000000000000000000000000);
        futuresmarketsettings_i.setMaxFundingRate("sDebtRatio", 100000000000000000);
        futuresmarketsettings_i.setSkewScaleUSD("sDebtRatio", 5000000000000000000000000);
        // Ensure futures market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sDebtRatio", 80);
        futuresmarketsettings_i.setTakerFee("sBNB", 4000000000000000);
        futuresmarketsettings_i.setMakerFee("sBNB", 3500000000000000);
        futuresmarketsettings_i.setTakerFeeNextPrice("sBNB", 3000000000000000);
        futuresmarketsettings_i.setMakerFeeNextPrice("sBNB", 3000000000000000);
        futuresmarketsettings_i.setNextPriceConfirmWindow("sBNB", 2);
        futuresmarketsettings_i.setMaxLeverage("sBNB", 10000000000000000000);
        futuresmarketsettings_i.setMaxMarketValueUSD("sBNB", 1000000000000000000000000);
        futuresmarketsettings_i.setMaxFundingRate("sBNB", 100000000000000000);
        futuresmarketsettings_i.setSkewScaleUSD("sBNB", 50000000000000000000000000);
        // Ensure futures market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sBNB", 80);
        futuresmarketsettings_i.setTakerFee("sOP", 4000000000000000);
        futuresmarketsettings_i.setMakerFee("sOP", 3500000000000000);
        futuresmarketsettings_i.setTakerFeeNextPrice("sOP", 3000000000000000);
        futuresmarketsettings_i.setMakerFeeNextPrice("sOP", 3000000000000000);
        futuresmarketsettings_i.setNextPriceConfirmWindow("sOP", 2);
        futuresmarketsettings_i.setMaxLeverage("sOP", 10000000000000000000);
        futuresmarketsettings_i.setMaxMarketValueUSD("sOP", 1000000000000000000000000);
        futuresmarketsettings_i.setMaxFundingRate("sOP", 100000000000000000);
        futuresmarketsettings_i.setSkewScaleUSD("sOP", 50000000000000000000000000);
        // Ensure futures market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sOP", 80);
        futuresmarketsettings_i.setTakerFee("sXMR", 4000000000000000);
        futuresmarketsettings_i.setMakerFee("sXMR", 3500000000000000);
        futuresmarketsettings_i.setTakerFeeNextPrice("sXMR", 3000000000000000);
        futuresmarketsettings_i.setMakerFeeNextPrice("sXMR", 3000000000000000);
        futuresmarketsettings_i.setNextPriceConfirmWindow("sXMR", 2);
        futuresmarketsettings_i.setMaxLeverage("sXMR", 10000000000000000000);
        futuresmarketsettings_i.setMaxMarketValueUSD("sXMR", 1000000000000000000000000);
        futuresmarketsettings_i.setMaxFundingRate("sXMR", 100000000000000000);
        futuresmarketsettings_i.setSkewScaleUSD("sXMR", 50000000000000000000000000);
        // Ensure futures market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sXMR", 80);
        futuresmarketsettings_i.setTakerFee("sDOGE", 4000000000000000);
        futuresmarketsettings_i.setMakerFee("sDOGE", 3500000000000000);
        futuresmarketsettings_i.setTakerFeeNextPrice("sDOGE", 3000000000000000);
        futuresmarketsettings_i.setMakerFeeNextPrice("sDOGE", 3000000000000000);
        futuresmarketsettings_i.setNextPriceConfirmWindow("sDOGE", 2);
        futuresmarketsettings_i.setMaxLeverage("sDOGE", 10000000000000000000);
        futuresmarketsettings_i.setMaxMarketValueUSD("sDOGE", 1000000000000000000000000);
        futuresmarketsettings_i.setMaxFundingRate("sDOGE", 100000000000000000);
        futuresmarketsettings_i.setSkewScaleUSD("sDOGE", 50000000000000000000000000);
        // Ensure futures market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sDOGE", 80);

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

    function futuresmarketmanager_addMarkets_0() internal {
        address[] memory futuresmarketmanager_addMarkets_marketsToAdd_0_0 = new address[](5);
        futuresmarketmanager_addMarkets_marketsToAdd_0_0[0] = address(new_FuturesMarketDebtRatio_contract);
        futuresmarketmanager_addMarkets_marketsToAdd_0_0[1] = address(new_FuturesMarketBNB_contract);
        futuresmarketmanager_addMarkets_marketsToAdd_0_0[2] = address(new_FuturesMarketOP_contract);
        futuresmarketmanager_addMarkets_marketsToAdd_0_0[3] = address(new_FuturesMarketXMR_contract);
        futuresmarketmanager_addMarkets_marketsToAdd_0_0[4] = address(new_FuturesMarketDOGE_contract);
        futuresmarketmanager_i.addMarkets(futuresmarketmanager_addMarkets_marketsToAdd_0_0);
    }

    function addressresolver_importAddresses_1() internal {
        bytes32[] memory addressresolver_importAddresses_names_1_0 = new bytes32[](9);
        addressresolver_importAddresses_names_1_0[0] = bytes32("ExchangeRates");
        addressresolver_importAddresses_names_1_0[1] = bytes32("CircuitBreaker");
        addressresolver_importAddresses_names_1_0[2] = bytes32("Issuer");
        addressresolver_importAddresses_names_1_0[3] = bytes32("Exchanger");
        addressresolver_importAddresses_names_1_0[4] = bytes32("FuturesMarketDebtRatio");
        addressresolver_importAddresses_names_1_0[5] = bytes32("FuturesMarketXMR");
        addressresolver_importAddresses_names_1_0[6] = bytes32("FuturesMarketOP");
        addressresolver_importAddresses_names_1_0[7] = bytes32("FuturesMarketBNB");
        addressresolver_importAddresses_names_1_0[8] = bytes32("FuturesMarketDOGE");
        address[] memory addressresolver_importAddresses_destinations_1_1 = new address[](9);
        addressresolver_importAddresses_destinations_1_1[0] = address(new_ExchangeRates_contract);
        addressresolver_importAddresses_destinations_1_1[1] = address(new_CircuitBreaker_contract);
        addressresolver_importAddresses_destinations_1_1[2] = address(new_Issuer_contract);
        addressresolver_importAddresses_destinations_1_1[3] = address(new_Exchanger_contract);
        addressresolver_importAddresses_destinations_1_1[4] = address(new_FuturesMarketDebtRatio_contract);
        addressresolver_importAddresses_destinations_1_1[5] = address(new_FuturesMarketXMR_contract);
        addressresolver_importAddresses_destinations_1_1[6] = address(new_FuturesMarketOP_contract);
        addressresolver_importAddresses_destinations_1_1[7] = address(new_FuturesMarketBNB_contract);
        addressresolver_importAddresses_destinations_1_1[8] = address(new_FuturesMarketDOGE_contract);
        addressresolver_i.importAddresses(
            addressresolver_importAddresses_names_1_0,
            addressresolver_importAddresses_destinations_1_1
        );
    }

    function addressresolver_rebuildCaches_2() internal {
        MixinResolver[] memory addressresolver_rebuildCaches_destinations_2_0 = new MixinResolver[](20);
        addressresolver_rebuildCaches_destinations_2_0[0] = MixinResolver(0x68a8b098967Ae077dcFf5cC8E29B7cb15f1A3cC8);
        addressresolver_rebuildCaches_destinations_2_0[1] = MixinResolver(0x17628A557d1Fc88D1c35989dcBAC3f3e275E2d2B);
        addressresolver_rebuildCaches_destinations_2_0[2] = MixinResolver(new_Exchanger_contract);
        addressresolver_rebuildCaches_destinations_2_0[3] = MixinResolver(new_CircuitBreaker_contract);
        addressresolver_rebuildCaches_destinations_2_0[4] = MixinResolver(0x7322e8F6cB6c6a7B4e6620C486777fcB9Ea052a4);
        addressresolver_rebuildCaches_destinations_2_0[5] = MixinResolver(new_Issuer_contract);
        addressresolver_rebuildCaches_destinations_2_0[6] = MixinResolver(0x136b1EC699c62b0606854056f02dC7Bb80482d63);
        addressresolver_rebuildCaches_destinations_2_0[7] = MixinResolver(0xD21969A86Ce5c41aAb2D492a0F802AA3e015cd9A);
        addressresolver_rebuildCaches_destinations_2_0[8] = MixinResolver(0x15E7D4972a3E477878A5867A47617122BE2d1fF0);
        addressresolver_rebuildCaches_destinations_2_0[9] = MixinResolver(0x308AD16ef90fe7caCb85B784A603CB6E71b1A41a);
        addressresolver_rebuildCaches_destinations_2_0[10] = MixinResolver(0xeb4b5ABcE7310855319440d936cd3aDd77DFA193);
        addressresolver_rebuildCaches_destinations_2_0[11] = MixinResolver(0x6202A3B0bE1D222971E93AaB084c6E584C29DB70);
        addressresolver_rebuildCaches_destinations_2_0[12] = MixinResolver(0xad32aA4Bff8b61B4aE07E3BA437CF81100AF0cD7);
        addressresolver_rebuildCaches_destinations_2_0[13] = MixinResolver(0x8A91e92FDd86e734781c38DB52a390e1B99fba7c);
        addressresolver_rebuildCaches_destinations_2_0[14] = MixinResolver(new_ExchangeRates_contract);
        addressresolver_rebuildCaches_destinations_2_0[15] = MixinResolver(0x47eE58801C1AC44e54FF2651aE50525c5cfc66d0);
        addressresolver_rebuildCaches_destinations_2_0[16] = MixinResolver(0x45c55BF488D3Cb8640f12F63CbeDC027E8261E79);
        addressresolver_rebuildCaches_destinations_2_0[17] = MixinResolver(0xF4EebDD0704021eF2a6Bbe993fdf93030Cd784b4);
        addressresolver_rebuildCaches_destinations_2_0[18] = MixinResolver(0xD3739A5F06747e148E716Dcb7147B9BA15b70fcc);
        addressresolver_rebuildCaches_destinations_2_0[19] = MixinResolver(0xFE8E48Bf36ccC3254081eC8C65965D1c8b2E744D);
        addressresolver_i.rebuildCaches(addressresolver_rebuildCaches_destinations_2_0);
    }

    function addressresolver_rebuildCaches_3() internal {
        MixinResolver[] memory addressresolver_rebuildCaches_destinations_3_0 = new MixinResolver[](20);
        addressresolver_rebuildCaches_destinations_3_0[0] = MixinResolver(0xA997BD647AEe62Ef03b41e6fBFAdaB43d8E57535);
        addressresolver_rebuildCaches_destinations_3_0[1] = MixinResolver(0xDfA2d3a0d32F870D87f8A0d7AA6b9CdEB7bc5AdB);
        addressresolver_rebuildCaches_destinations_3_0[2] = MixinResolver(0xe9dceA0136FEFC76c4E639Ec60CCE70482E2aCF7);
        addressresolver_rebuildCaches_destinations_3_0[3] = MixinResolver(0x421DEF861D623F7123dfE0878D86E9576cbb3975);
        addressresolver_rebuildCaches_destinations_3_0[4] = MixinResolver(0x0F6877e0Bb54a0739C6173A814B39D5127804123);
        addressresolver_rebuildCaches_destinations_3_0[5] = MixinResolver(0x04B50a5992Ea2281E14d43494d656698EA9C24dD);
        addressresolver_rebuildCaches_destinations_3_0[6] = MixinResolver(0x368A5126fF8e659004b6f9C9F723E15632e2B428);
        addressresolver_rebuildCaches_destinations_3_0[7] = MixinResolver(0xf49C194954b6B91855aC06D6C88Be316da60eD96);
        addressresolver_rebuildCaches_destinations_3_0[8] = MixinResolver(0xdEdb0b04AFF1525bb4B6167F00e61601690c1fF2);
        addressresolver_rebuildCaches_destinations_3_0[9] = MixinResolver(0x34783A738DdC355cD7c737D4101b20622681332a);
        addressresolver_rebuildCaches_destinations_3_0[10] = MixinResolver(0xcF2E165D2359E3C4dFF1E10eC40dBB5a745223A9);
        addressresolver_rebuildCaches_destinations_3_0[11] = MixinResolver(0x34c2360ffe5D21542f76e991FFD104f281D4B3fb);
        addressresolver_rebuildCaches_destinations_3_0[12] = MixinResolver(0x2DcAD1A019fba8301b77810Ae14007cc88ED004B);
        addressresolver_rebuildCaches_destinations_3_0[13] = MixinResolver(0xc704c9AA89d1ca60F67B3075d05fBb92b3B00B3B);
        addressresolver_rebuildCaches_destinations_3_0[14] = MixinResolver(0xEe8804d8Ad10b0C3aD1Bd57AC3737242aD24bB95);
        addressresolver_rebuildCaches_destinations_3_0[15] = MixinResolver(0xf86048DFf23cF130107dfB4e6386f574231a5C65);
        addressresolver_rebuildCaches_destinations_3_0[16] = MixinResolver(0x1228c7D8BBc5bC53DB181bD7B1fcE765aa83bF8A);
        addressresolver_rebuildCaches_destinations_3_0[17] = MixinResolver(0xcF853f7f8F78B2B801095b66F8ba9c5f04dB1640);
        addressresolver_rebuildCaches_destinations_3_0[18] = MixinResolver(0x4ff54624D5FB61C34c634c3314Ed3BfE4dBB665a);
        addressresolver_rebuildCaches_destinations_3_0[19] = MixinResolver(0x001b7876F567f0b3A639332Ed1e363839c6d85e2);
        addressresolver_i.rebuildCaches(addressresolver_rebuildCaches_destinations_3_0);
    }

    function addressresolver_rebuildCaches_4() internal {
        MixinResolver[] memory addressresolver_rebuildCaches_destinations_4_0 = new MixinResolver[](12);
        addressresolver_rebuildCaches_destinations_4_0[0] = MixinResolver(0x5Af0072617F7f2AEB0e314e2faD1DE0231Ba97cD);
        addressresolver_rebuildCaches_destinations_4_0[1] = MixinResolver(0xbCB2D435045E16B059b2130b28BE70b5cA47bFE5);
        addressresolver_rebuildCaches_destinations_4_0[2] = MixinResolver(0x4434f56ddBdE28fab08C4AE71970a06B300F8881);
        addressresolver_rebuildCaches_destinations_4_0[3] = MixinResolver(0xb147C69BEe211F57290a6cde9d1BAbfD0DCF3Ea3);
        addressresolver_rebuildCaches_destinations_4_0[4] = MixinResolver(0xad44873632840144fFC97b2D1de716f6E2cF0366);
        addressresolver_rebuildCaches_destinations_4_0[5] = MixinResolver(0xFe00395ec846240dc693e92AB2Dd720F94765Aa3);
        addressresolver_rebuildCaches_destinations_4_0[6] = MixinResolver(0x10305C1854d6DB8A1060dF60bDF8A8B2981249Cf);
        addressresolver_rebuildCaches_destinations_4_0[7] = MixinResolver(new_FuturesMarketDebtRatio_contract);
        addressresolver_rebuildCaches_destinations_4_0[8] = MixinResolver(new_FuturesMarketBNB_contract);
        addressresolver_rebuildCaches_destinations_4_0[9] = MixinResolver(new_FuturesMarketOP_contract);
        addressresolver_rebuildCaches_destinations_4_0[10] = MixinResolver(new_FuturesMarketXMR_contract);
        addressresolver_rebuildCaches_destinations_4_0[11] = MixinResolver(new_FuturesMarketDOGE_contract);
        addressresolver_i.rebuildCaches(addressresolver_rebuildCaches_destinations_4_0);
    }

    function issuer_addSynths_46() internal {
        ISynth[] memory issuer_addSynths_synthsToAdd_46_0 = new ISynth[](11);
        issuer_addSynths_synthsToAdd_46_0[0] = ISynth(0xDfA2d3a0d32F870D87f8A0d7AA6b9CdEB7bc5AdB);
        issuer_addSynths_synthsToAdd_46_0[1] = ISynth(0xe9dceA0136FEFC76c4E639Ec60CCE70482E2aCF7);
        issuer_addSynths_synthsToAdd_46_0[2] = ISynth(0x421DEF861D623F7123dfE0878D86E9576cbb3975);
        issuer_addSynths_synthsToAdd_46_0[3] = ISynth(0x0F6877e0Bb54a0739C6173A814B39D5127804123);
        issuer_addSynths_synthsToAdd_46_0[4] = ISynth(0x04B50a5992Ea2281E14d43494d656698EA9C24dD);
        issuer_addSynths_synthsToAdd_46_0[5] = ISynth(0x368A5126fF8e659004b6f9C9F723E15632e2B428);
        issuer_addSynths_synthsToAdd_46_0[6] = ISynth(0xf49C194954b6B91855aC06D6C88Be316da60eD96);
        issuer_addSynths_synthsToAdd_46_0[7] = ISynth(0xdEdb0b04AFF1525bb4B6167F00e61601690c1fF2);
        issuer_addSynths_synthsToAdd_46_0[8] = ISynth(0x34783A738DdC355cD7c737D4101b20622681332a);
        issuer_addSynths_synthsToAdd_46_0[9] = ISynth(0xcF2E165D2359E3C4dFF1E10eC40dBB5a745223A9);
        issuer_addSynths_synthsToAdd_46_0[10] = ISynth(0x34c2360ffe5D21542f76e991FFD104f281D4B3fb);
        issuer_i.addSynths(issuer_addSynths_synthsToAdd_46_0);
    }
}