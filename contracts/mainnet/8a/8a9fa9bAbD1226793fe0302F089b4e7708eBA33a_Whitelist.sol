//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelist is Ownable {
    mapping(bytes32 => int8) private codes;
    mapping(address => int8) private claimed_addresses;
    mapping(int8 => uint) private claimed_by_tier;
    mapping(int8 => uint) private unclaimed_code;

    constructor() {
    }

    function addCode(bytes32 _hashed_code, int8 _tier) public onlyOwner {
        require(codes[_hashed_code] == 0, "Duplicated hash");
        require(_tier > 0, "Invalid tier");
        codes[_hashed_code] = _tier;
        unclaimed_code[_tier]++;
    }

    function addCodes(bytes32[] memory _hashed_codes, int8[] memory _tiers) public onlyOwner {
        require(_hashed_codes.length == _tiers.length, "Both array must have the same length");
        for (uint256 i = 0; i < _hashed_codes.length; i++)
            addCode(_hashed_codes[i], _tiers[i]);
    }

    function removeCode(bytes32 _hashed_code) public onlyOwner {
        require(codes[_hashed_code] > 0, "Invalid code");
        int8 tier = codes[_hashed_code];
        codes[_hashed_code] = 0;
        unclaimed_code[tier]--;
    }

    function unwhitelistAddress(address addr) public onlyOwner() {
        require(claimed_addresses[addr] > 0, "Address is not whitelisted");
        int8 tier = claimed_addresses[addr];
        claimed_addresses[addr] = 0;
        claimed_by_tier[tier]--;
    }

    function unclaimedCodeCount(int8 _tier) public view returns (uint) {
        return unclaimed_code[_tier];
    }

    function hash(string memory _string) private pure returns(bytes32) {
        return keccak256(abi.encodePacked(_string));
    }

    function claim(string memory _code) public {
        require(claimed_addresses[msg.sender] == 0, "Address already claimed a code");
        bytes32 hashed_code = hash(_code);
        int8 tier = codes[hashed_code];
        assert(tier > 0);
        codes[hashed_code] = -1;
        claimed_addresses[msg.sender] = tier;
        claimed_by_tier[tier]++;
        unclaimed_code[tier]--;
    }

    function isWhitelist(address addr) public view returns (int8) {
        return claimed_addresses[addr];
    }

    function tierClaimedCount(int8 tier) public view returns (uint) {
        return claimed_by_tier[tier];
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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