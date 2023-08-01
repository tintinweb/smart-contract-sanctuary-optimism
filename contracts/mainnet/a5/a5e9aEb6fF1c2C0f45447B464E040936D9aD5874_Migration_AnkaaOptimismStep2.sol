/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-27
*/

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: migrations/Migration_AnkaaOptimismStep2.sol
*
* Latest source (may be newer): https://github.com/Synthetixio/synthetix/blob/master/contracts/migrations/Migration_AnkaaOptimismStep2.sol
* Docs: https://docs.synthetix.io/contracts/migrations/Migration_AnkaaOptimismStep2
*
* Contract Dependencies: 
*	- BaseMigration
*	- IAddressResolver
*	- IFuturesMarketManager
*	- IPerpsV2MarketBaseTypes
*	- IPerpsV2MarketBaseTypesLegacyR1
*	- IPerpsV2MarketSettings
*	- ISystemStatus
*	- MixinPerpsV2MarketSettings
*	- MixinResolver
*	- MixinSystemSettings
*	- Owned
*	- ReentrancyGuard
*	- StateShared
* Libraries: 
*	- AddressSetLib
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
        PriceImpactToleranceExceeded,
        PositionFlagged,
        PositionNotFlagged
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
        uint128 desiredFillPrice; // desired fill price as usd used on fillPrice at execution
        uint128 targetRoundId; // price oracle roundId using which price this order needs to executed
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint256 executableAtTime; // The timestamp at which this order is executable at
        uint256 intentionTime; // The block timestamp of submission
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }
}


interface IPerpsV2MarketBaseTypesLegacyR1 {
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
        PriceImpactToleranceExceeded,
        PositionFlagged,
        PositionNotFlagged
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
        uint128 priceImpactDelta; // desired price delta
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


pragma experimental ABIEncoderV2;

// Inheritance


// Libraries


/**
 Legacy State holding historical data. Old PerpsV2MarketState.sol
 Once this contract is linked to the next generation of PerpsV2MarketState, the data is not updateable anymore. 
 The only contract enabled to operate (if needed) on the data is the next generation PerpsV2MarketState, 
 in order to achieve that, the new State is the only address included as associated contract.

 Atomic data is copied at `migration` time.
 PerpsV2MarketState ---(consumes)--> PerpsV2MarketStateLegacyR1 
 */

// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketStateLegacyR1
contract PerpsV2MarketStateLegacyR1 is Owned, StateShared, IPerpsV2MarketBaseTypesLegacyR1 {
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


// Inheritance


// Libraries


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketState
// solhint-disable-next-line max-states-count
contract PerpsV2MarketState is Owned, StateShared, IPerpsV2MarketBaseTypes {
    using AddressSetLib for AddressSetLib.AddressSet;

    // Legacy state link
    bool public initialized;
    uint public legacyFundinSequenceOffset;
    PerpsV2MarketStateLegacyR1 public legacyState;
    bool private _legacyContractExists;
    mapping(address => bool) internal _positionMigrated;
    mapping(address => bool) internal _delayedOrderMigrated;

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
    int128[] internal _fundingSequence;

    /*
     * The funding rate last time it was recomputed. The market funding rate floats and requires the previously
     * calculated funding rate, time, and current market conditions to derive the next.
     */
    int128 public fundingRateLastRecomputed;

    /*
     * Each user's position. Multiple positions can always be merged, so each user has
     * only have one position at a time.
     */
    mapping(address => Position) internal _positions;

    // The set of all addresses (positions) .
    AddressSetLib.AddressSet internal _positionAddresses;

    // The set of all addresses (delayedOrders) .
    AddressSetLib.AddressSet internal _delayedOrderAddresses;

    // This increments for each position; zero reflects a position that does not exist.
    uint64 internal _nextPositionId = 1;

    /// @dev Holds a mapping of accounts to orders. Only one order per account is supported
    mapping(address => DelayedOrder) internal _delayedOrders;

    /// @dev Holds a mapping of accounts to flagger address to flag an account. Only one order per account is supported
    mapping(address => address) public positionFlagger;
    AddressSetLib.AddressSet internal _flaggedAddresses;

    constructor(
        address _owner,
        address[] memory _associatedContracts,
        bytes32 _baseAsset,
        bytes32 _marketKey,
        address _legacyState
    ) public Owned(_owner) StateShared(_associatedContracts) {
        baseAsset = _baseAsset;
        marketKey = _marketKey;

        // Set legacyState
        if (_legacyState != address(0)) {
            legacyState = PerpsV2MarketStateLegacyR1(_legacyState);
            _legacyContractExists = true;
            // Confirm same asset/market key
            // Passing the marketKey as parameter and confirming with the legacy allows for double check the intended market is configured
            require(
                baseAsset == legacyState.baseAsset() && marketKey == legacyState.marketKey(),
                "Invalid legacy state baseAsset or marketKey"
            );
        }
    }

    /*
     * Links this State contract with the legacy one fixing the latest state on the previous contract.
     * This function should be called with the market paused to prevent any issue.
     * Note: It's not called on constructor to allow separation of deployment and
     * setup/linking and reduce downtime.
     */
    function linkOrInitializeState() external onlyOwner {
        require(!initialized, "State already initialized");

        if (_legacyContractExists) {
            // copy atomic values
            marketSize = legacyState.marketSize();
            marketSkew = legacyState.marketSkew();
            _entryDebtCorrection = legacyState.entryDebtCorrection();
            _nextPositionId = legacyState.nextPositionId();
            fundingLastRecomputed = legacyState.fundingLastRecomputed();
            fundingRateLastRecomputed = legacyState.fundingRateLastRecomputed();
            uint legacyFundingSequenceLength = legacyState.fundingSequenceLength() - 1;

            // link fundingSequence
            // initialize the _fundingSequence array
            _fundingSequence.push(legacyState.fundingSequence(legacyFundingSequenceLength));
            // get fundingSequence offset
            legacyFundinSequenceOffset = legacyFundingSequenceLength;
        } else {
            // Initialise the funding sequence with 0 initially accrued, so that the first usable funding index is 1.
            _fundingSequence.push(0);
            fundingRateLastRecomputed = 0;
        }

        // set legacyConfigured
        initialized = true;
        // emit event
        emit MarketStateInitialized(marketKey, _legacyContractExists, address(legacyState), legacyFundinSequenceOffset);
    }

    function entryDebtCorrection() external view returns (int128) {
        return _entryDebtCorrection;
    }

    function nextPositionId() external view returns (uint64) {
        return _nextPositionId;
    }

    function fundingSequence(uint index) external view returns (int128) {
        if (_legacyContractExists && index < legacyFundinSequenceOffset) {
            return legacyState.fundingSequence(index);
        }

        return _fundingSequence[index - legacyFundinSequenceOffset];
    }

    function fundingSequenceLength() external view returns (uint) {
        return legacyFundinSequenceOffset + _fundingSequence.length;
    }

    function isFlagged(address account) external view returns (bool) {
        return positionFlagger[account] != address(0);
    }

    function positions(address account) external view returns (Position memory) {
        // If it doesn't exist here check legacy
        if (_legacyContractExists && !_positionMigrated[account] && _positions[account].id == 0) {
            (uint64 id, uint64 lastFundingIndex, uint128 margin, uint128 lastPrice, int128 size) =
                legacyState.positions(account);

            return Position(id, lastFundingIndex, margin, lastPrice, size);
        }

        return _positions[account];
    }

    function delayedOrders(address account) external view returns (DelayedOrder memory) {
        // If it doesn't exist here check legacy
        if (_legacyContractExists && !_delayedOrderMigrated[account] && _delayedOrders[account].sizeDelta == 0) {
            (
                bool isOffchain,
                int128 sizeDelta,
                uint128 desiredFillPrice,
                uint128 targetRoundId,
                uint128 commitDeposit,
                uint128 keeperDeposit,
                uint256 executableAtTime,
                uint256 intentionTime,
                bytes32 trackingCode
            ) = legacyState.delayedOrders(account);
            return
                DelayedOrder(
                    isOffchain,
                    sizeDelta,
                    desiredFillPrice,
                    targetRoundId,
                    commitDeposit,
                    keeperDeposit,
                    executableAtTime,
                    intentionTime,
                    trackingCode
                );
        }

        return _delayedOrders[account];
    }

    /*
     * helper function for migration and analytics. Not linked to legacy state
     */
    function getPositionAddressesPage(uint index, uint pageSize)
        external
        view
        onlyAssociatedContracts
        returns (address[] memory)
    {
        return _positionAddresses.getPage(index, pageSize);
    }

    /*
     * helper function for migration and analytics. Not linked to legacy state
     */
    function getDelayedOrderAddressesPage(uint index, uint pageSize) external view returns (address[] memory) {
        return _delayedOrderAddresses.getPage(index, pageSize);
    }

    /*
     * helper function for migration and analytics. Not linked to legacy state
     */
    function getFlaggedAddressesPage(uint index, uint pageSize) external view returns (address[] memory) {
        return _flaggedAddresses.getPage(index, pageSize);
    }

    /*
     * helper function for migration and analytics. Not linked to legacy state
     */
    function getPositionAddressesLength() external view returns (uint) {
        return _positionAddresses.elements.length;
    }

    /*
     * helper function for migration and analytics. Not linked to legacy state
     */
    function getDelayedOrderAddressesLength() external view returns (uint) {
        return _delayedOrderAddresses.elements.length;
    }

    /*
     * helper function for migration and analytics. Not linked to legacy state
     */
    function getFlaggedAddressesLength() external view returns (uint) {
        return _flaggedAddresses.elements.length;
    }

    function setMarketKey(bytes32 _marketKey) external onlyIfInitialized onlyAssociatedContracts {
        require(marketKey == bytes32(0) || _marketKey == marketKey, "Cannot change market key");
        marketKey = _marketKey;
    }

    function setBaseAsset(bytes32 _baseAsset) external onlyIfInitialized onlyAssociatedContracts {
        require(baseAsset == bytes32(0) || _baseAsset == baseAsset, "Cannot change base asset");
        baseAsset = _baseAsset;
    }

    function setMarketSize(uint128 _marketSize) external onlyIfInitialized onlyAssociatedContracts {
        marketSize = _marketSize;
    }

    function setEntryDebtCorrection(int128 entryDebtCorrection) external onlyIfInitialized onlyAssociatedContracts {
        _entryDebtCorrection = entryDebtCorrection;
    }

    function setNextPositionId(uint64 nextPositionId) external onlyIfInitialized onlyAssociatedContracts {
        _nextPositionId = nextPositionId;
    }

    function setMarketSkew(int128 _marketSkew) external onlyIfInitialized onlyAssociatedContracts {
        marketSkew = _marketSkew;
    }

    function setFundingLastRecomputed(uint32 lastRecomputed) external onlyIfInitialized onlyAssociatedContracts {
        fundingLastRecomputed = lastRecomputed;
    }

    function pushFundingSequence(int128 fundingSequence) external onlyIfInitialized onlyAssociatedContracts {
        _fundingSequence.push(fundingSequence);
    }

    // TODO: Perform this update when maxFundingVelocity and skewScale are modified.
    function setFundingRateLastRecomputed(int128 _fundingRateLastRecomputed)
        external
        onlyIfInitialized
        onlyAssociatedContracts
    {
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
    ) external onlyIfInitialized onlyAssociatedContracts {
        if (_legacyContractExists && !_positionMigrated[account]) {
            // Delete (if needed) from legacy state
            legacyState.deletePosition(account);

            // flag as already migrated
            _positionMigrated[account] = true;
        }

        _positions[account] = Position(id, lastFundingIndex, margin, lastPrice, size);
        _positionAddresses.add(account);
    }

    /**
     * @notice Store a delayed order at the specified account
     * @dev Only the associated contract may call this.
     * @param account The account whose value to set.
     * @param sizeDelta Difference in position to pass to modifyPosition
     * @param desiredFillPrice Desired fill price as usd used on fillPrice at execution
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
        uint128 desiredFillPrice,
        uint128 targetRoundId,
        uint128 commitDeposit,
        uint128 keeperDeposit,
        uint256 executableAtTime,
        uint256 intentionTime,
        bytes32 trackingCode
    ) external onlyIfInitialized onlyAssociatedContracts {
        if (_legacyContractExists && !_delayedOrderMigrated[account]) {
            // Delete (if needed) from legacy state
            legacyState.deleteDelayedOrder(account);

            // flag as already migrated
            _delayedOrderMigrated[account] = true;
        }

        _delayedOrders[account] = DelayedOrder(
            isOffchain,
            sizeDelta,
            desiredFillPrice,
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
    function deletePosition(address account) external onlyIfInitialized onlyAssociatedContracts {
        delete _positions[account];
        if (_positionAddresses.contains(account)) {
            _positionAddresses.remove(account);
        }

        if (_legacyContractExists && !_positionMigrated[account]) {
            legacyState.deletePosition(account);

            // flag as already migrated
            _positionMigrated[account] = true;
        }
    }

    function deleteDelayedOrder(address account) external onlyIfInitialized onlyAssociatedContracts {
        delete _delayedOrders[account];
        if (_delayedOrderAddresses.contains(account)) {
            _delayedOrderAddresses.remove(account);
        }

        // attempt to delete on legacy
        if (_legacyContractExists && !_delayedOrderMigrated[account]) {
            legacyState.deleteDelayedOrder(account);

            // flag as already migrated
            _delayedOrderMigrated[account] = true;
        }
    }

    function flag(address account, address flagger) external onlyIfInitialized onlyAssociatedContracts {
        positionFlagger[account] = flagger;
        _flaggedAddresses.add(account);
    }

    function unflag(address account) external onlyIfInitialized onlyAssociatedContracts {
        delete positionFlagger[account];
        if (_flaggedAddresses.contains(account)) {
            _flaggedAddresses.remove(account);
        }
    }

    modifier onlyIfInitialized() {
        require(initialized, "State not initialized");
        _;
    }

    /* ========== EVENTS ========== */

    event MarketStateInitialized(
        bytes32 indexed marketKey,
        bool legacyContractExists,
        address legacyState,
        uint legacyFundinSequenceOffset
    );
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

    function modifyDebtSharesForMigration(address account, uint amount) external;
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

    modifier onlyAssociatedContracts() {
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

    function isEndorsed(address account) external view returns (bool);

    function allEndorsedAddresses() external view returns (address[] memory);

    function addEndorsedAddresses(address[] calldata addresses) external;

    function removeEndorsedAddresses(address[] calldata addresses) external;
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

    function feesBurned(address account) external view returns (uint);

    function feesToBurn(address account) external view returns (uint);

    function feePeriodDuration() external view returns (uint);

    function isFeesClaimable(address account) external view returns (bool);

    function targetThreshold() external view returns (uint);

    function totalFeesAvailable() external view returns (uint);

    function totalFeesBurned() external view returns (uint);

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

    // PerpsV2 endorsed addresses
    AddressSetLib.AddressSet internal _endorsedAddresses;

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

    function allEndorsedAddresses() external view returns (address[] memory) {
        return _endorsedAddresses.getPage(0, _endorsedAddresses.elements.length);
    }

    function isEndorsed(address account) external view returns (bool) {
        return _endorsedAddresses.contains(account);
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

    /*
     * Removes a group of endorsed addresses.
     * For each address, if it's present is removed, if it's not present it does nothing
     */
    function removeEndorsedAddresses(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            if (_endorsedAddresses.contains(addresses[i])) {
                _endorsedAddresses.remove(addresses[i]);
                emit EndorsedAddressRemoved(addresses[i]);
            }
        }
    }

    /*
     * Adds a group of endorsed addresses.
     * For each address, if it's not present it is added, if it's already present it does nothing
     */
    function addEndorsedAddresses(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            _endorsedAddresses.add(addresses[i]);
            emit EndorsedAddressAdded(addresses[i]);
        }
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

    event EndorsedAddressAdded(address endorsedAddress);

    event EndorsedAddressRemoved(address endorsedAddress);
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
    bytes32 internal constant PARAMETER_MAX_LIQUIDAION_DELTA = "maxLiquidationDelta";
    bytes32 internal constant PARAMETER_MAX_LIQUIDATION_PD = "maxPD";
    // liquidation buffer to prevent negative margin upon liquidation
    bytes32 internal constant PARAMETER_LIQUIDATION_BUFFER_RATIO = "liquidationBufferRatio";

    // Global settings
    // minimum liquidation fee payable to liquidator
    bytes32 internal constant SETTING_MIN_KEEPER_FEE = "perpsV2MinKeeperFee";
    // maximum liquidation fee payable to liquidator
    bytes32 internal constant SETTING_MAX_KEEPER_FEE = "perpsV2MaxKeeperFee";
    // liquidation fee basis points payed to liquidator
    bytes32 internal constant SETTING_LIQUIDATION_FEE_RATIO = "perpsV2LiquidationFeeRatio";
    // minimum initial margin
    bytes32 internal constant SETTING_MIN_INITIAL_MARGIN = "perpsV2MinInitialMargin";
    // fixed liquidation fee to be paid to liquidator keeper (not flagger)
    bytes32 internal constant SETTING_KEEPER_LIQUIRATION_FEE = "keeperLiquidationFee";

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

    function _maxLiquidationDelta(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_LIQUIDAION_DELTA);
    }

    function _maxPD(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_MAX_LIQUIDATION_PD);
    }

    function _liquidationBufferRatio(bytes32 _marketKey) internal view returns (uint) {
        return _parameter(_marketKey, PARAMETER_LIQUIDATION_BUFFER_RATIO);
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

    function _minInitialMargin() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_INITIAL_MARGIN);
    }

    function _keeperLiquidationFee() internal view returns (uint) {
        return _flexibleStorage().getUIntValue(SETTING_CONTRACT_NAME, SETTING_KEEPER_LIQUIRATION_FEE);
    }
}


interface IPerpsV2MarketSettings {
    struct Parameters {
        uint takerFee;
        uint makerFee;
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
        uint liquidationBufferRatio;
        uint maxLiquidationDelta;
        uint maxPD;
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

    function offchainMarketKey(bytes32 _marketKey) external view returns (bytes32);

    function offchainPriceDivergence(bytes32 _marketKey) external view returns (uint);

    function liquidationPremiumMultiplier(bytes32 _marketKey) external view returns (uint);

    function maxPD(bytes32 _marketKey) external view returns (uint);

    function maxLiquidationDelta(bytes32 _marketKey) external view returns (uint);

    function liquidationBufferRatio(bytes32 _marketKey) external view returns (uint);

    function parameters(bytes32 _marketKey) external view returns (Parameters memory);

    function minKeeperFee() external view returns (uint);

    function maxKeeperFee() external view returns (uint);

    function liquidationFeeRatio() external view returns (uint);

    function minInitialMargin() external view returns (uint);

    function keeperLiquidationFee() external view returns (uint);
}


interface IPerpsV2MarketViews {
    /* ---------- Market Details ---------- */

    function marketKey() external view returns (bytes32 key);

    function baseAsset() external view returns (bytes32 key);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingLastRecomputed() external view returns (uint32 timestamp);

    function fundingRateLastRecomputed() external view returns (int128 fundingRate);

    function fundingSequence(uint index) external view returns (int128 netFunding);

    function positions(address account) external view returns (IPerpsV2MarketBaseTypes.Position memory);

    function delayedOrders(address account) external view returns (IPerpsV2MarketBaseTypes.DelayedOrder memory);

    function assetPrice() external view returns (uint price, bool invalid);

    function fillPrice(int sizeDelta) external view returns (uint price, bool invalid);

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

    function isFlagged(address account) external view returns (bool);

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

    function modifyPosition(int sizeDelta, uint desiredFillPrice) external;

    function modifyPositionWithTracking(
        int sizeDelta,
        uint desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function closePosition(uint desiredFillPrice) external;

    function closePositionWithTracking(uint desiredFillPrice, bytes32 trackingCode) external;
}


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/PerpsV2MarketSettings
contract PerpsV2MarketSettings is Owned, MixinPerpsV2MarketSettings, IPerpsV2MarketSettings {
    /* ========== CONSTANTS ========== */

    /* ---------- Address Resolver Configuration ---------- */
    bytes32 public constant CONTRACT_NAME = "PerpsV2MarketSettings";

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

    /*
     * Liquidation price buffer in basis points to prevent negative margin on liquidation.
     */
    function liquidationBufferRatio(bytes32 _marketKey) external view returns (uint) {
        return _liquidationBufferRatio(_marketKey);
    }

    /*
     * The maximum price impact to allow an instantaneous liquidation.
     */
    function maxLiquidationDelta(bytes32 _marketKey) public view returns (uint) {
        return _maxLiquidationDelta(_marketKey);
    }

    /*
     * The maximum premium/discount to allow an instantaneous liquidation.
     */
    function maxPD(bytes32 _marketKey) public view returns (uint) {
        return _maxPD(_marketKey);
    }

    function parameters(bytes32 _marketKey) external view returns (Parameters memory) {
        return
            Parameters(
                _takerFee(_marketKey),
                _makerFee(_marketKey),
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
                _liquidationPremiumMultiplier(_marketKey),
                _liquidationBufferRatio(_marketKey),
                _maxLiquidationDelta(_marketKey),
                _maxPD(_marketKey)
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
     * The minimum margin required to open a position.
     * This quantity must be no less than `minKeeperFee`.
     */
    function minInitialMargin() external view returns (uint) {
        return _minInitialMargin();
    }

    /*
     * The fixed fee sent to a keeper upon liquidation.
     */
    function keeperLiquidationFee() external view returns (uint) {
        return _keeperLiquidationFee();
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

    function setLiquidationBufferRatio(bytes32 _marketKey, uint _ratio) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_LIQUIDATION_BUFFER_RATIO, _ratio);
    }

    function setMaxLiquidationDelta(bytes32 _marketKey, uint _maxLiquidationDelta) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_LIQUIDAION_DELTA, _maxLiquidationDelta);
    }

    function setMaxPD(bytes32 _marketKey, uint _maxPD) public onlyOwner {
        _setParameter(_marketKey, PARAMETER_MAX_LIQUIDATION_PD, _maxPD);
    }

    function setParameters(bytes32 _marketKey, Parameters calldata _parameters) external onlyOwner {
        _recomputeFunding(_marketKey);
        setTakerFee(_marketKey, _parameters.takerFee);
        setMakerFee(_marketKey, _parameters.makerFee);
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
        setLiquidationBufferRatio(_marketKey, _parameters.liquidationBufferRatio);
        setMaxLiquidationDelta(_marketKey, _parameters.maxLiquidationDelta);
        setMaxPD(_marketKey, _parameters.maxPD);
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

    function setMinInitialMargin(uint _minMargin) external onlyOwner {
        require(_minKeeperFee() <= _minMargin, "min margin < liquidation fee");
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_INITIAL_MARGIN, _minMargin);
        emit MinInitialMarginUpdated(_minMargin);
    }

    function setKeeperLiquidationFee(uint _keeperFee) external onlyOwner {
        _flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_KEEPER_LIQUIRATION_FEE, _keeperFee);
        emit KeeperLiquidationFeeUpdated(_keeperFee);
    }

    /* ========== EVENTS ========== */

    event ParameterUpdated(bytes32 indexed marketKey, bytes32 indexed parameter, uint value);
    event ParameterUpdatedBytes32(bytes32 indexed marketKey, bytes32 indexed parameter, bytes32 value);
    event MinKeeperFeeUpdated(uint sUSD);
    event MaxKeeperFeeUpdated(uint sUSD);
    event LiquidationFeeRatioUpdated(uint bps);
    event LiquidationBufferRatioUpdated(uint bps);
    event MinInitialMarginUpdated(uint minMargin);
    event KeeperLiquidationFeeUpdated(uint keeperFee);
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
contract Migration_AnkaaOptimismStep2 is BaseMigration {
    // https://explorer.optimism.io/address/0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;
    address public constant OWNER = 0x6d4a64C57612841c2C6745dB2a4E4db34F002D20;

    // ----------------------------
    // EXISTING SYNTHETIX CONTRACTS
    // ----------------------------

    // https://explorer.optimism.io/address/0xf963a0fc0BFc38FEfE08C6062f2AD9A11AfFDEeb
    PerpsV2MarketState public constant perpsv2marketstatemkrperp_i =
        PerpsV2MarketState(0xf963a0fc0BFc38FEfE08C6062f2AD9A11AfFDEeb);
    // https://explorer.optimism.io/address/0x2C15259D4886e2C0946f9aB7a5E389c86b3c3b04
    PerpsV2ExchangeRate public constant perpsv2exchangerate_i =
        PerpsV2ExchangeRate(0x2C15259D4886e2C0946f9aB7a5E389c86b3c3b04);
    // https://explorer.optimism.io/address/0xd30bdFd7e7a65fE109D5dE1D4e95F3B800FB7463
    FuturesMarketManager public constant futuresmarketmanager_i =
        FuturesMarketManager(0xd30bdFd7e7a65fE109D5dE1D4e95F3B800FB7463);
    // https://explorer.optimism.io/address/0x649F44CAC3276557D03223Dbf6395Af65b11c11c
    PerpsV2MarketSettings public constant perpsv2marketsettings_i =
        PerpsV2MarketSettings(0x649F44CAC3276557D03223Dbf6395Af65b11c11c);
    // https://explorer.optimism.io/address/0xE8c41bE1A167314ABAF2423b72Bf8da826943FFD
    SystemStatus public constant systemstatus_i = SystemStatus(0xE8c41bE1A167314ABAF2423b72Bf8da826943FFD);
    // https://explorer.optimism.io/address/0x2107A107D1043b2c442b8de40d6696C29bD2c5b8
    PerpsV2MarketState public constant perpsv2marketstateyfiperp_i =
        PerpsV2MarketState(0x2107A107D1043b2c442b8de40d6696C29bD2c5b8);
    // https://explorer.optimism.io/address/0xB241aF12256998A0051b93e02027e73CA7E5388d
    PerpsV2MarketState public constant perpsv2marketstatemavperp_i =
        PerpsV2MarketState(0xB241aF12256998A0051b93e02027e73CA7E5388d);
    // https://explorer.optimism.io/address/0xf606E99D6F6a003623eA5764dA119BAEcB2e8C99
    PerpsV2MarketState public constant perpsv2marketstaterplperp_i =
        PerpsV2MarketState(0xf606E99D6F6a003623eA5764dA119BAEcB2e8C99);

    // ----------------------------------
    // NEW CONTRACTS DEPLOYED TO BE ADDED
    // ----------------------------------

    constructor() public BaseMigration(OWNER) {}

    function contractsRequiringOwnership() public pure returns (address[] memory contracts) {
        contracts = new address[](8);
        contracts[0] = address(perpsv2marketstatemkrperp_i);
        contracts[1] = address(perpsv2exchangerate_i);
        contracts[2] = address(futuresmarketmanager_i);
        contracts[3] = address(perpsv2marketsettings_i);
        contracts[4] = address(systemstatus_i);
        contracts[5] = address(perpsv2marketstateyfiperp_i);
        contracts[6] = address(perpsv2marketstatemavperp_i);
        contracts[7] = address(perpsv2marketstaterplperp_i);
    }

    function migrate() external onlyOwner {
        // ACCEPT OWNERSHIP for all contracts that require ownership to make changes
        acceptAll();

        // MIGRATION
        // Add migration contract permission to pause
        systemstatus_i.updateAccessControl("Futures", address(this), true, false);

        perpsv2marketstatemkrperp_i.linkOrInitializeState();
        perpsv2exchangerate_addAssociatedContracts_1();
        futuresmarketmanager_addProxiedMarkets_2();
        perpsv2marketsettings_i.setTakerFee("sMKRPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFee("sMKRPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeDelayedOrder("sMKRPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFeeDelayedOrder("sMKRPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sMKRPERP", 1000000000000000);
        perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sMKRPERP", 200000000000000);
        perpsv2marketsettings_i.setNextPriceConfirmWindow("sMKRPERP", 2);
        perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sMKRPERP", 120);
        perpsv2marketsettings_i.setMinDelayTimeDelta("sMKRPERP", 60);
        perpsv2marketsettings_i.setMaxDelayTimeDelta("sMKRPERP", 6000);
        perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sMKRPERP", 2);
        perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sMKRPERP", 60);
        perpsv2marketsettings_i.setMaxLeverage("sMKRPERP", 27500000000000000000);
        perpsv2marketsettings_i.setMaxMarketValue("sMKRPERP", 750000000000000000000);
        perpsv2marketsettings_i.setMaxFundingVelocity("sMKRPERP", 27000000000000000000);
        perpsv2marketsettings_i.setSkewScale("sMKRPERP", 60000000000000000000000);
        perpsv2marketsettings_i.setOffchainMarketKey("sMKRPERP", "ocMKRPERP");
        perpsv2marketsettings_i.setOffchainPriceDivergence("sMKRPERP", 25000000000000000);
        perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sMKRPERP", 3000000000000000000);
        perpsv2marketsettings_i.setMaxLiquidationDelta("sMKRPERP", 1200000000000000);
        perpsv2marketsettings_i.setLiquidationBufferRatio("sMKRPERP", 15000000000000000);
        perpsv2marketsettings_i.setMaxPD("sMKRPERP", 2400000000000000);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sMKRPERP", 80);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("ocMKRPERP", 80);
        perpsv2marketstateyfiperp_i.linkOrInitializeState();
        perpsv2exchangerate_addAssociatedContracts_28();
        futuresmarketmanager_addProxiedMarkets_29();
        perpsv2marketsettings_i.setTakerFee("sYFIPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFee("sYFIPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeDelayedOrder("sYFIPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFeeDelayedOrder("sYFIPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sYFIPERP", 1000000000000000);
        perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sYFIPERP", 200000000000000);
        perpsv2marketsettings_i.setNextPriceConfirmWindow("sYFIPERP", 2);
        perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sYFIPERP", 120);
        perpsv2marketsettings_i.setMinDelayTimeDelta("sYFIPERP", 60);
        perpsv2marketsettings_i.setMaxDelayTimeDelta("sYFIPERP", 6000);
        perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sYFIPERP", 2);
        perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sYFIPERP", 60);
        perpsv2marketsettings_i.setMaxLeverage("sYFIPERP", 27500000000000000000);
        perpsv2marketsettings_i.setMaxMarketValue("sYFIPERP", 75000000000000000000);
        perpsv2marketsettings_i.setMaxFundingVelocity("sYFIPERP", 27000000000000000000);
        perpsv2marketsettings_i.setSkewScale("sYFIPERP", 2500000000000000000000);
        perpsv2marketsettings_i.setOffchainMarketKey("sYFIPERP", "ocYFIPERP");
        perpsv2marketsettings_i.setOffchainPriceDivergence("sYFIPERP", 25000000000000000);
        perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sYFIPERP", 3000000000000000000);
        perpsv2marketsettings_i.setMaxLiquidationDelta("sYFIPERP", 1200000000000000);
        perpsv2marketsettings_i.setLiquidationBufferRatio("sYFIPERP", 15000000000000000);
        perpsv2marketsettings_i.setMaxPD("sYFIPERP", 2400000000000000);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sYFIPERP", 80);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("ocYFIPERP", 80);
        perpsv2marketstatemavperp_i.linkOrInitializeState();
        perpsv2exchangerate_addAssociatedContracts_55();
        futuresmarketmanager_addProxiedMarkets_56();
        perpsv2marketsettings_i.setTakerFee("sMAVPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFee("sMAVPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeDelayedOrder("sMAVPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFeeDelayedOrder("sMAVPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sMAVPERP", 1000000000000000);
        perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sMAVPERP", 200000000000000);
        perpsv2marketsettings_i.setNextPriceConfirmWindow("sMAVPERP", 2);
        perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sMAVPERP", 120);
        perpsv2marketsettings_i.setMinDelayTimeDelta("sMAVPERP", 60);
        perpsv2marketsettings_i.setMaxDelayTimeDelta("sMAVPERP", 6000);
        perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sMAVPERP", 2);
        perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sMAVPERP", 60);
        perpsv2marketsettings_i.setMaxLeverage("sMAVPERP", 27500000000000000000);
        perpsv2marketsettings_i.setMaxMarketValue("sMAVPERP", 500000000000000000000000);
        perpsv2marketsettings_i.setMaxFundingVelocity("sMAVPERP", 27000000000000000000);
        perpsv2marketsettings_i.setSkewScale("sMAVPERP", 21000000000000000000000000);
        perpsv2marketsettings_i.setOffchainMarketKey("sMAVPERP", "ocMAVPERP");
        perpsv2marketsettings_i.setOffchainPriceDivergence("sMAVPERP", 25000000000000000);
        perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sMAVPERP", 3000000000000000000);
        perpsv2marketsettings_i.setMaxLiquidationDelta("sMAVPERP", 1200000000000000);
        perpsv2marketsettings_i.setLiquidationBufferRatio("sMAVPERP", 15000000000000000);
        perpsv2marketsettings_i.setMaxPD("sMAVPERP", 2400000000000000);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sMAVPERP", 80);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("ocMAVPERP", 80);
        perpsv2marketstaterplperp_i.linkOrInitializeState();
        perpsv2exchangerate_addAssociatedContracts_82();
        futuresmarketmanager_addProxiedMarkets_83();
        perpsv2marketsettings_i.setTakerFee("sRPLPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFee("sRPLPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeDelayedOrder("sRPLPERP", 300000000000000000);
        perpsv2marketsettings_i.setMakerFeeDelayedOrder("sRPLPERP", 300000000000000000);
        perpsv2marketsettings_i.setTakerFeeOffchainDelayedOrder("sRPLPERP", 1500000000000000);
        perpsv2marketsettings_i.setMakerFeeOffchainDelayedOrder("sRPLPERP", 200000000000000);
        perpsv2marketsettings_i.setNextPriceConfirmWindow("sRPLPERP", 2);
        perpsv2marketsettings_i.setDelayedOrderConfirmWindow("sRPLPERP", 120);
        perpsv2marketsettings_i.setMinDelayTimeDelta("sRPLPERP", 60);
        perpsv2marketsettings_i.setMaxDelayTimeDelta("sRPLPERP", 6000);
        perpsv2marketsettings_i.setOffchainDelayedOrderMinAge("sRPLPERP", 2);
        perpsv2marketsettings_i.setOffchainDelayedOrderMaxAge("sRPLPERP", 60);
        perpsv2marketsettings_i.setMaxLeverage("sRPLPERP", 27500000000000000000);
        perpsv2marketsettings_i.setMaxMarketValue("sRPLPERP", 3000000000000000000000);
        perpsv2marketsettings_i.setMaxFundingVelocity("sRPLPERP", 27000000000000000000);
        perpsv2marketsettings_i.setSkewScale("sRPLPERP", 17500000000000000000000);
        perpsv2marketsettings_i.setOffchainMarketKey("sRPLPERP", "ocRPLPERP");
        perpsv2marketsettings_i.setOffchainPriceDivergence("sRPLPERP", 25000000000000000);
        perpsv2marketsettings_i.setLiquidationPremiumMultiplier("sRPLPERP", 3000000000000000000);
        perpsv2marketsettings_i.setMaxLiquidationDelta("sRPLPERP", 1700000000000000);
        perpsv2marketsettings_i.setLiquidationBufferRatio("sRPLPERP", 15000000000000000);
        perpsv2marketsettings_i.setMaxPD("sRPLPERP", 3400000000000000);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("sRPLPERP", 80);
        // Ensure perpsV2 market is paused according to config;
        systemstatus_i.suspendFuturesMarket("ocRPLPERP", 80);
        // Remove permission to migration contract
        systemstatus_i.updateAccessControl("Futures", address(this), false, false);

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

    function perpsv2exchangerate_addAssociatedContracts_1() internal {
        address[] memory perpsv2exchangerate_addAssociatedContracts_associatedContracts_1_0 = new address[](2);
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_1_0[0] = address(
            0xDEbC936c5aDfd1331E5fa4AE76DB7197283342d0
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_1_0[1] = address(
            0xE0d1A14EBC3bc4460fEeB67A45C8198063cCC7c7
        );
        perpsv2exchangerate_i.addAssociatedContracts(perpsv2exchangerate_addAssociatedContracts_associatedContracts_1_0);
    }

    function futuresmarketmanager_addProxiedMarkets_2() internal {
        address[] memory futuresmarketmanager_addProxiedMarkets_marketsToAdd_2_0 = new address[](1);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_2_0[0] = address(0xf7d9Bd13F877171f6C7f93F71bdf8e380335dc12);
        futuresmarketmanager_i.addProxiedMarkets(futuresmarketmanager_addProxiedMarkets_marketsToAdd_2_0);
    }

    function perpsv2exchangerate_addAssociatedContracts_28() internal {
        address[] memory perpsv2exchangerate_addAssociatedContracts_associatedContracts_28_0 = new address[](2);
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_28_0[0] = address(
            0xf7AF14838789093ccD01c67cF9Bc5f602501cEd0
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_28_0[1] = address(
            0x7aF6Be46f83d25902cfa49c9e16BEc54893f25cB
        );
        perpsv2exchangerate_i.addAssociatedContracts(perpsv2exchangerate_addAssociatedContracts_associatedContracts_28_0);
    }

    function futuresmarketmanager_addProxiedMarkets_29() internal {
        address[] memory futuresmarketmanager_addProxiedMarkets_marketsToAdd_29_0 = new address[](1);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_29_0[0] = address(0x6940e7C6125a177b052C662189bb27692E88E9Cb);
        futuresmarketmanager_i.addProxiedMarkets(futuresmarketmanager_addProxiedMarkets_marketsToAdd_29_0);
    }

    function perpsv2exchangerate_addAssociatedContracts_55() internal {
        address[] memory perpsv2exchangerate_addAssociatedContracts_associatedContracts_55_0 = new address[](2);
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_55_0[0] = address(
            0x6A5A1E32216377FC03bFFdC9B33fe29c2f14Ec84
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_55_0[1] = address(
            0xFc6895ff4756985BCa9df2AABB5f31651C591Bef
        );
        perpsv2exchangerate_i.addAssociatedContracts(perpsv2exchangerate_addAssociatedContracts_associatedContracts_55_0);
    }

    function futuresmarketmanager_addProxiedMarkets_56() internal {
        address[] memory futuresmarketmanager_addProxiedMarkets_marketsToAdd_56_0 = new address[](1);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_56_0[0] = address(0x572F816F21F56D47e4c4fA577837bd3f58088676);
        futuresmarketmanager_i.addProxiedMarkets(futuresmarketmanager_addProxiedMarkets_marketsToAdd_56_0);
    }

    function perpsv2exchangerate_addAssociatedContracts_82() internal {
        address[] memory perpsv2exchangerate_addAssociatedContracts_associatedContracts_82_0 = new address[](2);
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_82_0[0] = address(
            0xc9c64cF6D1CE4b41D087F08EdAa9De23262f1EdA
        );
        perpsv2exchangerate_addAssociatedContracts_associatedContracts_82_0[1] = address(
            0xF0671cF8a1a0b3308e84852308F9624B9eC2e28f
        );
        perpsv2exchangerate_i.addAssociatedContracts(perpsv2exchangerate_addAssociatedContracts_associatedContracts_82_0);
    }

    function futuresmarketmanager_addProxiedMarkets_83() internal {
        address[] memory futuresmarketmanager_addProxiedMarkets_marketsToAdd_83_0 = new address[](1);
        futuresmarketmanager_addProxiedMarkets_marketsToAdd_83_0[0] = address(0xfAD0835dAD2985b25ddab17eace356237589E5C7);
        futuresmarketmanager_i.addProxiedMarkets(futuresmarketmanager_addProxiedMarkets_marketsToAdd_83_0);
    }
}