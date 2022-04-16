// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TeleportrDisburser
 */
contract TeleportrDisburser is Ownable {
    /**
     * @notice A struct holding the address and amount to disbursement.
     */
    struct Disbursement {
        uint256 amount;
        address addr;
    }

    /// The total number of disbursements processed.
    uint256 public totalDisbursements;

    /**
     * @notice Emitted any time the balance is withdrawn by the owner.
     * @param owner The current owner and recipient of the funds.
     * @param balance The current contract balance paid to the owner.
     */
    event BalanceWithdrawn(address indexed owner, uint256 balance);

    /**
     * @notice Emitted any time a disbursement is successfuly sent.
     * @param depositId The unique sequence number identifying the deposit.
     * @param to The recipient of the disbursement.
     * @param amount The amount sent to the recipient.
     */
    event DisbursementSuccess(uint256 indexed depositId, address indexed to, uint256 amount);

    /**
     * @notice Emitted any time a disbursement fails to send.
     * @param depositId The unique sequence number identifying the deposit.
     * @param to The intended recipient of the disbursement.
     * @param amount The amount intended to be sent to the recipient.
     */
    event DisbursementFailed(uint256 indexed depositId, address indexed to, uint256 amount);

    /**
     * @notice Initializes a new TeleportrDisburser contract.
     */
    constructor() {
        totalDisbursements = 0;
    }

    /**
     * @notice Accepts a list of Disbursements and forwards the amount paid to
     * the contract to each recipient. The method reverts if there are zero
     * disbursements, the total amount to forward differs from the amount sent
     * in the transaction, or the _nextDepositId is unexpected. Failed
     * disbursements will not cause the method to revert, but will instead be
     * held by the contract and availabe for the owner to withdraw.
     * @param _nextDepositId The depositId of the first Dispursement.
     * @param _disbursements A list of Disbursements to process.
     */
    function disburse(uint256 _nextDepositId, Disbursement[] calldata _disbursements)
        external
        payable
        onlyOwner
    {
        // Ensure there are disbursements to process.
        uint256 _numDisbursements = _disbursements.length;
        require(_numDisbursements > 0, "No disbursements");

        // Ensure the _nextDepositId matches our expected value.
        uint256 _depositId = totalDisbursements;
        require(_depositId == _nextDepositId, "Unexpected next deposit id");
        unchecked {
            totalDisbursements += _numDisbursements;
        }

        // Ensure the amount sent in the transaction is equal to the sum of the
        // disbursements.
        uint256 _totalDisbursed = 0;
        for (uint256 i = 0; i < _numDisbursements; i++) {
            _totalDisbursed += _disbursements[i].amount;
        }
        require(_totalDisbursed == msg.value, "Disbursement total != amount sent");

        // Process disbursements.
        for (uint256 i = 0; i < _numDisbursements; i++) {
            uint256 _amount = _disbursements[i].amount;
            address _addr = _disbursements[i].addr;

            // Deliver the dispursement amount to the receiver. If the
            // disbursement fails, the amount will be kept by the contract
            // rather than reverting to prevent blocking progress on other
            // disbursements.

            // slither-disable-next-line calls-loop,reentrancy-events
            (bool success, ) = _addr.call{ value: _amount, gas: 2300 }("");
            if (success) emit DisbursementSuccess(_depositId, _addr, _amount);
            else emit DisbursementFailed(_depositId, _addr, _amount);

            unchecked {
                _depositId += 1;
            }
        }
    }

    /**
     * @notice Sends the contract's current balance to the owner.
     */
    function withdrawBalance() external onlyOwner {
        address _owner = owner();
        uint256 balance = address(this).balance;
        emit BalanceWithdrawn(_owner, balance);
        payable(_owner).transfer(balance);
    }
}

// SPDX-License-Identifier: MIT

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
}

// SPDX-License-Identifier: MIT

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