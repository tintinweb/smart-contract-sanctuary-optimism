/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-20
*/

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: PerpsV2MarketState.sol
*
* Latest source (may be newer): https://github.com/Synthetixio/synthetix/blob/master/contracts/PerpsV2MarketState.sol
* Docs: https://docs.synthetix.io/contracts/PerpsV2MarketState
*
* Contract Dependencies: 
*	- IPerpsV2MarketBaseTypes
*	- Owned
*	- StateShared
* Libraries: 
*	- AddressSetLib
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