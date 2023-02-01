/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-30
*/

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: migrations/Migration_MintakaOptimism.sol
*
* Latest source (may be newer): https://github.com/Synthetixio/synthetix/blob/master/contracts/migrations/Migration_MintakaOptimism.sol
* Docs: https://docs.synthetix.io/contracts/migrations/Migration_MintakaOptimism
*
* Contract Dependencies: 
*	- BaseMigration
*	- IAddressResolver
*	- IFuturesMarketManager
*	- IPerpsV2Market
*	- IPerpsV2MarketBaseTypes
*	- IPerpsV2MarketDelayedOrders
*	- IPerpsV2MarketOffchainOrders
*	- IPerpsV2MarketSettings
*	- MixinPerpsV2MarketSettings
*	- MixinResolver
*	- MixinSystemSettings
*	- Owned
*	- PerpsV2MarketBase
*	- PerpsV2MarketDelayedOrdersBase
*	- PerpsV2MarketProxyable
*	- Proxyable
*	- ReentrancyGuard
*	- StateShared
* Libraries: 
*	- AddressSetLib
*	- SafeDecimalMath
*	- SafeMath
*	- SignedSafeDecimalMath
*	- SignedSafeMath
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


pragma experimental ABIEncoderV2;

// Inheritance


// Internal references


/**
 * Based on Proxy.sol that adds routing capabilities to route specific function calls (selectors) to
 * specific implementations and flagging the routes if are views in order to not call
 * proxyable.setMessageSender() that is mutative (resulting in a revert).
 *
 * In order to manage the routes it provides two onlyOwner functions (`addRoute` and `removeRoute`), and
 * some helper views to get the size of the route list (`getRoutesLength`), the list of routes (`getRoutesPage`),
 * and a list of all the targeted contracts.
 */
// https://docs.synthetix.io/contracts/source/contracts/ProxyPerpsV2
contract ProxyPerpsV2 is Owned {
    /* ----- Dynamic router storage ----- */
    struct Route {
        bytes4 selector;
        address implementation;
        bool isView;
    }

    // Route definition and index to quickly access it
    Route[] internal _routes;
    mapping(bytes4 => uint) internal _routeIndexes;
    // number of routes referencing a target, if number is greater than zero, it means the address is a valid target
    mapping(address => uint) internal _targetReferences;
    // list of valid target addresses (more than zero references in the routes)
    address[] internal _routedTargets;

    constructor(address _owner) public Owned(_owner) {}

    /* ----- Dynamic router administration ----- */
    function _contains(bytes4 selector) internal view returns (bool) {
        if (_routes.length == 0) {
            return false;
        }
        uint index = _routeIndexes[selector];
        return index != 0 || _routes[0].selector == selector;
    }

    function _removeTargetReference(address implementation) internal {
        require(_targetReferences[implementation] > 0, "Target not referenced.");

        // Decrement the references
        _targetReferences[implementation] -= 1;

        // if was the latest reference, remove it from the _routedTargets and emit an event
        if (_targetReferences[implementation] == 0) {
            // Accepting a for loop since implementations for a market is going to be a very limited number (initially only 2)
            for (uint idx = 0; idx < _routedTargets.length; idx++) {
                if (_routedTargets[idx] == implementation) {
                    // remove it by bringing the last one to that position and poping the latest item (if it's the latest one will do an unecessary write)
                    _routedTargets[idx] = _routedTargets[_routedTargets.length - 1];
                    _routedTargets.pop();
                    break;
                }
            }

            emit TargetedRouteRemoved(implementation);
        }
    }

    function addRoute(
        bytes4 selector,
        address implementation,
        bool isView
    ) external onlyOwner {
        require(selector != bytes4(0), "Invalid nil selector");

        if (_contains(selector)) {
            // Update data
            Route storage route = _routes[_routeIndexes[selector]];

            // Remove old implementation reference
            _removeTargetReference(route.implementation);

            route.selector = selector;
            route.implementation = implementation;
            route.isView = isView;
        } else {
            // Add data
            _routeIndexes[selector] = _routes.length;
            Route memory newRoute;
            newRoute.selector = selector;
            newRoute.implementation = implementation;
            newRoute.isView = isView;

            _routes.push(newRoute);
        }

        // Add to targeted references
        _targetReferences[implementation] += 1;
        if (_targetReferences[implementation] == 1) {
            // First reference, add to routed targets and emit the event
            _routedTargets.push(implementation);
            emit TargetedRouteAdded(implementation);
        }

        emit RouteUpdated(selector, implementation, isView);
    }

    function removeRoute(bytes4 selector) external onlyOwner {
        require(_contains(selector), "Selector not in set.");

        // Replace the removed selector with the last selector of the list.
        uint index = _routeIndexes[selector];
        uint lastIndex = _routes.length - 1; // We required that selector is in the list, so it is not empty.

        // Remove target reference
        _removeTargetReference(_routes[index].implementation);

        // Ensure target is in latest index
        if (index != lastIndex) {
            // No need to shift the last selector if it is the one we want to delete.
            Route storage shiftedElement = _routes[lastIndex];
            _routes[index] = shiftedElement;
            _routeIndexes[shiftedElement.selector] = index;
        }

        // Remove target
        _routes.pop();
        delete _routeIndexes[selector];
        emit RouteRemoved(selector);
    }

    function getRoute(bytes4 selector) external view returns (Route memory) {
        if (!_contains(selector)) {
            return Route(0, address(0), false);
        }
        return _routes[_routeIndexes[selector]];
    }

    function getRoutesLength() external view returns (uint) {
        return _routes.length;
    }

    function getRoutesPage(uint index, uint pageSize) external view returns (Route[] memory) {
        // NOTE: This implementation should be converted to slice operators if the compiler is updated to v0.6.0+
        uint endIndex = index + pageSize; // The check below that endIndex <= index handles overflow.

        // If the page extends past the end of the list, truncate it.
        if (endIndex > _routes.length) {
            endIndex = _routes.length;
        }
        if (endIndex <= index) {
            return new Route[](0);
        }

        uint n = endIndex - index; // We already checked for negative overflow.
        Route[] memory page = new Route[](n);
        for (uint i; i < n; i++) {
            page[i] = _routes[i + index];
        }
        return page;
    }

    function getAllTargets() external view returns (address[] memory) {
        return _routedTargets;
    }

    ///// BASED ON PROXY.SOL /////
    /* ----- Proxy based on Proxy.sol ----- */

    function _emit(
        bytes calldata callData,
        uint numTopics,
        bytes32 topic1,
        bytes32 topic2,
        bytes32 topic3,
        bytes32 topic4
    ) external onlyTargets {
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
        bytes4 sig4 = msg.sig;

        require(_contains(sig4), "Invalid selector");

        // Identify target
        address implementation = _routes[_routeIndexes[sig4]].implementation;
        bool isView = _routes[_routeIndexes[sig4]].isView;

        if (isView) {
            assembly {
                let free_ptr := mload(0x40)
                calldatacopy(free_ptr, 0, calldatasize)

                /* We must explicitly forward ether to the underlying contract as well. */
                let result := staticcall(gas, implementation, free_ptr, calldatasize, 0, 0)
                returndatacopy(free_ptr, 0, returndatasize)

                if iszero(result) {
                    revert(free_ptr, returndatasize)
                }
                return(free_ptr, returndatasize)
            }
        } else {
            // Mutable call setting Proxyable.messageSender as this is using call not delegatecall
            Proxyable(implementation).setMessageSender(msg.sender);
            assembly {
                let free_ptr := mload(0x40)
                calldatacopy(free_ptr, 0, calldatasize)

                /* We must explicitly forward ether to the underlying contract as well. */
                let result := call(gas, implementation, callvalue, free_ptr, calldatasize, 0, 0)
                returndatacopy(free_ptr, 0, returndatasize)

                if iszero(result) {
                    revert(free_ptr, returndatasize)
                }
                return(free_ptr, returndatasize)
            }
        }
    }

    modifier onlyTargets {
        require(_targetReferences[msg.sender] > 0, "Must be a proxy target");
        _;
    }

    event RouteUpdated(bytes4 route, address implementation, bool isView);

    event RouteRemoved(bytes4 route);

    event TargetedRouteAdded(address targetedRoute);

    event TargetedRouteRemoved(address targetedRoute);
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


/**
 * Based on `State.sol`. This contract adds the capability to have multiple associated contracts
 * enabled to access a state contract.
 *
 * Note: it changed the interface to manage the associated contracts from `setAssociatedContract`
 * to `addAssociatedContracts` or `removeAssociatedContracts` and the modifier is now plural
 */
// https://docs.synthetix.io/contracts/source/contracts/StateShared
contract StateShared is Owned {
    using AddressSetLib for AddressSetLib.AddressSet;

    // the address of the contract that can modify variables
    // this can only be changed by the owner of this contract
    AddressSetLib.AddressSet internal _associatedContracts;

    constructor(address[] memory associatedContracts) internal {
        // This contract is abstract, and thus cannot be instantiated directly
        require(owner != address(0), "Owner must be set");

        _addAssociatedContracts(associatedContracts);
    }

    /* ========== SETTERS ========== */

    function _addAssociatedContracts(address[] memory associatedContracts) internal {
        for (uint i = 0; i < associatedContracts.length; i++) {
            if (!_associatedContracts.contains(associatedContracts[i])) {
                _associatedContracts.add(associatedContracts[i]);
                emit AssociatedContractAdded(associatedContracts[i]);
            }
        }
    }

    // Add associated contracts
    function addAssociatedContracts(address[] calldata associatedContracts) external onlyOwner {
        _addAssociatedContracts(associatedContracts);
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

    /* ========== MODIFIERS ========== */

    modifier onlyAssociatedContracts {
        require(_associatedContracts.contains(msg.sender), "Only an associated contract can perform this action");
        _;
    }

    /* ========== EVENTS ========== */

    event AssociatedContractAdded(address associatedContract);
    event AssociatedContractRemoved(address associatedContract);
}


// Inheritance


// Libraries


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketState
contract PerpsV2MarketState is Owned, StateShared, IPerpsV2MarketBaseTypes {
    using AddressSetLib for AddressSetLib.AddressSet;

    // The market identifier in the perpsV2 system (manager + settings). Multiple markets can co-exist
    // for the same asset in order to allow migrations.
    bytes32 public marketKey;

    // The asset being traded in this market. This should be a valid key into the ExchangeRates contract.
    bytes32 public baseAsset;

    // The total number of base units in long and short positions.
    uint128 public marketSize;

    /*
     * The net position in base units of the whole market.
     * When this is positive, longs outweigh shorts. When it is negative, shorts outweigh longs.
     */
    int128 public marketSkew;

    /*
     * This holds the value: sum_{p in positions}{p.margin - p.size * (p.lastPrice + fundingSequence[p.lastFundingIndex])}
     * Then marketSkew * (price + _nextFundingEntry()) + _entryDebtCorrection yields the total system debt,
     * which is equivalent to the sum of remaining margins in all positions.
     */
    int128 internal _entryDebtCorrection;

    /*
     * The funding sequence allows constant-time calculation of the funding owed to a given position.
     * Each entry in the sequence holds the net funding accumulated per base unit since the market was created.
     * Then to obtain the net funding over a particular interval, subtract the start point's sequence entry
     * from the end point's sequence entry.
     * Positions contain the funding sequence entry at the time they were confirmed; so to compute
     * the net funding on a given position, obtain from this sequence the net funding per base unit
     * since the position was confirmed and multiply it by the position size.
     */
    uint32 public fundingLastRecomputed;
    int128[] public fundingSequence;

    /*
     * The funding rate last time it was recomputed. The market funding rate floats and requires the previously
     * calculated funding rate, time, and current market conditions to derive the next.
     */
    int128 public fundingRateLastRecomputed;

    /*
     * Each user's position. Multiple positions can always be merged, so each user has
     * only have one position at a time.
     */
    mapping(address => Position) public positions;

    // The set of all addresses (positions) .
    AddressSetLib.AddressSet internal _positionAddresses;

    // The set of all addresses (delayedOrders) .
    AddressSetLib.AddressSet internal _delayedOrderAddresses;

    // This increments for each position; zero reflects a position that does not exist.
    uint64 internal _nextPositionId = 1;

    /// @dev Holds a mapping of accounts to orders. Only one order per account is supported
    mapping(address => DelayedOrder) public delayedOrders;

    constructor(
        address _owner,
        address[] memory _associatedContracts,
        bytes32 _baseAsset,
        bytes32 _marketKey
    ) public Owned(_owner) StateShared(_associatedContracts) {
        baseAsset = _baseAsset;
        marketKey = _marketKey;

        // Initialise the funding sequence with 0 initially accrued, so that the first usable funding index is 1.
        fundingSequence.push(0);

        fundingRateLastRecomputed = 0;
    }

    function entryDebtCorrection() external view returns (int128) {
        return _entryDebtCorrection;
    }

    function nextPositionId() external view returns (uint64) {
        return _nextPositionId;
    }

    function fundingSequenceLength() external view returns (uint) {
        return fundingSequence.length;
    }

    function getPositionAddressesPage(uint index, uint pageSize)
        external
        view
        onlyAssociatedContracts
        returns (address[] memory)
    {
        return _positionAddresses.getPage(index, pageSize);
    }

    function getDelayedOrderAddressesPage(uint index, uint pageSize)
        external
        view
        onlyAssociatedContracts
        returns (address[] memory)
    {
        return _delayedOrderAddresses.getPage(index, pageSize);
    }

    function getPositionAddressesLength() external view onlyAssociatedContracts returns (uint) {
        return _positionAddresses.elements.length;
    }

    function getDelayedOrderAddressesLength() external view onlyAssociatedContracts returns (uint) {
        return _delayedOrderAddresses.elements.length;
    }

    function setMarketKey(bytes32 _marketKey) external onlyAssociatedContracts {
        require(marketKey == bytes32(0) || _marketKey == marketKey, "Cannot change market key");
        marketKey = _marketKey;
    }

    function setBaseAsset(bytes32 _baseAsset) external onlyAssociatedContracts {
        require(baseAsset == bytes32(0) || _baseAsset == baseAsset, "Cannot change base asset");
        baseAsset = _baseAsset;
    }

    function setMarketSize(uint128 _marketSize) external onlyAssociatedContracts {
        marketSize = _marketSize;
    }

    function setEntryDebtCorrection(int128 entryDebtCorrection) external onlyAssociatedContracts {
        _entryDebtCorrection = entryDebtCorrection;
    }

    function setNextPositionId(uint64 nextPositionId) external onlyAssociatedContracts {
        _nextPositionId = nextPositionId;
    }

    function setMarketSkew(int128 _marketSkew) external onlyAssociatedContracts {
        marketSkew = _marketSkew;
    }

    function setFundingLastRecomputed(uint32 lastRecomputed) external onlyAssociatedContracts {
        fundingLastRecomputed = lastRecomputed;
    }

    function pushFundingSequence(int128 _fundingSequence) external onlyAssociatedContracts {
        fundingSequence.push(_fundingSequence);
    }

    // TODO: Perform this update when maxFundingVelocity and skewScale are modified.
    function setFundingRateLastRecomputed(int128 _fundingRateLastRecomputed) external onlyAssociatedContracts {
        fundingRateLastRecomputed = _fundingRateLastRecomputed;
    }

    /**
     * @notice Set the position of a given account
     * @dev Only the associated contract may call this.
     * @param account The account whose value to set.
     * @param id position id.
     * @param lastFundingIndex position lastFundingIndex.
     * @param margin position margin.
     * @param lastPrice position lastPrice.
     * @param size position size.
     */
    function updatePosition(
        address account,
        uint64 id,
        uint64 lastFundingIndex,
        uint128 margin,
        uint128 lastPrice,
        int128 size
    ) external onlyAssociatedContracts {
        positions[account] = Position(id, lastFundingIndex, margin, lastPrice, size);
        _positionAddresses.add(account);
    }

    /**
     * @notice Store a delayed order at the specified account
     * @dev Only the associated contract may call this.
     * @param account The account whose value to set.
     * @param sizeDelta Difference in position to pass to modifyPosition
     * @param priceImpactDelta Price impact tolerance as a percentage used on fillPrice at execution
     * @param targetRoundId Price oracle roundId using which price this order needs to executed
     * @param commitDeposit The commitDeposit paid upon submitting that needs to be refunded if order succeeds
     * @param keeperDeposit The keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
     * @param executableAtTime The timestamp at which this order is executable at
     * @param isOffchain Flag indicating if the order is offchain
     * @param trackingCode Tracking code to emit on execution for volume source fee sharing
     */
    function updateDelayedOrder(
        address account,
        bool isOffchain,
        int128 sizeDelta,
        uint128 priceImpactDelta,
        uint128 targetRoundId,
        uint128 commitDeposit,
        uint128 keeperDeposit,
        uint256 executableAtTime,
        uint256 intentionTime,
        bytes32 trackingCode
    ) external onlyAssociatedContracts {
        delayedOrders[account] = DelayedOrder(
            isOffchain,
            sizeDelta,
            priceImpactDelta,
            targetRoundId,
            commitDeposit,
            keeperDeposit,
            executableAtTime,
            intentionTime,
            trackingCode
        );
        _delayedOrderAddresses.add(account);
    }

    /**
     * @notice Delete the position of a given account
     * @dev Only the associated contract may call this.
     * @param account The account whose position should be deleted.
     */
    function deletePosition(address account) external onlyAssociatedContracts {
        delete positions[account];
        if (_positionAddresses.contains(account)) {
            _positionAddresses.remove(account);
        }
    }

    function deleteDelayedOrder(address account) external onlyAssociatedContracts {
        delete delayedOrders[account];
        if (_delayedOrderAddresses.contains(account)) {
            _delayedOrderAddresses.remove(account);
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


// SPDX-License-Identifier: MIT

/*
The MIT License (MIT)

Copyright (c) 2016-2020 zOS Global Limited

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*
 * When we upgrade to solidity v0.6.0 or above, we should be able to
 * just do import `"openzeppelin-solidity-3.0.0/contracts/math/SignedSafeMath.sol";`
 * wherever this is used.
 */


/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 private constant _INT256_MIN = -2**255;

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


// TODO: Test suite

// https://docs.synthetix.io/contracts/SignedSafeDecimalMath
library SignedSafeDecimalMath {
    using SignedSafeMath for int;

    /* Number of decimal places in the representations. */
    uint8 public constant decimals = 18;
    uint8 public constant highPrecisionDecimals = 27;

    /* The number representing 1.0. */
    int public constant UNIT = int(10**uint(decimals));

    /* The number representing 1.0 for higher fidelity numbers. */
    int public constant PRECISE_UNIT = int(10**uint(highPrecisionDecimals));
    int private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = int(10**uint(highPrecisionDecimals - decimals));

    /**
     * @return Provides an interface to UNIT.
     */
    function unit() external pure returns (int) {
        return UNIT;
    }

    /**
     * @return Provides an interface to PRECISE_UNIT.
     */
    function preciseUnit() external pure returns (int) {
        return PRECISE_UNIT;
    }

    /**
     * @dev Rounds an input with an extra zero of precision, returning the result without the extra zero.
     * Half increments round away from zero; positive numbers at a half increment are rounded up,
     * while negative such numbers are rounded down. This behaviour is designed to be consistent with the
     * unsigned version of this library (SafeDecimalMath).
     */
    function _roundDividingByTen(int valueTimesTen) private pure returns (int) {
        int increment;
        if (valueTimesTen % 10 >= 5) {
            increment = 10;
        } else if (valueTimesTen % 10 <= -5) {
            increment = -10;
        }
        return (valueTimesTen + increment) / 10;
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
    function multiplyDecimal(int x, int y) internal pure returns (int) {
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
        int x,
        int y,
        int precisionUnit
    ) private pure returns (int) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        int quotientTimesTen = x.mul(y) / (precisionUnit / 10);
        return _roundDividingByTen(quotientTimesTen);
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
    function multiplyDecimalRoundPrecise(int x, int y) internal pure returns (int) {
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
    function multiplyDecimalRound(int x, int y) internal pure returns (int) {
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
    function divideDecimal(int x, int y) internal pure returns (int) {
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
        int x,
        int y,
        int precisionUnit
    ) private pure returns (int) {
        int resultTimesTen = x.mul(precisionUnit * 10).div(y);
        return _roundDividingByTen(resultTimesTen);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * standard precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and the standard precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function divideDecimalRound(int x, int y) internal pure returns (int) {
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
    function divideDecimalRoundPrecise(int x, int y) internal pure returns (int) {
        return _divideDecimalRound(x, y, PRECISE_UNIT);
    }

    /**
     * @dev Convert a standard decimal representation to a high precision one.
     */
    function decimalToPreciseDecimal(int i) internal pure returns (int) {
        return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
    }

    /**
     * @dev Convert a high precision decimal to a standard decimal representation.
     */
    function preciseDecimalToDecimal(int i) internal pure returns (int) {
        int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);
        return _roundDividingByTen(quotientTimesTen);
    }
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


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketState
interface IPerpsV2MarketState {
    function marketKey() external view returns (bytes32);

    function baseAsset() external view returns (bytes32);

    function marketSize() external view returns (uint128);

    function marketSkew() external view returns (int128);

    function fundingLastRecomputed() external view returns (uint32);

    function fundingSequence(uint) external view returns (int128);

    function fundingRateLastRecomputed() external view returns (int128);

    function positions(address) external view returns (IPerpsV2MarketBaseTypes.Position memory);

    function delayedOrders(address) external view returns (IPerpsV2MarketBaseTypes.DelayedOrder memory);

    function entryDebtCorrection() external view returns (int128);

    function nextPositionId() external view returns (uint64);

    function fundingSequenceLength() external view returns (uint);

    function getPositionAddressesPage(uint, uint) external view returns (address[] memory);

    function getDelayedOrderAddressesPage(uint, uint) external view returns (address[] memory);

    function getPositionAddressesLength() external view returns (uint);

    function getDelayedOrderAddressesLength() external view returns (uint);

    function setMarketKey(bytes32) external;

    function setBaseAsset(bytes32) external;

    function setMarketSize(uint128) external;

    function setEntryDebtCorrection(int128) external;

    function setNextPositionId(uint64) external;

    function setMarketSkew(int128) external;

    function setFundingLastRecomputed(uint32) external;

    function setFundingRateLastRecomputed(int128 _fundingRateLastRecomputed) external;

    function pushFundingSequence(int128) external;

    function updatePosition(
        address account,
        uint64 id,
        uint64 lastFundingIndex,
        uint128 margin,
        uint128 lastPrice,
        int128 size
    ) external;

    function updateDelayedOrder(
        address account,
        bool isOffchain,
        int128 sizeDelta,
        uint128 priceImpactDelta,
        uint128 targetRoundId,
        uint128 commitDeposit,
        uint128 keeperDeposit,
        uint256 executableAtTime,
        uint256 intentionTime,
        bytes32 trackingCode
    ) external;

    function deletePosition(address) external;

    function deleteDelayedOrder(address) external;
}


// Inheritance


// Libraries


// Internal references


// Internal references


// Use internal interface (external functions not present in IFuturesMarketManager)
interface IFuturesMarketManagerInternal {
    function issueSUSD(address account, uint amount) external;

    function burnSUSD(address account, uint amount) external returns (uint postReclamationAmount);

    function payFee(uint amount) external;
}

// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketBase
contract PerpsV2MarketBase is Owned, MixinPerpsV2MarketSettings, IPerpsV2MarketBaseTypes {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;
    using SafeDecimalMath for uint;
    using SignedSafeMath for int;
    using SignedSafeDecimalMath for int;

    /* ========== CONSTANTS ========== */

    // This is the same unit as used inside `SignedSafeDecimalMath`.
    int private constant _UNIT = int(10**uint(18));

    //slither-disable-next-line naming-convention
    bytes32 internal constant sUSD = "sUSD";

    /* ========== STATE VARIABLES ========== */

    IPerpsV2MarketState public marketState;

    /* ---------- Address Resolver Configuration ---------- */

    // bytes32 internal constant CONTRACT_CIRCUIT_BREAKER = "ExchangeCircuitBreaker";
    bytes32 private constant CONTRACT_EXRATES = "ExchangeRates";
    bytes32 internal constant CONTRACT_EXCHANGER = "Exchanger";
    bytes32 internal constant CONTRACT_SYSTEMSTATUS = "SystemStatus";
    bytes32 internal constant CONTRACT_FUTURESMARKETMANAGER = "FuturesMarketManager";
    bytes32 internal constant CONTRACT_PERPSV2MARKETSETTINGS = "PerpsV2MarketSettings";
    bytes32 internal constant CONTRACT_PERPSV2EXCHANGERATE = "PerpsV2ExchangeRate";

    // Holds the revert message for each type of error.
    mapping(uint8 => string) internal _errorMessages;

    // convenience struct for passing params between position modification helper functions
    struct TradeParams {
        int sizeDelta;
        uint oraclePrice;
        uint fillPrice;
        uint takerFee;
        uint makerFee;
        uint priceImpactDelta;
        bytes32 trackingCode; // optional tracking code for volume source fee sharing
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _marketState,
        address _owner,
        address _resolver
    ) public MixinPerpsV2MarketSettings(_resolver) Owned(_owner) {
        marketState = IPerpsV2MarketState(_marketState);

        // Set up the mapping between error codes and their revert messages.
        _errorMessages[uint8(Status.InvalidPrice)] = "Invalid price";
        _errorMessages[uint8(Status.InvalidOrderType)] = "Invalid order type";
        _errorMessages[uint8(Status.PriceOutOfBounds)] = "Price out of acceptable range";
        _errorMessages[uint8(Status.CanLiquidate)] = "Position can be liquidated";
        _errorMessages[uint8(Status.CannotLiquidate)] = "Position cannot be liquidated";
        _errorMessages[uint8(Status.MaxMarketSizeExceeded)] = "Max market size exceeded";
        _errorMessages[uint8(Status.MaxLeverageExceeded)] = "Max leverage exceeded";
        _errorMessages[uint8(Status.InsufficientMargin)] = "Insufficient margin";
        _errorMessages[uint8(Status.NotPermitted)] = "Not permitted by this address";
        _errorMessages[uint8(Status.NilOrder)] = "Cannot submit empty order";
        _errorMessages[uint8(Status.NoPositionOpen)] = "No position open";
        _errorMessages[uint8(Status.PriceTooVolatile)] = "Price too volatile";
        _errorMessages[uint8(Status.PriceImpactToleranceExceeded)] = "Price impact exceeded";
    }

    /* ---------- External Contracts ---------- */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinPerpsV2MarketSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](6);
        newAddresses[0] = CONTRACT_EXCHANGER;
        newAddresses[1] = CONTRACT_EXRATES;
        newAddresses[2] = CONTRACT_SYSTEMSTATUS;
        newAddresses[3] = CONTRACT_FUTURESMARKETMANAGER;
        newAddresses[4] = CONTRACT_PERPSV2MARKETSETTINGS;
        newAddresses[5] = CONTRACT_PERPSV2EXCHANGERATE;
        // newAddresses[1] = CONTRACT_CIRCUIT_BREAKER;
        addresses = combineArrays(existingAddresses, newAddresses);
    }

    // function _exchangeCircuitBreaker() internal view returns (IExchangeCircuitBreaker) {
    //     return IExchangeCircuitBreaker(requireAndGetAddress(CONTRACT_CIRCUIT_BREAKER));
    // }

    function _exchangeRates() internal view returns (IExchangeRates) {
        return IExchangeRates(requireAndGetAddress(CONTRACT_EXRATES));
    }

    function _exchanger() internal view returns (IExchanger) {
        return IExchanger(requireAndGetAddress(CONTRACT_EXCHANGER));
    }

    function _systemStatus() internal view returns (ISystemStatus) {
        return ISystemStatus(requireAndGetAddress(CONTRACT_SYSTEMSTATUS));
    }

    function _manager() internal view returns (IFuturesMarketManagerInternal) {
        return IFuturesMarketManagerInternal(requireAndGetAddress(CONTRACT_FUTURESMARKETMANAGER));
    }

    function _settings() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_PERPSV2MARKETSETTINGS);
    }

    /* ---------- Market Details ---------- */
    function _baseAsset() internal view returns (bytes32) {
        return marketState.baseAsset();
    }

    function _marketKey() internal view returns (bytes32) {
        return marketState.marketKey();
    }

    /*
     * Returns the pSkew = skew / skewScale capping the pSkew between [-1, 1].
     */
    function _proportionalSkew() internal view returns (int) {
        int pSkew = int(marketState.marketSkew()).divideDecimal(int(_skewScale(_marketKey())));

        // Ensures the proportionalSkew is between -1 and 1.
        return _min(_max(-_UNIT, pSkew), _UNIT);
    }

    function _proportionalElapsed() internal view returns (int) {
        return int(block.timestamp.sub(marketState.fundingLastRecomputed())).divideDecimal(1 days);
    }

    function _currentFundingVelocity() internal view returns (int) {
        int maxFundingVelocity = int(_maxFundingVelocity(_marketKey()));
        return _proportionalSkew().multiplyDecimal(maxFundingVelocity);
    }

    /*
     * @dev Retrieves the _current_ funding rate given the current market conditions.
     *
     * This is used during funding computation _before_ the market is modified (e.g. closing or
     * opening a position). However, called via the `currentFundingRate` view, will return the
     * 'instantaneous' funding rate. It's similar but subtle in that velocity now includes the most
     * recent skew modification.
     *
     * There is no variance in computation but will be affected based on outside modifications to
     * the market skew, max funding velocity, price, and time delta.
     */
    function _currentFundingRate() internal view returns (int) {
        // calculations:
        //  - velocity          = proportional_skew * max_funding_velocity
        //  - proportional_skew = skew / skew_scale
        //
        // example:
        //  - prev_funding_rate     = 0
        //  - prev_velocity         = 0.0025
        //  - time_delta            = 29,000s
        //  - max_funding_velocity  = 0.025 (2.5%)
        //  - skew                  = 300
        //  - skew_scale            = 10,000
        //
        // note: prev_velocity just refs to the velocity _before_ modifying the market skew.
        //
        // funding_rate = prev_funding_rate + prev_velocity * (time_delta / seconds_in_day)
        // funding_rate = 0 + 0.0025 * (29,000 / 86,400)
        //              = 0 + 0.0025 * 0.33564815
        //              = 0.00083912
        return
            int(marketState.fundingRateLastRecomputed()).add(
                _currentFundingVelocity().multiplyDecimal(_proportionalElapsed())
            );
    }

    function _unrecordedFunding(uint price) internal view returns (int) {
        int nextFundingRate = _currentFundingRate();
        // note the minus sign: funding flows in the opposite direction to the skew.
        int avgFundingRate = -(int(marketState.fundingRateLastRecomputed()).add(nextFundingRate)).divideDecimal(_UNIT * 2);
        return avgFundingRate.multiplyDecimal(_proportionalElapsed()).multiplyDecimal(int(price));
    }

    /*
     * The new entry in the funding sequence, appended when funding is recomputed. It is the sum of the
     * last entry and the unrecorded funding, so the sequence accumulates running total over the market's lifetime.
     */
    function _nextFundingEntry(uint price) internal view returns (int) {
        return int(marketState.fundingSequence(_latestFundingIndex())).add(_unrecordedFunding(price));
    }

    function _netFundingPerUnit(uint startIndex, uint price) internal view returns (int) {
        // Compute the net difference between start and end indices.
        return _nextFundingEntry(price).sub(marketState.fundingSequence(startIndex));
    }

    /* ---------- Position Details ---------- */

    /*
     * Determines whether a change in a position's size would violate the max market value constraint.
     */
    function _orderSizeTooLarge(
        uint maxSize,
        int oldSize,
        int newSize
    ) internal view returns (bool) {
        // Allow users to reduce an order no matter the market conditions.
        if (_sameSide(oldSize, newSize) && _abs(newSize) <= _abs(oldSize)) {
            return false;
        }

        // Either the user is flipping sides, or they are increasing an order on the same side they're already on;
        // we check that the side of the market their order is on would not break the limit.
        int newSkew = int(marketState.marketSkew()).sub(oldSize).add(newSize);
        int newMarketSize = int(marketState.marketSize()).sub(_signedAbs(oldSize)).add(_signedAbs(newSize));

        int newSideSize;
        if (0 < newSize) {
            // long case: marketSize + skew
            //            = (|longSize| + |shortSize|) + (longSize + shortSize)
            //            = 2 * longSize
            newSideSize = newMarketSize.add(newSkew);
        } else {
            // short case: marketSize - skew
            //            = (|longSize| + |shortSize|) - (longSize + shortSize)
            //            = 2 * -shortSize
            newSideSize = newMarketSize.sub(newSkew);
        }

        // newSideSize still includes an extra factor of 2 here, so we will divide by 2 in the actual condition
        if (maxSize < _abs(newSideSize.div(2))) {
            return true;
        }

        return false;
    }

    function _notionalValue(int positionSize, uint price) internal pure returns (int value) {
        return positionSize.multiplyDecimal(int(price));
    }

    function _profitLoss(Position memory position, uint price) internal pure returns (int pnl) {
        int priceShift = int(price).sub(int(position.lastPrice));
        return int(position.size).multiplyDecimal(priceShift);
    }

    function _accruedFunding(Position memory position, uint price) internal view returns (int funding) {
        uint lastModifiedIndex = position.lastFundingIndex;
        if (lastModifiedIndex == 0) {
            return 0; // The position does not exist -- no funding.
        }
        int net = _netFundingPerUnit(lastModifiedIndex, price);
        return int(position.size).multiplyDecimal(net);
    }

    /*
     * The initial margin of a position, plus any PnL and funding it has accrued. The resulting value may be negative.
     */
    function _marginPlusProfitFunding(Position memory position, uint price) internal view returns (int) {
        int funding = _accruedFunding(position, price);
        return int(position.margin).add(_profitLoss(position, price)).add(funding);
    }

    /*
     * The value in a position's margin after a deposit or withdrawal, accounting for funding and profit.
     * If the resulting margin would be negative or below the liquidation threshold, an appropriate error is returned.
     * If the result is not an error, callers of this function that use it to update a position's margin
     * must ensure that this is accompanied by a corresponding debt correction update, as per `_applyDebtCorrection`.
     */
    function _recomputeMarginWithDelta(
        Position memory position,
        uint price,
        int marginDelta
    ) internal view returns (uint margin, Status statusCode) {
        int newMargin = _marginPlusProfitFunding(position, price).add(marginDelta);
        if (newMargin < 0) {
            return (0, Status.InsufficientMargin);
        }

        uint uMargin = uint(newMargin);
        int positionSize = int(position.size);
        // minimum margin beyond which position can be liquidated
        uint lMargin = _liquidationMargin(positionSize, price);
        if (positionSize != 0 && uMargin <= lMargin) {
            return (uMargin, Status.CanLiquidate);
        }

        return (uMargin, Status.Ok);
    }

    function _remainingMargin(Position memory position, uint price) internal view returns (uint) {
        int remaining = _marginPlusProfitFunding(position, price);

        // If the margin went past zero, the position should have been liquidated - return zero remaining margin.
        return uint(_max(0, remaining));
    }

    /*
     * @dev Similar to _remainingMargin except it accounts for the premium to be paid upon liquidation.
     */
    function _remainingLiquidatableMargin(Position memory position, uint price) internal view returns (uint) {
        int remaining = _marginPlusProfitFunding(position, price).sub(int(_liquidationPremium(position.size, price)));
        return uint(_max(0, remaining));
    }

    function _accessibleMargin(Position memory position, uint price) internal view returns (uint) {
        // Ugly solution to rounding safety: leave up to an extra tenth of a cent in the account/leverage
        // This should guarantee that the value returned here can always be withdrawn, but there may be
        // a little extra actually-accessible value left over, depending on the position size and margin.
        uint milli = uint(_UNIT / 1000);
        int maxLeverage = int(_maxLeverage(_marketKey()).sub(milli));
        uint inaccessible = _abs(_notionalValue(position.size, price).divideDecimal(maxLeverage));

        // If the user has a position open, we'll enforce a min initial margin requirement.
        if (0 < inaccessible) {
            uint minInitialMargin = _minInitialMargin();
            if (inaccessible < minInitialMargin) {
                inaccessible = minInitialMargin;
            }
            inaccessible = inaccessible.add(milli);
        }

        uint remaining = _remainingMargin(position, price);
        if (remaining <= inaccessible) {
            return 0;
        }

        return remaining.sub(inaccessible);
    }

    /**
     * The fee charged from the margin during liquidation. Fee is proportional to position size
     * but is between _minKeeperFee() and _maxKeeperFee() expressed in sUSD to prevent underincentivising
     * liquidations of small positions, or overpaying.
     * @param positionSize size of position in fixed point decimal baseAsset units
     * @param price price of single baseAsset unit in sUSD fixed point decimal units
     * @return lFee liquidation fee to be paid to liquidator in sUSD fixed point decimal units
     */
    function _liquidationFee(int positionSize, uint price) internal view returns (uint lFee) {
        // size * price * fee-ratio
        uint proportionalFee = _abs(positionSize).multiplyDecimal(price).multiplyDecimal(_liquidationFeeRatio());
        uint maxFee = _maxKeeperFee();
        uint cappedProportionalFee = proportionalFee > maxFee ? maxFee : proportionalFee;
        uint minFee = _minKeeperFee();

        // max(proportionalFee, minFee) - to prevent not incentivising liquidations enough
        return cappedProportionalFee > minFee ? cappedProportionalFee : minFee; // not using _max() helper because it's for signed ints
    }

    /**
     * The minimal margin at which liquidation can happen. Is the sum of liquidationBuffer and liquidationFee
     * @param positionSize size of position in fixed point decimal baseAsset units
     * @param price price of single baseAsset unit in sUSD fixed point decimal units
     * @return lMargin liquidation margin to maintain in sUSD fixed point decimal units
     * @dev The liquidation margin contains a buffer that is proportional to the position
     * size. The buffer should prevent liquidation happening at negative margin (due to next price being worse)
     * so that stakers would not leak value to liquidators through minting rewards that are not from the
     * account's margin.
     */
    function _liquidationMargin(int positionSize, uint price) internal view returns (uint lMargin) {
        uint liquidationBuffer = _abs(positionSize).multiplyDecimal(price).multiplyDecimal(_liquidationBufferRatio());
        return liquidationBuffer.add(_liquidationFee(positionSize, price));
    }

    /**
     * @dev This is the additional premium we charge upon liquidation.
     *
     * Similar to fillPrice, but we disregard the skew (by assuming it's zero). Which is basically the calculation
     * when we compute as if taking the position from 0 to x. In practice, the premium component of the
     * liquidation will just be (size / skewScale) * (size * price).
     *
     * It adds a configurable multiplier that can be used to increase the margin that goes to feePool.
     *
     * For instance, if size of the liquidation position is 100, oracle price is 1200 and skewScale is 1M then,
     *
     *  size    = abs(-100)
     *          = 100
     *  premium = 100 / 1000000 * (100 * 1200) * multiplier
     *          = 12 * multiplier
     *  if multiplier is set to 1
     *          = 12 * 1 = 12
     *
     * @param positionSize Size of the position we want to liquidate
     * @param currentPrice The current oracle price (not fillPrice)
     * @return The premium to be paid upon liquidation in sUSD
     */
    function _liquidationPremium(int positionSize, uint currentPrice) internal view returns (uint) {
        if (positionSize == 0) {
            return 0;
        }

        // note: this is the same as fillPrice() where the skew is 0.
        uint notional = _abs(_notionalValue(positionSize, currentPrice));

        return
            _abs(positionSize).divideDecimal(_skewScale(_marketKey())).multiplyDecimal(notional).multiplyDecimal(
                _liquidationPremiumMultiplier(_marketKey())
            );
    }

    function _canLiquidate(Position memory position, uint price) internal view returns (bool) {
        // No liquidating empty positions.
        if (position.size == 0) {
            return false;
        }

        return _remainingLiquidatableMargin(position, price) <= _liquidationMargin(int(position.size), price);
    }

    function _currentLeverage(
        Position memory position,
        uint price,
        uint remainingMargin_
    ) internal pure returns (int leverage) {
        // No position is open, or it is ready to be liquidated; leverage goes to nil
        if (remainingMargin_ == 0) {
            return 0;
        }

        return _notionalValue(position.size, price).divideDecimal(int(remainingMargin_));
    }

    function _orderFee(TradeParams memory params, uint dynamicFeeRate) internal view returns (uint fee) {
        // usd value of the difference in position (using the p/d-adjusted price).
        int marketSkew = marketState.marketSkew();
        int notionalDiff = params.sizeDelta.multiplyDecimal(int(params.fillPrice));

        // minimum fee to pay regardless (due to dynamic fees).
        uint baseFee = _abs(notionalDiff).multiplyDecimal(dynamicFeeRate);

        // does this trade keep the skew on one side?
        if (_sameSide(marketSkew + params.sizeDelta, marketSkew)) {
            // use a flat maker/taker fee for the entire size depending on whether the skew is increased or reduced.
            //
            // if the order is submitted on the same side as the skew (increasing it) - the taker fee is charged.
            // otherwise if the order is opposite to the skew, the maker fee is charged.
            uint staticRate = _sameSide(notionalDiff, marketState.marketSkew()) ? params.takerFee : params.makerFee;
            return baseFee + _abs(notionalDiff.multiplyDecimal(int(staticRate)));
        }

        // this trade flips the skew.
        //
        // the proportion of size that moves in the direction after the flip should not be considered
        // as a maker (reducing skew) as it's now taking (increasing skew) in the opposite direction. hence,
        // a different fee is applied on the proportion increasing the skew.

        // proportion of size that's on the other direction
        uint takerSize = _abs((marketSkew + params.sizeDelta).divideDecimal(params.sizeDelta));
        uint makerSize = uint(_UNIT) - takerSize;
        uint takerFee = _abs(notionalDiff).multiplyDecimal(takerSize).multiplyDecimal(params.takerFee);
        uint makerFee = _abs(notionalDiff).multiplyDecimal(makerSize).multiplyDecimal(params.makerFee);

        return baseFee + takerFee + makerFee;
    }

    /// Uses the exchanger to get the dynamic fee (SIP-184) for trading from sUSD to baseAsset
    /// this assumes dynamic fee is symmetric in direction of trade.
    /// @dev this is a pretty expensive action in terms of execution gas as it queries a lot
    ///   of past rates from oracle. Shouldn't be much of an issue on a rollup though.
    function _dynamicFeeRate() internal view returns (uint feeRate, bool tooVolatile) {
        return _exchanger().dynamicFeeRateForExchange(sUSD, _baseAsset());
    }

    function _latestFundingIndex() internal view returns (uint) {
        return marketState.fundingSequenceLength().sub(1); // at least one element is pushed in constructor
    }

    function _postTradeDetails(Position memory oldPos, TradeParams memory params)
        internal
        view
        returns (
            Position memory newPosition,
            uint fee,
            Status tradeStatus
        )
    {
        // Reverts if the user is trying to submit a size-zero order.
        if (params.sizeDelta == 0) {
            return (oldPos, 0, Status.NilOrder);
        }

        // The order is not submitted if the user's existing position needs to be liquidated.
        if (_canLiquidate(oldPos, params.oraclePrice)) {
            return (oldPos, 0, Status.CanLiquidate);
        }

        // get the dynamic fee rate SIP-184
        (uint dynamicFeeRate, bool tooVolatile) = _dynamicFeeRate();
        if (tooVolatile) {
            return (oldPos, 0, Status.PriceTooVolatile);
        }

        // calculate the total fee for exchange
        fee = _orderFee(params, dynamicFeeRate);

        // Deduct the fee.
        // It is an error if the realised margin minus the fee is negative or subject to liquidation.
        (uint newMargin, Status status) = _recomputeMarginWithDelta(oldPos, params.fillPrice, -int(fee));
        if (_isError(status)) {
            return (oldPos, 0, status);
        }

        // construct new position
        Position memory newPos =
            Position({
                id: oldPos.id,
                lastFundingIndex: uint64(_latestFundingIndex()),
                margin: uint128(newMargin),
                lastPrice: uint128(params.fillPrice),
                size: int128(int(oldPos.size).add(params.sizeDelta))
            });

        // always allow to decrease a position, otherwise a margin of minInitialMargin can never
        // decrease a position as the price goes against them.
        // we also add the paid out fee for the minInitialMargin because otherwise minInitialMargin
        // is never the actual minMargin, because the first trade will always deduct
        // a fee (so the margin that otherwise would need to be transferred would have to include the future
        // fee as well, making the UX and definition of min-margin confusing).
        bool positionDecreasing = _sameSide(oldPos.size, newPos.size) && _abs(newPos.size) < _abs(oldPos.size);
        if (!positionDecreasing) {
            // minMargin + fee <= margin is equivalent to minMargin <= margin - fee
            // except that we get a nicer error message if fee > margin, rather than arithmetic overflow.
            if (uint(newPos.margin).add(fee) < _minInitialMargin()) {
                return (oldPos, 0, Status.InsufficientMargin);
            }
        }

        // check that new position margin is above liquidation margin
        // (above, in _recomputeMarginWithDelta() we checked the old position, here we check the new one)
        //
        // Liquidation margin is considered without a fee (but including premium), because it wouldn't make sense to allow
        // a trade that will make the position liquidatable.
        //
        // note: we use `oraclePrice` here as `liquidationPremium` calcs premium based not current skew.
        uint liqPremium = _liquidationPremium(newPos.size, params.oraclePrice);
        uint liqMargin = _liquidationMargin(newPos.size, params.oraclePrice).add(liqPremium);
        if (newMargin <= liqMargin) {
            return (newPos, 0, Status.CanLiquidate);
        }

        // Check that the maximum leverage is not exceeded when considering new margin including the paid fee.
        // The paid fee is considered for the benefit of UX of allowed max leverage, otherwise, the actual
        // max leverage is always below the max leverage parameter since the fee paid for a trade reduces the margin.
        // We'll allow a little extra headroom for rounding errors.
        {
            // stack too deep
            int leverage = int(newPos.size).multiplyDecimal(int(params.fillPrice)).divideDecimal(int(newMargin.add(fee)));
            if (_maxLeverage(_marketKey()).add(uint(_UNIT) / 100) < _abs(leverage)) {
                return (oldPos, 0, Status.MaxLeverageExceeded);
            }
        }

        // Check that the order isn't too large for the markets.
        if (_orderSizeTooLarge(_maxMarketValue(_marketKey()), oldPos.size, newPos.size)) {
            return (oldPos, 0, Status.MaxMarketSizeExceeded);
        }

        return (newPos, fee, Status.Ok);
    }

    /* ---------- Utilities ---------- */

    /*
     * The current base price from the oracle, and whether that price was invalid. Zero prices count as invalid.
     * Public because used both externally and internally
     */
    function _assetPrice() internal view returns (uint price, bool invalid) {
        (price, invalid) = _exchangeRates().rateAndInvalid(_baseAsset());
        // Ensure we catch uninitialised rates or suspended state / synth
        invalid = invalid || price == 0 || _systemStatus().synthSuspended(_baseAsset());
        return (price, invalid);
    }

    /*
     * @dev SIP-279 fillPrice price at which a trade is executed against accounting for how this position's
     * size impacts the skew. If the size contracts the skew (reduces) then a discount is applied on the price
     * whereas expanding the skew incurs an additional premium.
     */
    function _fillPrice(int size, uint price) internal view returns (uint) {
        int skew = marketState.marketSkew();
        int skewScale = int(_skewScale(_marketKey()));

        int pdBefore = skew.divideDecimal(skewScale);
        int pdAfter = skew.add(size).divideDecimal(skewScale);
        int priceBefore = int(price).add(int(price).multiplyDecimal(pdBefore));
        int priceAfter = int(price).add(int(price).multiplyDecimal(pdAfter));

        // How is the p/d-adjusted price calculated using an example:
        //
        // price      = $1200 USD (oracle)
        // size       = 100
        // skew       = 0
        // skew_scale = 1,000,000 (1M)
        //
        // Then,
        //
        // pd_before = 0 / 1,000,000
        //           = 0
        // pd_after  = (0 + 100) / 1,000,000
        //           = 100 / 1,000,000
        //           = 0.0001
        //
        // price_before = 1200 * (1 + pd_before)
        //              = 1200 * (1 + 0)
        //              = 1200
        // price_after  = 1200 * (1 + pd_after)
        //              = 1200 * (1 + 0.0001)
        //              = 1200 * (1.0001)
        //              = 1200.12
        // Finally,
        //
        // fill_price = (price_before + price_after) / 2
        //            = (1200 + 1200.12) / 2
        //            = 1200.06
        return uint(priceBefore.add(priceAfter).divideDecimal(_UNIT * 2));
    }

    /*
     * @dev Given the current oracle price (not fillPrice) and priceImpactDelta, return the max priceImpactDelta
     * price which is a price that is inclusive of the priceImpactDelta tolerance.
     *
     * For instance, if price ETH is $1000 and priceImpactDelta is 1% then maxPriceImpact is $1010. The fillPrice
     * on the trade must be below $1010 for the trade to succeed.
     *
     * For clarity when priceImpactDelta is:
     *  0.1   then 10%
     *  0.01  then 1%
     *  0.001 then 0.1%
     *
     * When price is $1000, I long, and priceImpactDelta is:
     *  0.1   then price * (1 + 0.1)   = 1100
     *  0.01  then price * (1 + 0.01)  = 1010
     *  0.001 then price * (1 + 0.001) = 1001
     *
     * When same but short then,
     *  0.1   then price * (1 - 0.1)   = 900
     *  0.01  then price * (1 - 0.01)  = 990
     *  0.001 then price * (1 - 0.001) = 999
     *
     * This forms the limit at which the fillPrice can reach before we revert the trade.
     */
    function _priceImpactLimit(
        uint price,
        uint priceImpactDelta,
        int sizeDelta
    ) internal pure returns (uint) {
        // A lower price would be less desirable for shorts and a higher price is less desirable for longs. As such
        // we derive the maxPriceImpact based on whether the position is going long/short.
        return price.multiplyDecimal(sizeDelta > 0 ? uint(_UNIT).add(priceImpactDelta) : uint(_UNIT).sub(priceImpactDelta));
    }

    /*
     * Absolute value of the input, returned as a signed number.
     */
    function _signedAbs(int x) internal pure returns (int) {
        return x < 0 ? -x : x;
    }

    /*
     * Absolute value of the input, returned as an unsigned number.
     */
    function _abs(int x) internal pure returns (uint) {
        return uint(_signedAbs(x));
    }

    function _max(int x, int y) internal pure returns (int) {
        return x < y ? y : x;
    }

    function _min(int x, int y) internal pure returns (int) {
        return x < y ? x : y;
    }

    // True if and only if two positions a and b are on the same side of the market;
    // that is, if they have the same sign, or either of them is zero.
    function _sameSide(int a, int b) internal pure returns (bool) {
        return (a == 0) || (b == 0) || (a > 0) == (b > 0);
    }

    /*
     * True if and only if the given status indicates an error.
     */
    function _isError(Status status) internal pure returns (bool) {
        return status != Status.Ok;
    }

    /*
     * Revert with an appropriate message if the first argument is true.
     */
    function _revertIfError(bool isError, Status status) internal view {
        if (isError) {
            revert(_errorMessages[uint8(status)]);
        }
    }

    /*
     * Revert with an appropriate message if the input is an error.
     */
    function _revertIfError(Status status) internal view {
        if (_isError(status)) {
            revert(_errorMessages[uint8(status)]);
        }
    }
}


// Inheritance


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketProxyable
contract PerpsV2MarketProxyable is PerpsV2MarketBase, Proxyable {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        address _marketState,
        address _owner,
        address _resolver
    ) public PerpsV2MarketBase(_marketState, _owner, _resolver) Proxyable(_proxy) {}

    /* ---------- Market Operations ---------- */

    /*
     * Alter the debt correction to account for the net result of altering a position.
     */
    function _applyDebtCorrection(Position memory newPosition, Position memory oldPosition) internal {
        int newCorrection = _positionDebtCorrection(newPosition);
        int oldCorrection = _positionDebtCorrection(oldPosition);
        marketState.setEntryDebtCorrection(
            int128(int(marketState.entryDebtCorrection()).add(newCorrection).sub(oldCorrection))
        );
    }

    /*
     * The impact of a given position on the debt correction.
     */
    function _positionDebtCorrection(Position memory position) internal view returns (int) {
        /**
        This method only returns the correction term for the debt calculation of the position, and not it's 
        debt. This is needed for keeping track of the marketDebt() in an efficient manner to allow O(1) marketDebt
        calculation in marketDebt().

        Explanation of the full market debt calculation from the SIP https://sips.synthetix.io/sips/sip-80/:

        The overall market debt is the sum of the remaining margin in all positions. The intuition is that
        the debt of a single position is the value withdrawn upon closing that position.

        single position remaining margin = initial-margin + profit-loss + accrued-funding =
            = initial-margin + q * (price - last-price) + q * funding-accrued-per-unit
            = initial-margin + q * price - q * last-price + q * (funding - initial-funding)

        Total debt = sum ( position remaining margins )
            = sum ( initial-margin + q * price - q * last-price + q * (funding - initial-funding) )
            = sum( q * price ) + sum( q * funding ) + sum( initial-margin - q * last-price - q * initial-funding )
            = skew * price + skew * funding + sum( initial-margin - q * ( last-price + initial-funding ) )
            = skew (price + funding) + sum( initial-margin - q * ( last-price + initial-funding ) )

        The last term: sum( initial-margin - q * ( last-price + initial-funding ) ) being the position debt correction
            that is tracked with each position change using this method. 
        
        The first term and the full debt calculation using current skew, price, and funding is calculated globally in marketDebt().
         */
        return
            int(position.margin).sub(
                int(position.size).multiplyDecimal(
                    int(position.lastPrice).add(marketState.fundingSequence(position.lastFundingIndex))
                )
            );
    }

    /*
     * The current base price, reverting if it is invalid, or if system or synth is suspended.
     * This is mutative because the circuit breaker stores the last price on every invocation.
     */
    function _assetPriceRequireSystemChecks(bool checkOffchainMarket) internal returns (uint) {
        // check that futures market isn't suspended, revert with appropriate message
        _systemStatus().requireFuturesMarketActive(_marketKey()); // asset and market may be different
        // check that synth is active, and wasn't suspended, revert with appropriate message
        _systemStatus().requireSynthActive(_baseAsset());

        if (checkOffchainMarket) {
            // offchain PerpsV2 virtual market
            _systemStatus().requireFuturesMarketActive(_offchainMarketKey(_marketKey()));
        }
        // check if circuit breaker if price is within deviation tolerance and system & synth is active
        // note: rateWithBreakCircuit (mutative) is used here instead of rateWithInvalid (view). This is
        //  despite reverting immediately after if circuit is broken, which may seem silly.
        //  This is in order to persist last-rate in exchangeCircuitBreaker in the happy case
        //  because last-rate is what used for measuring the deviation for subsequent trades.
        (uint price, bool circuitBroken, bool staleOrInvalid) = _exchangeRates().rateWithSafetyChecks(_baseAsset());
        // revert if price is invalid or circuit was broken
        // note: we revert here, which means that circuit is not really broken (is not persisted), this is
        //  because the futures methods and interface are designed for reverts, and do not support no-op
        //  return values.
        _revertIfError(circuitBroken || staleOrInvalid, Status.InvalidPrice);
        return price;
    }

    /*
     * @dev Checks if the fillPrice does not exceed priceImpactDelta tolerance.
     *
     * This will vary depending on the side you're taking. The intuition is if you're short, a discount is negatively
     * impactful to your order but a premium is not. As such, the priceImpactDelta is asserted differently depending
     * on which side of the trade you take.
     */
    function _assertPriceImpact(
        uint price,
        uint fillPrice,
        uint priceImpactDelta,
        int sizeDelta
    ) internal view returns (uint) {
        uint priceImpactLimit = _priceImpactLimit(price, priceImpactDelta, sizeDelta);
        _revertIfError(
            sizeDelta > 0 ? fillPrice > priceImpactLimit : fillPrice < priceImpactLimit,
            Status.PriceImpactToleranceExceeded
        );
        return priceImpactLimit;
    }

    function _recomputeFunding(uint price) internal returns (uint lastIndex) {
        uint sequenceLengthBefore = marketState.fundingSequenceLength();

        int fundingRate = _currentFundingRate();
        int funding = _nextFundingEntry(price);
        marketState.pushFundingSequence(int128(funding));
        marketState.setFundingLastRecomputed(uint32(block.timestamp));
        marketState.setFundingRateLastRecomputed(int128(fundingRate));

        emitFundingRecomputed(funding, fundingRate, sequenceLengthBefore, marketState.fundingLastRecomputed());

        return sequenceLengthBefore;
    }

    // updates the stored position margin in place (on the stored position)
    function _updatePositionMargin(
        address account,
        Position memory position,
        uint price,
        int marginDelta
    ) internal {
        Position memory oldPosition = position;
        // Determine new margin, ensuring that the result is positive.
        (uint margin, Status status) = _recomputeMarginWithDelta(oldPosition, price, marginDelta);
        _revertIfError(status);

        // Update the debt correction.
        int positionSize = position.size;
        uint fundingIndex = _latestFundingIndex();
        _applyDebtCorrection(
            Position(0, uint64(fundingIndex), uint128(margin), uint128(price), int128(positionSize)),
            Position(0, position.lastFundingIndex, position.margin, position.lastPrice, int128(positionSize))
        );

        // Update the account's position with the realised margin.
        position.margin = uint128(margin);
        // We only need to update their funding/PnL details if they actually have a position open
        if (positionSize != 0) {
            position.lastPrice = uint128(price);
            position.lastFundingIndex = uint64(fundingIndex);

            // The user can always decrease their margin if they have no position, or as long as:
            //   * they have sufficient margin to do so
            //   * the resulting margin would not be lower than the liquidation margin or min initial margin
            //     * liqMargin accounting for the liqPremium
            //   * the resulting leverage is lower than the maximum leverage
            if (marginDelta < 0) {
                // note: We .add `liqPremium` to increase the req margin to avoid entering into liquidation
                uint liqPremium = _liquidationPremium(position.size, price);
                uint liqMargin = _liquidationMargin(position.size, price).add(liqPremium);
                _revertIfError(
                    (margin < _minInitialMargin()) ||
                        (margin <= liqMargin) ||
                        (_maxLeverage(_marketKey()) < _abs(_currentLeverage(position, price, margin))),
                    Status.InsufficientMargin
                );
            }
        }

        // persist position changes
        marketState.updatePosition(
            account,
            position.id,
            position.lastFundingIndex,
            position.margin,
            position.lastPrice,
            position.size
        );
    }

    function _trade(address sender, TradeParams memory params) internal {
        Position memory position = marketState.positions(sender);
        Position memory oldPosition =
            Position({
                id: position.id,
                lastFundingIndex: position.lastFundingIndex,
                margin: position.margin,
                lastPrice: position.lastPrice,
                size: position.size
            });

        // Compute the new position after performing the trade
        (Position memory newPosition, uint fee, Status status) = _postTradeDetails(oldPosition, params);
        _revertIfError(status);

        _assertPriceImpact(params.oraclePrice, params.fillPrice, params.priceImpactDelta, params.sizeDelta);

        // Update the aggregated market size and skew with the new order size
        marketState.setMarketSkew(int128(int(marketState.marketSkew()).add(newPosition.size).sub(oldPosition.size)));
        marketState.setMarketSize(
            uint128(uint(marketState.marketSize()).add(_abs(newPosition.size)).sub(_abs(oldPosition.size)))
        );

        // Send the fee to the fee pool
        if (0 < fee) {
            _manager().payFee(fee);
            // emit tracking code event
            if (params.trackingCode != bytes32(0)) {
                emitPerpsTracking(params.trackingCode, _baseAsset(), _marketKey(), params.sizeDelta, fee);
            }
        }

        // Update the margin, and apply the resulting debt correction
        position.margin = newPosition.margin;
        _applyDebtCorrection(newPosition, oldPosition);

        // Record the trade
        uint64 id = oldPosition.id;
        uint fundingIndex = _latestFundingIndex();
        if (newPosition.size == 0) {
            // If the position is being closed, we no longer need to track these details.
            delete position.id;
            delete position.size;
            delete position.lastPrice;
            delete position.lastFundingIndex;
        } else {
            if (oldPosition.size == 0) {
                // New positions get new ids.
                id = marketState.nextPositionId();
                marketState.setNextPositionId(id + 1);
            }
            position.id = id;
            position.size = newPosition.size;
            position.lastPrice = uint128(params.fillPrice);
            position.lastFundingIndex = uint64(fundingIndex);
        }

        // persist position changes
        marketState.updatePosition(
            sender,
            position.id,
            position.lastFundingIndex,
            position.margin,
            position.lastPrice,
            position.size
        );

        // emit the modification event
        emitPositionModified(
            id,
            sender,
            newPosition.margin,
            newPosition.size,
            params.sizeDelta,
            params.fillPrice,
            fundingIndex,
            fee
        );
    }

    /* ========== EVENTS ========== */
    function addressToBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

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
    bytes32 internal constant POSITIONMODIFIED_SIG =
        keccak256("PositionModified(uint256,address,uint256,int256,int256,uint256,uint256,uint256)");

    function emitPositionModified(
        uint id,
        address account,
        uint margin,
        int size,
        int tradeSize,
        uint lastPrice,
        uint fundingIndex,
        uint fee
    ) internal {
        proxy._emit(
            abi.encode(margin, size, tradeSize, lastPrice, fundingIndex, fee),
            3,
            POSITIONMODIFIED_SIG,
            bytes32(id),
            addressToBytes32(account),
            0
        );
    }

    event MarginTransferred(address indexed account, int marginDelta);
    bytes32 internal constant MARGINTRANSFERRED_SIG = keccak256("MarginTransferred(address,int256)");

    function emitMarginTransferred(address account, int marginDelta) internal {
        proxy._emit(abi.encode(marginDelta), 2, MARGINTRANSFERRED_SIG, addressToBytes32(account), 0, 0);
    }

    event PositionLiquidated(uint id, address account, address liquidator, int size, uint price, uint fee);
    bytes32 internal constant POSITIONLIQUIDATED_SIG =
        keccak256("PositionLiquidated(uint256,address,address,int256,uint256,uint256)");

    function emitPositionLiquidated(
        uint id,
        address account,
        address liquidator,
        int size,
        uint price,
        uint fee
    ) internal {
        proxy._emit(abi.encode(id, account, liquidator, size, price, fee), 1, POSITIONLIQUIDATED_SIG, 0, 0, 0);
    }

    event FundingRecomputed(int funding, int fundingRate, uint index, uint timestamp);
    bytes32 internal constant FUNDINGRECOMPUTED_SIG = keccak256("FundingRecomputed(int256,int256,uint256,uint256)");

    function emitFundingRecomputed(
        int funding,
        int fundingRate,
        uint index,
        uint timestamp
    ) internal {
        proxy._emit(abi.encode(funding, fundingRate, index, timestamp), 1, FUNDINGRECOMPUTED_SIG, 0, 0, 0);
    }

    event PerpsTracking(bytes32 indexed trackingCode, bytes32 baseAsset, bytes32 marketKey, int sizeDelta, uint fee);
    bytes32 internal constant PERPSTRACKING_SIG = keccak256("PerpsTracking(bytes32,bytes32,bytes32,int256,uint256)");

    function emitPerpsTracking(
        bytes32 trackingCode,
        bytes32 baseAsset,
        bytes32 marketKey,
        int sizeDelta,
        uint fee
    ) internal {
        proxy._emit(abi.encode(baseAsset, marketKey, sizeDelta, fee), 2, PERPSTRACKING_SIG, trackingCode, 0, 0);
    }
}


// Inheritance


// Reference


/**
 Contract that implements DelayedOrders (base for on-chain and off-chain) mechanism for the PerpsV2 market.
 The purpose of the mechanism is to allow reduced fees for trades that commit to next price instead
 of current price. Specifically, this should serve funding rate arbitrageurs, such that funding rate
 arb is profitable for smaller skews. This in turn serves the protocol by reducing the skew, and so
 the risk to the debt pool, and funding rate for traders.

 The fees can be reduced when committing to next price, because front-running (MEV and oracle delay)
 is less of a risk when committing to next price.

 The relative complexity of the mechanism is due to having to enforce the "commitment" to the trade
 without either introducing free (or cheap) optionality to cause cancellations, and without large
 sacrifices to the UX / risk of the traders (e.g. blocking all actions, or penalizing failures too much).
 */
// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketDelayedOrdersBase
contract PerpsV2MarketDelayedOrdersBase is PerpsV2MarketProxyable {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        address _marketState,
        address _owner,
        address _resolver
    ) public PerpsV2MarketProxyable(_proxy, _marketState, _owner, _resolver) {}

    function delayedOrders(address account) external view returns (DelayedOrder memory) {
        return marketState.delayedOrders(account);
    }

    ///// Mutative methods

    function _submitDelayedOrder(
        bytes32 marketKey,
        int sizeDelta,
        uint priceImpactDelta,
        uint desiredTimeDelta,
        bytes32 trackingCode,
        bool isOffchain
    ) internal {
        // check that a previous order doesn't exist
        require(marketState.delayedOrders(messageSender).sizeDelta == 0, "previous order exists");

        // automatically set desiredTimeDelta to min if 0 is specified
        if (desiredTimeDelta == 0) {
            desiredTimeDelta = _minDelayTimeDelta(marketKey);
        }

        // ensure the desiredTimeDelta is above the minimum required delay
        require(
            desiredTimeDelta >= _minDelayTimeDelta(marketKey) && desiredTimeDelta <= _maxDelayTimeDelta(marketKey),
            "delay out of bounds"
        );

        // storage position as it's going to be modified to deduct commitFee and keeperFee
        Position memory position = marketState.positions(messageSender);

        // to prevent submitting bad orders in good faith and being charged commitDeposit for them
        // simulate the order with current price (+ p/d) and market and check that the order doesn't revert
        uint price = _assetPriceRequireSystemChecks(isOffchain);
        uint fillPrice = _fillPrice(sizeDelta, price);
        uint fundingIndex = _recomputeFunding(price);

        TradeParams memory params =
            TradeParams({
                sizeDelta: sizeDelta,
                oraclePrice: price,
                fillPrice: fillPrice,
                takerFee: isOffchain ? _takerFeeOffchainDelayedOrder(marketKey) : _takerFeeDelayedOrder(marketKey),
                makerFee: isOffchain ? _makerFeeOffchainDelayedOrder(marketKey) : _makerFeeDelayedOrder(marketKey),
                priceImpactDelta: priceImpactDelta,
                trackingCode: trackingCode
            });

        // stack too deep
        {
            (, , Status status) = _postTradeDetails(position, params);
            _revertIfError(status);
        }

        // deduct fees from margin
        //
        // commitDeposit is simply the maker/taker fee. note the dynamic fee rate is 0 since for the purposes of the
        // commitment deposit it is not important since at the time of the order execution it will be refunded and the
        // correct dynamic fee will be charged.
        // If the overrideCommitFee is set (value > 0) use this one instead.
        uint commitDeposit = _overrideCommitFee(marketKey) > 0 ? _overrideCommitFee(marketKey) : _orderFee(params, 0);
        uint keeperDeposit = _minKeeperFee();

        _updatePositionMargin(messageSender, position, fillPrice, -int(commitDeposit + keeperDeposit));
        emitPositionModified(position.id, messageSender, position.margin, position.size, 0, fillPrice, fundingIndex, 0);

        uint targetRoundId = _exchangeRates().getCurrentRoundId(_baseAsset()) + 1; // next round
        DelayedOrder memory order =
            DelayedOrder({
                isOffchain: isOffchain,
                sizeDelta: int128(sizeDelta),
                priceImpactDelta: uint128(priceImpactDelta),
                targetRoundId: isOffchain ? 0 : uint128(targetRoundId),
                commitDeposit: uint128(commitDeposit),
                keeperDeposit: uint128(keeperDeposit), // offchain orders do _not_ have an executableAtTime as it's based on price age.
                executableAtTime: isOffchain ? 0 : block.timestamp + desiredTimeDelta, // zero out - not used and minimise confusion.
                intentionTime: block.timestamp,
                trackingCode: trackingCode
            });

        emitDelayedOrderSubmitted(messageSender, order);
        marketState.updateDelayedOrder(
            messageSender,
            order.isOffchain,
            order.sizeDelta,
            order.priceImpactDelta,
            order.targetRoundId,
            order.commitDeposit,
            order.keeperDeposit,
            order.executableAtTime,
            order.intentionTime,
            order.trackingCode
        );
    }

    function _cancelDelayedOrder(address account, DelayedOrder memory order) internal {
        uint currentRoundId = _exchangeRates().getCurrentRoundId(_baseAsset());

        _confirmCanCancel(account, order, currentRoundId);

        if (account == messageSender) {
            // this is account owner
            // refund keeper fee to margin
            Position memory position = marketState.positions(account);

            // cancelling an order does not induce a fillPrice as no skew has moved.
            uint price = _assetPriceRequireSystemChecks(false);
            uint fundingIndex = _recomputeFunding(price);
            _updatePositionMargin(account, position, price, int(order.keeperDeposit));

            // emit event for modifying the position (add the fee to margin)
            emitPositionModified(position.id, account, position.margin, position.size, 0, price, fundingIndex, 0);
        } else {
            // send keeper fee to keeper
            _manager().issueSUSD(messageSender, order.keeperDeposit);
        }

        // pay the commitDeposit as fee to the FeePool
        _manager().payFee(order.commitDeposit);

        // important!! position of the account, not the msg.sender
        marketState.deleteDelayedOrder(account);
        emitDelayedOrderRemoved(account, currentRoundId, order);
    }

    function _executeDelayedOrder(
        address account,
        DelayedOrder memory order,
        uint currentPrice,
        uint currentRoundId,
        uint takerFee,
        uint makerFee
    ) internal {
        // handle the fees and refunds according to the mechanism rules
        uint toRefund = order.commitDeposit; // refund the commitment deposit

        // refund keeperFee to margin if it's the account holder
        if (messageSender == account) {
            toRefund += order.keeperDeposit;
        } else {
            _manager().issueSUSD(messageSender, order.keeperDeposit);
        }

        Position memory position = marketState.positions(account);

        uint fundingIndex = _recomputeFunding(currentPrice);

        // we need to grab the fillPrice for events and margin updates.
        uint fillPrice = _fillPrice(order.sizeDelta, currentPrice);

        // refund the commitFee (and possibly the keeperFee) to the margin before executing the order
        // if the order later fails this is reverted of course
        _updatePositionMargin(account, position, fillPrice, int(toRefund));
        // emit event for modifying the position (refunding fee/s)
        emitPositionModified(position.id, account, position.margin, position.size, 0, fillPrice, fundingIndex, 0);

        // execute or revert
        _trade(
            account,
            TradeParams({
                sizeDelta: order.sizeDelta, // using the pastPrice from the target roundId
                oraclePrice: currentPrice, // the funding is applied only from order confirmation time
                fillPrice: fillPrice,
                takerFee: takerFee, //_takerFeeDelayedOrder(_marketKey()),
                makerFee: makerFee, //_makerFeeDelayedOrder(_marketKey()),
                priceImpactDelta: order.priceImpactDelta,
                trackingCode: order.trackingCode
            })
        );

        // remove stored order
        marketState.deleteDelayedOrder(account);
        // emit event
        emitDelayedOrderRemoved(account, currentRoundId, order);
    }

    function _confirmCanCancel(
        address account,
        DelayedOrder memory order,
        uint currentRoundId
    ) internal {}

    ///// Events
    event DelayedOrderSubmitted(
        address indexed account,
        bool isOffchain,
        int sizeDelta,
        uint targetRoundId,
        uint intentionTime,
        uint executableAtTime,
        uint commitDeposit,
        uint keeperDeposit,
        bytes32 trackingCode
    );
    bytes32 internal constant DELAYEDORDERSUBMITTED_SIG =
        keccak256("DelayedOrderSubmitted(address,bool,int256,uint256,uint256,uint256,uint256,uint256,bytes32)");

    function emitDelayedOrderSubmitted(address account, DelayedOrder memory order) internal {
        proxy._emit(
            abi.encode(
                order.isOffchain,
                order.sizeDelta,
                order.targetRoundId,
                order.intentionTime,
                order.executableAtTime,
                order.commitDeposit,
                order.keeperDeposit,
                order.trackingCode
            ),
            2,
            DELAYEDORDERSUBMITTED_SIG,
            addressToBytes32(account),
            0,
            0
        );
    }

    event DelayedOrderRemoved(
        address indexed account,
        bool isOffchain,
        uint currentRoundId,
        int sizeDelta,
        uint targetRoundId,
        uint commitDeposit,
        uint keeperDeposit,
        bytes32 trackingCode
    );
    bytes32 internal constant DELAYEDORDERREMOVED_SIG =
        keccak256("DelayedOrderRemoved(address,bool,uint256,int256,uint256,uint256,uint256,bytes32)");

    function emitDelayedOrderRemoved(
        address account,
        uint currentRoundId,
        DelayedOrder memory order
    ) internal {
        proxy._emit(
            abi.encode(
                order.isOffchain,
                currentRoundId,
                order.sizeDelta,
                order.targetRoundId,
                order.commitDeposit,
                order.keeperDeposit,
                order.trackingCode
            ),
            2,
            DELAYEDORDERREMOVED_SIG,
            addressToBytes32(account),
            0,
            0
        );
    }
}


interface IPerpsV2MarketDelayedOrders {
    function submitDelayedOrder(
        int sizeDelta,
        uint priceImpactDelta,
        uint desiredTimeDelta
    ) external;

    function submitDelayedOrderWithTracking(
        int sizeDelta,
        uint priceImpactDelta,
        uint desiredTimeDelta,
        bytes32 trackingCode
    ) external;

    function cancelDelayedOrder(address account) external;

    function executeDelayedOrder(address account) external;
}


// Inheritance


/**
 Contract that implements DelayedOrders (onchain) mechanism for the PerpsV2 market.
 The purpose of the mechanism is to allow reduced fees for trades that commit to next price instead
 of current price. Specifically, this should serve funding rate arbitrageurs, such that funding rate
 arb is profitable for smaller skews. This in turn serves the protocol by reducing the skew, and so
 the risk to the debt pool, and funding rate for traders.
 The fees can be reduced when committing to next price, because front-running (MEV and oracle delay)
 is less of a risk when committing to next price.
 The relative complexity of the mechanism is due to having to enforce the "commitment" to the trade
 without either introducing free (or cheap) optionality to cause cancellations, and without large
 sacrifices to the UX / risk of the traders (e.g. blocking all actions, or penalizing failures too much).
 */
// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketDelayedOrders
contract PerpsV2MarketDelayedOrders is IPerpsV2MarketDelayedOrders, PerpsV2MarketDelayedOrdersBase {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        address _marketState,
        address _owner,
        address _resolver
    ) public PerpsV2MarketDelayedOrdersBase(_proxy, _marketState, _owner, _resolver) {}

    ///// Mutative methods

    /**
     * @notice submits an order to be filled some time in the future or at a price of the next oracle update.
     * Reverts if a previous order still exists (wasn't executed or cancelled).
     * Reverts if the order cannot be filled at current price to prevent withholding commitFee for
     * incorrectly submitted orders (that cannot be filled).
     *
     * The order is executable after desiredTimeDelta. However, we also allow execution if the next price update
     * occurs before the desiredTimeDelta.
     * Reverts if the desiredTimeDelta is < minimum required delay.
     *
     * @param sizeDelta size in baseAsset (notional terms) of the order, similar to `modifyPosition` interface
     * @param priceImpactDelta is a percentage tolerance on fillPrice to be check upon execution
     * @param desiredTimeDelta maximum time in seconds to wait before filling this order
     */
    function submitDelayedOrder(
        int sizeDelta,
        uint priceImpactDelta,
        uint desiredTimeDelta
    ) external onlyProxy {
        // @dev market key is obtained here and not in internal function to prevent stack too deep there
        // bytes32 marketKey = _marketKey();

        _submitDelayedOrder(_marketKey(), sizeDelta, priceImpactDelta, desiredTimeDelta, bytes32(0), false);
    }

    /// same as submitDelayedOrder but emits an event with the tracking code
    /// to allow volume source fee sharing for integrations
    function submitDelayedOrderWithTracking(
        int sizeDelta,
        uint priceImpactDelta,
        uint desiredTimeDelta,
        bytes32 trackingCode
    ) external onlyProxy {
        // @dev market key is obtained here and not in internal function to prevent stack too deep there
        // bytes32 marketKey = _marketKey();

        _submitDelayedOrder(_marketKey(), sizeDelta, priceImpactDelta, desiredTimeDelta, trackingCode, false);
    }

    /**
     * @notice Cancels an existing order for an account.
     * Anyone can call this method for any account, but only the account owner
     *  can cancel their own order during the period when it can still potentially be executed (before it becomes stale).
     *  Only after the order becomes stale, can anyone else (e.g. a keeper) cancel the order for the keeperFee.
     * Cancelling the order:
     * - Removes the stored order.
     * - commitFee (deducted during submission) is sent to the fee pool.
     * - keeperFee (deducted during submission) is refunded into margin if it's the account holder,
     *  or send to the msg.sender if it's not the account holder.
     * @param account the account for which the stored order should be cancelled
     */
    function cancelDelayedOrder(address account) external onlyProxy {
        // important!! order of the account, not the msg.sender
        DelayedOrder memory order = marketState.delayedOrders(account);
        // check that a previous order exists
        require(order.sizeDelta != 0, "no previous order");
        // check to ensure we are not running the offchain delayed order.
        require(!order.isOffchain, "use offchain method");

        _cancelDelayedOrder(account, order);
    }

    /**
     * @notice Tries to execute a previously submitted delayed order.
     * Reverts if:
     * - There is no order
     * - Target roundId wasn't reached yet
     * - Order is stale (target roundId is too low compared to current roundId).
     * - Order fails for accounting reason (e.g. margin was removed, leverage exceeded, etc)
     * - Time delay and target round has not yet been reached
     * If order reverts, it has to be removed by calling cancelDelayedOrder().
     * Anyone can call this method for any account.
     * If this is called by the account holder - the keeperFee is refunded into margin,
     *  otherwise it sent to the msg.sender.
     * @param account address of the account for which to try to execute a delayed order
     */
    function executeDelayedOrder(address account) external onlyProxy {
        // important!: order of the account, not the sender!
        DelayedOrder memory order = marketState.delayedOrders(account);
        // check that a previous order exists
        require(order.sizeDelta != 0, "no previous order");

        require(!order.isOffchain, "use offchain method");

        // check order executability and round-id
        uint currentRoundId = _exchangeRates().getCurrentRoundId(_baseAsset());
        require(
            block.timestamp >= order.executableAtTime || order.targetRoundId <= currentRoundId,
            "executability not reached"
        );

        // check order is not too old to execute
        // we cannot allow executing old orders because otherwise future knowledge
        // can be used to trigger failures of orders that are more profitable
        // then the commitFee that was charged, or can be used to confirm
        // orders that are more profitable than known then (which makes this into a "cheap option").
        require(
            !_confirmationWindowOver(order.executableAtTime, currentRoundId, order.targetRoundId),
            "order too old, use cancel"
        );

        // price depends on whether the delay or price update has reached/occurred first
        uint currentPrice = _assetPriceRequireSystemChecks(false);
        _executeDelayedOrder(
            account,
            order,
            currentPrice,
            currentRoundId,
            _takerFeeDelayedOrder(_marketKey()),
            _makerFeeDelayedOrder(_marketKey())
        );
    }

    function _confirmCanCancel(
        address account,
        DelayedOrder memory order,
        uint currentRoundId
    ) internal {
        if (account != messageSender) {
            // this is someone else (like a keeper)
            // cancellation by third party is only possible when execution cannot be attempted any longer
            // otherwise someone might try to grief an account by cancelling for the keeper fee
            require(
                _confirmationWindowOver(order.executableAtTime, currentRoundId, order.targetRoundId),
                "cannot be cancelled by keeper yet"
            );
        }
    }

    ///// Internal views

    /// confirmation window is over when:
    ///  1. current roundId is more than nextPriceConfirmWindow rounds after target roundId
    ///  2. or executableAtTime - block.timestamp is more than delayedOrderConfirmWindow
    ///
    /// if either conditions are met, an order is considered to have exceeded the window.
    function _confirmationWindowOver(
        uint executableAtTime,
        uint currentRoundId,
        uint targetRoundId
    ) internal view returns (bool) {
        bytes32 marketKey = _marketKey();
        return
            (block.timestamp > executableAtTime &&
                (block.timestamp - executableAtTime) > _delayedOrderConfirmWindow(marketKey)) ||
            ((currentRoundId > targetRoundId) && (currentRoundId - targetRoundId > _nextPriceConfirmWindow(marketKey))); // don't underflow
    }
}


interface IPerpsV2MarketOffchainOrders {
    function submitOffchainDelayedOrder(int sizeDelta, uint priceImpactDelta) external;

    function submitOffchainDelayedOrderWithTracking(
        int sizeDelta,
        uint priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function cancelOffchainDelayedOrder(address account) external;

    function executeOffchainDelayedOrder(address account, bytes[] calldata priceUpdateData) external payable;
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


// https://docs.synthetix.io/contracts/source/contracts/IPerpsV2ExchangeRate
interface IPerpsV2ExchangeRate {
    function setOffchainOracle(IPyth _offchainOracle) external;

    function setOffchainPriceFeedId(bytes32 assetId, bytes32 priceFeedId) external;

    /* ========== VIEWS ========== */

    function offchainOracle() external view returns (IPyth);

    function offchainPriceFeedId(bytes32 assetId) external view returns (bytes32);

    /* ---------- priceFeeds mutation ---------- */

    function updatePythPrice(address sender, bytes[] calldata priceUpdateData) external payable;

    // it is a view but it can revert
    function resolveAndGetPrice(bytes32 assetId, uint maxAge) external view returns (uint price, uint publishTime);

    // it is a view but it can revert
    function resolveAndGetLatestPrice(bytes32 assetId) external view returns (uint price, uint publishTime);
}


// Inheritance


// Reference


/**
 Contract that implements DelayedOrders (offchain) mechanism for the PerpsV2 market.
 The purpose of the mechanism is to allow reduced fees for trades that commit to next price instead
 of current price. Specifically, this should serve funding rate arbitrageurs, such that funding rate
 arb is profitable for smaller skews. This in turn serves the protocol by reducing the skew, and so
 the risk to the debt pool, and funding rate for traders.
 The fees can be reduced when committing to next price, because front-running (MEV and oracle delay)
 is less of a risk when committing to next price.
 The relative complexity of the mechanism is due to having to enforce the "commitment" to the trade
 without either introducing free (or cheap) optionality to cause cancellations, and without large
 sacrifices to the UX / risk of the traders (e.g. blocking all actions, or penalizing failures too much).
 */
// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketDelayedOrdersOffchain
contract PerpsV2MarketDelayedOrdersOffchain is IPerpsV2MarketOffchainOrders, PerpsV2MarketDelayedOrdersBase {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        address _marketState,
        address _owner,
        address _resolver
    ) public PerpsV2MarketDelayedOrdersBase(_proxy, _marketState, _owner, _resolver) {}

    function _perpsV2ExchangeRate() internal view returns (IPerpsV2ExchangeRate) {
        return IPerpsV2ExchangeRate(requireAndGetAddress(CONTRACT_PERPSV2EXCHANGERATE));
    }

    ///// Mutative methods

    /**
     * @notice submits an order to be filled some time in the future or at a price of the next oracle update.
     * Reverts if a previous order still exists (wasn't executed or cancelled).
     * Reverts if the order cannot be filled at current price to prevent withholding commitFee for
     * incorrectly submitted orders (that cannot be filled).
     *
     * The order is executable after desiredTimeDelta. However, we also allow execution if the next price update
     * occurs before the desiredTimeDelta.
     * Reverts if the desiredTimeDelta is < minimum required delay.
     *
     * @param sizeDelta size in baseAsset (notional terms) of the order, similar to `modifyPosition` interface
     * @param priceImpactDelta is a percentage tolerance on fillPrice to be check upon execution
     */
    function submitOffchainDelayedOrder(int sizeDelta, uint priceImpactDelta) external onlyProxy {
        // @dev market key is obtained here and not in internal function to prevent stack too deep there
        // bytes32 marketKey = _marketKey();

        // enforcing desiredTimeDelta to 0 to use default (not needed for offchain delayed order)
        _submitDelayedOrder(_marketKey(), sizeDelta, priceImpactDelta, 0, bytes32(0), true);
    }

    function submitOffchainDelayedOrderWithTracking(
        int sizeDelta,
        uint priceImpactDelta,
        bytes32 trackingCode
    ) external onlyProxy {
        // @dev market key is obtained here and not in internal function to prevent stack too deep there
        // bytes32 marketKey = _marketKey();

        _submitDelayedOrder(_marketKey(), sizeDelta, priceImpactDelta, 0, trackingCode, true);
    }

    /**
     * @notice Cancels an existing order for an account.
     * Anyone can call this method for any account, but only the account owner
     *  can cancel their own order during the period when it can still potentially be executed (before it becomes stale).
     *  Only after the order becomes stale, can anyone else (e.g. a keeper) cancel the order for the keeperFee.
     * Cancelling the order:
     * - Removes the stored order.
     * - commitFee (deducted during submission) is sent to the fee pool.
     * - keeperFee (deducted during submission) is refunded into margin if it's the account holder,
     *  or send to the msg.sender if it's not the account holder.
     * @param account the account for which the stored order should be cancelled
     */
    function cancelOffchainDelayedOrder(address account) external onlyProxy {
        // important!! order of the account, not the msg.sender
        DelayedOrder memory order = marketState.delayedOrders(account);
        // check that a previous order exists
        require(order.sizeDelta != 0, "no previous order");

        require(order.isOffchain, "use onchain method");

        _cancelDelayedOrder(account, order);
    }

    /**
     * @notice Tries to execute a previously submitted delayed order.
     * Reverts if:
     * - There is no order
     * - Target roundId wasn't reached yet
     * - Order is stale (target roundId is too low compared to current roundId).
     * - Order fails for accounting reason (e.g. margin was removed, leverage exceeded, etc)
     * - Time delay and target round has not yet been reached
     * If order reverts, it has to be removed by calling cancelDelayedOrder().
     * Anyone can call this method for any account.
     * If this is called by the account holder - the keeperFee is refunded into margin,
     *  otherwise it sent to the msg.sender.
     * @param account address of the account for which to try to execute a delayed order
     */
    function executeOffchainDelayedOrder(address account, bytes[] calldata priceUpdateData) external payable onlyProxy {
        // important!: order of the account, not the sender!
        DelayedOrder memory order = marketState.delayedOrders(account);
        // check that a previous order exists
        require(order.sizeDelta != 0, "no previous order");

        require(order.isOffchain, "use onchain method");

        // update price feed (this is payable)
        _perpsV2ExchangeRate().updatePythPrice.value(msg.value)(messageSender, priceUpdateData);

        // get latest price for asset
        uint maxAge = _offchainDelayedOrderMaxAge(_marketKey());
        uint minAge = _offchainDelayedOrderMinAge(_marketKey());

        (uint currentPrice, uint executionTimestamp) = _offchainAssetPriceRequireSystemChecks(maxAge);

        require((executionTimestamp > order.intentionTime), "price not updated");
        require((executionTimestamp - order.intentionTime > minAge), "too early");
        require((executionTimestamp - order.intentionTime < maxAge), "too late");

        _executeDelayedOrder(
            account,
            order,
            currentPrice,
            0,
            _takerFeeOffchainDelayedOrder(_marketKey()),
            _makerFeeOffchainDelayedOrder(_marketKey())
        );
    }

    // solhint-disable no-unused-vars
    function _confirmCanCancel(
        address account,
        DelayedOrder memory order,
        uint currentRoundId
    ) internal {
        require(block.timestamp - order.intentionTime > _offchainDelayedOrderMaxAge(_marketKey()) * 2, "cannot cancel yet");
    }

    ///// Internal

    /*
     * The current base price, reverting if it is invalid, or if system or synth is suspended.
     */
    function _offchainAssetPriceRequireSystemChecks(uint maxAge) internal returns (uint price, uint publishTime) {
        // Onchain oracle asset price
        uint onchainPrice = _assetPriceRequireSystemChecks(true);
        (price, publishTime) = _perpsV2ExchangeRate().resolveAndGetPrice(_baseAsset(), maxAge);

        require(onchainPrice > 0 && price > 0, "invalid, price is 0");

        uint delta =
            (onchainPrice > price)
                ? onchainPrice.divideDecimal(price).sub(SafeDecimalMath.unit())
                : price.divideDecimal(onchainPrice).sub(SafeDecimalMath.unit());
        require(_offchainPriceDivergence(_marketKey()) > delta, "price divergence too high");

        return (price, publishTime);
    }
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


/*
 * Synthetic PerpsV2
 * =================
 *
 * PerpsV2 markets allow users leveraged exposure to an asset, long or short.
 * A user must post some margin in order to open a perpsV2 account, and profits/losses are
 * continually tallied against this margin. If a user's margin runs out, then their position is closed
 * by a liquidation keeper, which is rewarded with a flat fee extracted from the margin.
 *
 * The Synthetix debt pool is effectively the counterparty to each trade, so if a particular position
 * is in profit, then the debt pool pays by issuing sUSD into their margin account,
 * while if the position makes a loss then the debt pool burns sUSD from the margin, reducing the
 * debt load in the system.
 *
 * As the debt pool underwrites all positions, the debt-inflation risk to the system is proportional to the
 * long-short skew in the market. It is therefore in the interest of the system to reduce the skew.
 * To encourage the minimisation of the skew, each position is charged a funding rate, which increases with
 * the size of the skew. The funding rate is charged continuously, and positions on the heavier side of the
 * market are charged the current funding rate times the notional value of their position, while positions
 * on the lighter side are paid at the same rate to keep their positions open.
 * As the funding rate is the same (but negated) on both sides of the market, there is an excess quantity of
 * funding being charged, which is collected by the debt pool, and serves to reduce the system debt.
 *
 * The contract architecture is as follows:
 *
 *     - FuturesMarketManager.sol:  the manager keeps track of which markets exist, and is the main window between
 *                                  futures and perpsV2 markets and the rest of the system. It accumulates the total debt
 *                                  over all markets, and issues and burns sUSD on each market's behalf.
 *
 *     - PerpsV2MarketSettings.sol: Holds the settings for each market in the global FlexibleStorage instance used
 *                                  by SystemSettings, and provides an interface to modify these values. Other than
 *                                  the base asset, these settings determine the behaviour of each market.
 *                                  See that contract for descriptions of the meanings of each setting.
 *
 * Each market is composed of the following pieces, one of each of this exists per asset:
 *
 *     - ProxyPerpsV2.sol:          The Proxy is the main entry point and visible, permanent address of the market.
 *                                  It acts as a combination of Proxy and Router sending the messages to the
 *                                  appropriate implementation (or fragment) of the Market.
 *                                  Margin is maintained isolated per market. each market is composed of several
 *                                  contracts (or fragments) accessed by this proxy:
 *                                  `base` contains all the common logic and is inherited by other fragments.
 *                                  It's treated as abstract and not deployed alone;
 *                                  `proxyable` is an extension of `base` that implements the proxyable interface
 *                                  and is used as base for fragments that require the messageSender.
 *                                  `mutations` contains the basic market behaviour
 *                                  `views` contains functions to provide visibility to different parameters and
 *                                  is used by external or manager contracts.
 *                                  `delayedOrders` contains the logic to implement the delayed order flows.
 *                                  `offchainDelayedOrders` contains the logic to implement the delayed order
 *                                  with off-chain pricing flows.
 *
 *     - PerpsV2State.sol:          The State contracts holds all the state for the market and is consumed/updated
 *                                  by the fragments.
 *                                  It provides access to the positions in case a migration is needed in the future.
 *
 *     - PerpsV2Market.sol:         Contains the core logic to implement the market and position flows.
 *
 *     - PerpsV2MarketViews.sol:    Contains the logic to access market and positions parameters by external or
 *                                  manager contracts
 *
 *     - PerpsV2MarketDelayedOrdersOffchain.sol: Contains the logic to implement delayed order with off-chain pricing flows
 *
 *
 * Technical note: internal functions within the PerpsV2Market contract assume the following:
 *
 *     - prices passed into them are valid;
 *     - funding has already been recomputed up to the current time (hence unrecorded funding is nil);
 *     - the account being managed was not liquidated in the same transaction;
 */

// https://docs.synthetix.io/contracts/source/contracts/PerpsV2Market
contract PerpsV2Market is IPerpsV2Market, PerpsV2MarketProxyable {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        address _marketState,
        address _owner,
        address _resolver
    ) public PerpsV2MarketProxyable(_proxy, _marketState, _owner, _resolver) {}

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * Pushes a new entry to the funding sequence at the current price and funding rate.
     * @dev Admin only method accessible to PerpsV2MarketSettings. This is admin only because:
     * - When system parameters change, funding should be recomputed, but system may be paused
     *   during that time for any reason, so this method needs to work even if system is paused.
     *   But in that case, it shouldn't be accessible to external accounts.
     */
    function recomputeFunding() external returns (uint lastIndex) {
        // only PerpsV2MarketSettings is allowed to use this method (calling it directly, not via proxy)
        _revertIfError(messageSender != _settings(), Status.NotPermitted);
        // This method is the only mutative method that uses the view _assetPrice()
        // and not the mutative _assetPriceRequireSystemChecks() that reverts on system flags.
        // This is because this method is used by system settings when changing funding related
        // parameters, so needs to function even when system / market is paused. E.g. to facilitate
        // market migration.
        (uint price, bool invalid) = _assetPrice();
        // A check for a valid price is still in place, to ensure that a system settings action
        // doesn't take place when the price is invalid (e.g. some oracle issue).
        require(!invalid, "Invalid price");
        return _recomputeFunding(price);
    }

    function _transferMargin(
        int marginDelta,
        uint price,
        address sender
    ) internal {
        // Transfer no tokens if marginDelta is 0
        uint absDelta = _abs(marginDelta);
        if (marginDelta > 0) {
            // A positive margin delta corresponds to a deposit, which will be burnt from their
            // sUSD balance and credited to their margin account.

            // Ensure we handle reclamation when burning tokens.
            uint postReclamationAmount = _manager().burnSUSD(sender, absDelta);
            if (postReclamationAmount != absDelta) {
                // If balance was insufficient, the actual delta will be smaller
                marginDelta = int(postReclamationAmount);
            }
        } else if (marginDelta < 0) {
            // A negative margin delta corresponds to a withdrawal, which will be minted into
            // their sUSD balance, and debited from their margin account.
            _manager().issueSUSD(sender, absDelta);
        } else {
            // Zero delta is a no-op
            return;
        }

        Position memory position = marketState.positions(sender);

        _updatePositionMargin(sender, position, price, marginDelta);

        emitMarginTransferred(sender, marginDelta);

        emitPositionModified(position.id, sender, position.margin, position.size, 0, price, _latestFundingIndex(), 0);
    }

    /*
     * Alter the amount of margin in a position. A positive input triggers a deposit; a negative one, a
     * withdrawal. The margin will be burnt or issued directly into/out of the caller's sUSD wallet.
     * Reverts on deposit if the caller lacks a sufficient sUSD balance.
     * Reverts on withdrawal if the amount to be withdrawn would expose an open position to liquidation.
     */
    function transferMargin(int marginDelta) external onlyProxy {
        uint price = _assetPriceRequireSystemChecks(false);
        _recomputeFunding(price);
        _transferMargin(marginDelta, price, messageSender);
    }

    /*
     * Withdraws all accessible margin in a position. This will leave some remaining margin
     * in the account if the caller has a position open. Equivalent to `transferMargin(-accessibleMargin(sender))`.
     */
    function withdrawAllMargin() external onlyProxy {
        address sender = messageSender;
        uint price = _assetPriceRequireSystemChecks(false);
        _recomputeFunding(price);
        int marginDelta = -int(_accessibleMargin(marketState.positions(sender), price));
        _transferMargin(marginDelta, price, sender);
    }

    /*
     * Adjust the sender's position size.
     * Reverts if the resulting position is too large, outside the max leverage, or is liquidating.
     */
    function modifyPosition(int sizeDelta, uint priceImpactDelta) external {
        _modifyPosition(sizeDelta, priceImpactDelta, bytes32(0));
    }

    /*
     * Same as modifyPosition, but emits an event with the passed tracking code to
     * allow off-chain calculations for fee sharing with originating integrations
     */
    function modifyPositionWithTracking(
        int sizeDelta,
        uint priceImpactDelta,
        bytes32 trackingCode
    ) external {
        _modifyPosition(sizeDelta, priceImpactDelta, trackingCode);
    }

    function _modifyPosition(
        int sizeDelta,
        uint priceImpactDelta,
        bytes32 trackingCode
    ) internal onlyProxy {
        uint price = _assetPriceRequireSystemChecks(false);
        _recomputeFunding(price);
        _trade(
            messageSender,
            TradeParams({
                sizeDelta: sizeDelta,
                oraclePrice: price,
                fillPrice: _fillPrice(sizeDelta, price),
                takerFee: _takerFee(_marketKey()),
                makerFee: _makerFee(_marketKey()),
                priceImpactDelta: priceImpactDelta,
                trackingCode: trackingCode
            })
        );
    }

    /*
     * Submit an order to close a position.
     */
    function closePosition(uint priceImpactDelta) external {
        _closePosition(priceImpactDelta, bytes32(0));
    }

    /// Same as closePosition, but emits an even with the trackingCode for volume source fee sharing
    function closePositionWithTracking(uint priceImpactDelta, bytes32 trackingCode) external {
        _closePosition(priceImpactDelta, trackingCode);
    }

    function _closePosition(uint priceImpactDelta, bytes32 trackingCode) internal onlyProxy {
        int size = marketState.positions(messageSender).size;
        _revertIfError(size == 0, Status.NoPositionOpen);
        uint price = _assetPriceRequireSystemChecks(false);
        _recomputeFunding(price);
        _trade(
            messageSender,
            // note: the -size here is needed to completely close the position.
            TradeParams({
                sizeDelta: -size,
                oraclePrice: price,
                fillPrice: _fillPrice(-size, price),
                takerFee: _takerFee(_marketKey()),
                makerFee: _makerFee(_marketKey()),
                priceImpactDelta: priceImpactDelta,
                trackingCode: trackingCode
            })
        );
    }

    function _liquidatePosition(
        address account,
        address liquidator,
        uint price
    ) internal {
        Position memory position = marketState.positions(account);

        // Get remaining margin for sending any leftover buffer to fee pool
        //
        // note: we do _not_ use `_remainingLiquidatableMargin` here as we want to send this premium to the fee pool
        // upon liquidation to give back to stakers.
        uint remMargin = _remainingMargin(position, price);

        // Record updates to market size and debt.
        int positionSize = position.size;
        uint positionId = position.id;
        marketState.setMarketSkew(int128(int(marketState.marketSkew()).sub(positionSize)));
        marketState.setMarketSize(uint128(uint(marketState.marketSize()).sub(_abs(positionSize))));

        uint fundingIndex = _latestFundingIndex();
        _applyDebtCorrection(
            Position(0, uint64(fundingIndex), 0, uint128(price), 0),
            Position(0, position.lastFundingIndex, position.margin, position.lastPrice, int128(positionSize))
        );

        // Close the position itself.
        marketState.deletePosition(account);

        // Issue the reward to the liquidator.
        uint liqFee = _liquidationFee(positionSize, price);
        _manager().issueSUSD(liquidator, liqFee);

        emitPositionModified(positionId, account, 0, 0, 0, price, fundingIndex, 0);
        emitPositionLiquidated(positionId, account, liquidator, positionSize, price, liqFee);

        // Send any positive margin buffer to the fee pool
        if (remMargin > liqFee) {
            _manager().payFee(remMargin.sub(liqFee));
        }
    }

    /*
     * Liquidate a position if its remaining margin is below the liquidation fee. This succeeds if and only if
     * `canLiquidate(account)` is true, and reverts otherwise.
     * Upon liquidation, the position will be closed, and the liquidation fee minted into the liquidator's account.
     */
    function liquidatePosition(address account) external onlyProxy {
        uint price = _assetPriceRequireSystemChecks(false);
        _recomputeFunding(price);

        _revertIfError(!_canLiquidate(marketState.positions(account), price), Status.CannotLiquidate);

        _liquidatePosition(account, messageSender, price);
    }
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


interface ISynthetixNamedContract {
    // solhint-disable func-name-mixedcase
    function CONTRACT_NAME() external view returns (bytes32);
}

// solhint-disable contract-name-camelcase
contract Migration_MintakaOptimism is BaseMigration {
    // https://explorer.optimism.io/address/0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;
    address public constant OWNER = 0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;

    // ----------------------------
    // EXISTING SYNTHETIX CONTRACTS
    // ----------------------------

    // https://explorer.optimism.io/address/0x038dC05D68ED32F23e6856c0D44b0696B325bfC8
    PerpsV2MarketState public constant perpsv2marketstate_i = PerpsV2MarketState(0x038dC05D68ED32F23e6856c0D44b0696B325bfC8);
    // https://explorer.optimism.io/address/0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6
    PerpsV2MarketDelayedOrders public constant perpsv2marketdelayedorders_i =
        PerpsV2MarketDelayedOrders(0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6);
    // https://explorer.optimism.io/address/0x0454E103a712b257819efBBB797EaE80918dd2FF
    PerpsV2MarketDelayedOrdersOffchain public constant perpsv2marketdelayedordersoffchain_i =
        PerpsV2MarketDelayedOrdersOffchain(0x0454E103a712b257819efBBB797EaE80918dd2FF);
    // https://explorer.optimism.io/address/0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c
    PerpsV2Market public constant perpsv2market_i = PerpsV2Market(0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c);
    // https://explorer.optimism.io/address/0x2B3bb4c683BFc5239B029131EEf3B1d214478d93
    ProxyPerpsV2 public constant proxyperpsv2_i = ProxyPerpsV2(0x2B3bb4c683BFc5239B029131EEf3B1d214478d93);
    // https://explorer.optimism.io/address/0x4aD2d14Bed21062Ef7B85C378F69cDdf6ED7489C
    PerpsV2ExchangeRate public constant perpsv2exchangerate_i =
        PerpsV2ExchangeRate(0x4aD2d14Bed21062Ef7B85C378F69cDdf6ED7489C);
    // https://explorer.optimism.io/address/0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e
    FuturesMarketManager public constant futuresmarketmanager_i =
        FuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);
    // https://explorer.optimism.io/address/0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C
    AddressResolver public constant addressresolver_i = AddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);
    // https://explorer.optimism.io/address/0x09793Aad1518B8d8CC72FDd356479E3CBa7B4Ad1
    PerpsV2MarketSettings public constant perpsv2marketsettings_i =
        PerpsV2MarketSettings(0x09793Aad1518B8d8CC72FDd356479E3CBa7B4Ad1);

    // ----------------------------------
    // NEW CONTRACTS DEPLOYED TO BE ADDED
    // ----------------------------------

    // https://explorer.optimism.io/address/0x09793Aad1518B8d8CC72FDd356479E3CBa7B4Ad1
    address public constant new_PerpsV2MarketSettings_contract = 0x09793Aad1518B8d8CC72FDd356479E3CBa7B4Ad1;

    constructor() public BaseMigration(OWNER) {}

    function contractsRequiringOwnership() public pure returns (address[] memory contracts) {
        contracts = new address[](9);
        contracts[0] = address(perpsv2marketstate_i);
        contracts[1] = address(perpsv2marketdelayedorders_i);
        contracts[2] = address(perpsv2marketdelayedordersoffchain_i);
        contracts[3] = address(perpsv2market_i);
        contracts[4] = address(proxyperpsv2_i);
        contracts[5] = address(perpsv2exchangerate_i);
        contracts[6] = address(futuresmarketmanager_i);
        contracts[7] = address(addressresolver_i);
        contracts[8] = address(perpsv2marketsettings_i);
    }

    function migrate() external onlyOwner {
        // ACCEPT OWNERSHIP for all contracts that require ownership to make changes
        acceptAll();

        // MIGRATION
        perpsv2marketstate_addAssociatedContracts_0();
        perpsv2marketdelayedorders_i.setProxy(0x2B3bb4c683BFc5239B029131EEf3B1d214478d93);
        perpsv2marketstate_addAssociatedContracts_2();
        perpsv2marketdelayedordersoffchain_i.setProxy(0x2B3bb4c683BFc5239B029131EEf3B1d214478d93);
        perpsv2marketstate_addAssociatedContracts_4();
        perpsv2market_i.setProxy(0x2B3bb4c683BFc5239B029131EEf3B1d214478d93);
        proxyperpsv2_i.addRoute(0x785cdeec, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x1bf556d0, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xd24378eb, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xcdf456e1, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xb9f4ff55, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x3aef4d0b, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xb74e3806, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xea9f9aa7, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x27b9a236, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x41108cf2, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xcded0cea, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x2af64bd3, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xc8023af4, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x964db90c, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xe8c63470, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xd7103a46, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xeb56105d, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x5fc890c2, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x2b58ecef, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xb895daab, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x4dd9d7e9, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x55f57510, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xea1d5478, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xb111dfac, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x9cfbf4e4, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0x917e77f5, 0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D, true);
        proxyperpsv2_i.addRoute(0xc70b41e9, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, false);
        proxyperpsv2_i.addRoute(0xc8b809aa, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, true);
        proxyperpsv2_i.addRoute(0xa8300afb, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, false);
        proxyperpsv2_i.addRoute(0xd67bdd25, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, true);
        proxyperpsv2_i.addRoute(0xec556889, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, true);
        proxyperpsv2_i.addRoute(0xbc67f832, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, false);
        proxyperpsv2_i.addRoute(0x97107d6d, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, false);
        proxyperpsv2_i.addRoute(0x09461cfe, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, false);
        proxyperpsv2_i.addRoute(0x787d6c30, 0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6, false);
        proxyperpsv2_i.addRoute(0xdcce5806, 0x0454E103a712b257819efBBB797EaE80918dd2FF, false);
        proxyperpsv2_i.addRoute(0xdfa723cc, 0x0454E103a712b257819efBBB797EaE80918dd2FF, false);
        proxyperpsv2_i.addRoute(0xa1c35a35, 0x0454E103a712b257819efBBB797EaE80918dd2FF, false);
        proxyperpsv2_i.addRoute(0x85f05ab5, 0x0454E103a712b257819efBBB797EaE80918dd2FF, false);
        proxyperpsv2_i.addRoute(0xa126d601, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x5c8011c3, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x7498a0f0, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x4ad4914b, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x32f05103, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x4eb985cc, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x88a3c848, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        proxyperpsv2_i.addRoute(0x5a1cbd2b, 0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c, false);
        perpsv2exchangerate_removeAssociatedContracts_53();
        perpsv2exchangerate_addAssociatedContracts_54();
        futuresmarketmanager_updateMarketsImplementations_55();
        // Import all new contracts into the address resolver;
        addressresolver_importAddresses_56();
        // Rebuild the resolver caches in all MixinResolver contracts - batch 1;
        addressresolver_rebuildCaches_57();
        // Ensure the PerpsV2ExchangeRate contract has the off-chain feed Id for sBTC;
        // Set the minimum margin to open a perpsV2 position (SIP-80);
        perpsv2marketsettings_i.setMinInitialMargin(40000000000000000000);
        // Set the reward for liquidating a perpsV2 position (SIP-80);
        perpsv2marketsettings_i.setLiquidationFeeRatio(3500000000000000);
        // Set the reward for liquidating a perpsV2 position (SIP-80);
        perpsv2marketsettings_i.setLiquidationBufferRatio(2500000000000000);
        // Set the minimum reward for liquidating a perpsV2 position (SIP-80);
        perpsv2marketsettings_i.setMinKeeperFee(2000000000000000000);
        // Set the maximum reward for liquidating a perpsV2 position;
        perpsv2marketsettings_i.setMaxKeeperFee(1000000000000000000000);
        perpsv2marketsettings_i.setTakerFee("sETHPERP", 10000000000000000);
        perpsv2marketsettings_i.setMakerFee("sETHPERP", 7000000000000000);
        perpsv2marketsettings_i.setTakerFeeDelayedOrder("sETHPERP", 1000000000000000);
        perpsv2marketsettings_i.setMakerFeeDelayedOrder("sETHPERP", 500000000000000);
        perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sETHPERP", 1000000000000000);
        perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sETHPERP", 500000000000000);
        perpsv2marketsettings_i.setNextPriceConfirmWindow("sETHPERP", 2);
        perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sETHPERP", 120);
        perpsv2marketsettings_i.setMinDelayTimeDelta("sETHPERP", 60);
        perpsv2marketsettings_i.setMaxDelayTimeDelta("sETHPERP", 6000);
        perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sETHPERP", 15);
        perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sETHPERP", 120);
        perpsv2marketsettings_i.setMaxLeverage("sETHPERP", 100000000000000000000);
        perpsv2marketsettings_i.setMaxMarketValue("sETHPERP", 1000000000000000000000);
        perpsv2marketsettings_i.setMaxFundingVelocity("sETHPERP", 3000000000000000000);
        perpsv2marketsettings_i.setSkewScale("sETHPERP", 1000000000000000000000000);
        perpsv2marketsettings_i.setOffchainMarketKey("sETHPERP", "ocETHPERP");
        perpsv2marketsettings_i.setOffchainPriceDivergence("sETHPERP", 20000000000000000);
        perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sETHPERP", 1000000000000000000);

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

    function perpsv2marketstate_addAssociatedContracts_0() internal {
        address[] memory perpsv2marketstate_addAssociatedContracts_associatedContracts_0_0 = new address[](1);
        perpsv2marketstate_addAssociatedContracts_associatedContracts_0_0[0] = address(
            0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6
        );
        perpsv2marketstate_i.addAssociatedContracts(perpsv2marketstate_addAssociatedContracts_associatedContracts_0_0);
    }

    function perpsv2marketstate_addAssociatedContracts_2() internal {
        address[] memory perpsv2marketstate_addAssociatedContracts_associatedContracts_2_0 = new address[](1);
        perpsv2marketstate_addAssociatedContracts_associatedContracts_2_0[0] = address(
            0x0454E103a712b257819efBBB797EaE80918dd2FF
        );
        perpsv2marketstate_i.addAssociatedContracts(perpsv2marketstate_addAssociatedContracts_associatedContracts_2_0);
    }

    function perpsv2marketstate_addAssociatedContracts_4() internal {
        address[] memory perpsv2marketstate_addAssociatedContracts_associatedContracts_4_0 = new address[](1);
        perpsv2marketstate_addAssociatedContracts_associatedContracts_4_0[0] = address(
            0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c
        );
        perpsv2marketstate_i.addAssociatedContracts(perpsv2marketstate_addAssociatedContracts_associatedContracts_4_0);
    }

    function perpsv2exchangerate_removeAssociatedContracts_53() internal {
        address[] memory perpsv2exchangerate_removeAssociatedContracts_associatedContracts_53_0 = new address[](1);
        perpsv2exchangerate_removeAssociatedContracts_associatedContracts_53_0[0] = address(
            0x36841F7Ff6fBD318202A5101F8426eBb051d5e4d
        );
        perpsv2exchangerate_i.removeAssociatedContracts(
            perpsv2exchangerate_removeAssociatedContracts_associatedContracts_53_0
        );
    }

    function perpsv2exchangerate_addAssociatedContracts_54() internal {
        address[] memory perpsv2exchangerate_addAssociatedContracts_associatedContracts_54_0 = new address[](1);
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_54_0[0] = address(
            0x0454E103a712b257819efBBB797EaE80918dd2FF
        );
        perpsv2exchangerate_i.addAssociatedContracts(perpsv2exchangerate_addAssociatedContracts_associatedContracts_54_0);
    }

    function futuresmarketmanager_updateMarketsImplementations_55() internal {
        address[] memory futuresmarketmanager_updateMarketsImplementations_marketsToUpdate_55_0 = new address[](1);
        futuresmarketmanager_updateMarketsImplementations_marketsToUpdate_55_0[0] = address(
            0x2B3bb4c683BFc5239B029131EEf3B1d214478d93
        );
        futuresmarketmanager_i.updateMarketsImplementations(
            futuresmarketmanager_updateMarketsImplementations_marketsToUpdate_55_0
        );
    }

    function addressresolver_importAddresses_56() internal {
        bytes32[] memory addressresolver_importAddresses_names_56_0 = new bytes32[](1);
        addressresolver_importAddresses_names_56_0[0] = bytes32("PerpsV2MarketSettings");
        address[] memory addressresolver_importAddresses_destinations_56_1 = new address[](1);
        addressresolver_importAddresses_destinations_56_1[0] = address(new_PerpsV2MarketSettings_contract);
        addressresolver_i.importAddresses(
            addressresolver_importAddresses_names_56_0,
            addressresolver_importAddresses_destinations_56_1
        );
    }

    function addressresolver_rebuildCaches_57() internal {
        MixinResolver[] memory addressresolver_rebuildCaches_destinations_57_0 = new MixinResolver[](5);
        addressresolver_rebuildCaches_destinations_57_0[0] = MixinResolver(0x35CcAC0A67D2a1EF1FDa8898AEcf1415FE6cf94c);
        addressresolver_rebuildCaches_destinations_57_0[1] = MixinResolver(0x9363c080Ca0B16EAD12Fd33aac65c8D0214E9d6D);
        addressresolver_rebuildCaches_destinations_57_0[2] = MixinResolver(0xe343542366A9f3Af56Acc6D68154Cfaf23efeba6);
        addressresolver_rebuildCaches_destinations_57_0[3] = MixinResolver(0x0454E103a712b257819efBBB797EaE80918dd2FF);
        addressresolver_rebuildCaches_destinations_57_0[4] = MixinResolver(new_PerpsV2MarketSettings_contract);
        addressresolver_i.rebuildCaches(addressresolver_rebuildCaches_destinations_57_0);
    }
}