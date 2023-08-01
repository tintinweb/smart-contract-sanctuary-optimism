// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
//
// BattleSettlement.sol
//
// Another World's onchain settlement for season 1 battles (one contract per battle). This is one time use contract and meant for being deployed on extremely cheap gas public chain (for public verification)
//

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BattleSettlement is Ownable {
    event Snapshot(address[], uint256[], uint256[]);
    event Settle(address[], uint256[]);
    event StartEndTime(uint256, uint256);
    event NewSettlementOperator(address);

    string public name = "BattleSettlement";
    string public symbol = "BS";
    string public treasureNetwork = "";
    string public notes =
        "This contract does snapshots and settle player's token balance onchain.";

    mapping(address => bool) public settlementOperator;

    bool public isSettled = false;

    uint256 public startTs = 0;
    uint256 public endTs = 0;
    uint256 public constant duration = 10 minutes;

    // player balances with item ids
    mapping(address => mapping(uint256 => uint256)) public balance;

    // readable item names
    mapping(uint256 => string) public itemNames;

    // address utils
    address[] public addresses;
    mapping(address => bool) private addressUsed;
    uint256 public addressCounter = 0;

    // item id utils
    uint256[] public itemIds;
    mapping(uint256 => bool) private itemIdUsed;
    uint256 public itemCounter = 0;

    constructor() {
        settlementOperator[msg.sender] = true; // default operator
    }

    function setTreasureNetwork(string calldata newTreasureNetwork) public onlyOwner {
        treasureNetwork = newTreasureNetwork;
    }

    function setItemName(uint256 id, string calldata itemName) public {
        require(settlementOperator[msg.sender], "invalid operator"); // only settlementOperator can set item names
        itemNames[id] = itemName;
    }

    // owner can update vault operator
    function setSettlementOperator(
        address newSettlementOperator
    ) public onlyOwner {
        require(newSettlementOperator != address(0));
        settlementOperator[newSettlementOperator] = true;
        emit NewSettlementOperator(newSettlementOperator);
    }

    // operator setup battle
    function setBattle(uint256 startTime) public {
        require(settlementOperator[msg.sender], "invalid operator"); // only settlementOperator can settle
        startTs = startTime;
        endTs = startTs + duration;
        emit StartEndTime(startTime, endTs);
    }

    // settle all player addresses (everyone can call settle() after end time)
    function settled()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        require(startTs > 0, "invalid start time");
        require(block.timestamp > endTs, "cannot settle before it ends");
        require(isSettled, "not settled");
        return (addresses, itemIds);
    }

    // snapshot players' balances in this contract (operator only)
    function snapshot(
        address[] calldata playerAddresses,
        uint256[] calldata playerItemIds,
        uint256[] calldata itemBalances
    ) public {
        require(!isSettled, "cannot snapshot after settlement");
        require(settlementOperator[msg.sender], "invalid operator"); // only settlementOperator can snapshot
        require(startTs > 0, "invalid start time");
        require(block.timestamp > startTs, "cannot snapshot before it starts");

        if (block.timestamp > endTs) {
            isSettled = true;
            emit Settle(addresses, itemIds);
        } else {
            for (uint256 i = 0; i < playerAddresses.length; i++) {
                balance[playerAddresses[i]][playerItemIds[i]] = itemBalances[i];
                if (!addressUsed[playerAddresses[i]]) {
                    addressUsed[playerAddresses[i]] = true;
                    addresses.push(playerAddresses[i]);
                    addressCounter++;
                }

                if (!itemIdUsed[playerItemIds[i]]) {
                    itemIdUsed[playerItemIds[i]] = true;
                    itemIds.push(playerItemIds[i]);
                    itemCounter++;
                }
            }
            emit Snapshot(playerAddresses, playerItemIds, itemBalances);
        }
    }
}