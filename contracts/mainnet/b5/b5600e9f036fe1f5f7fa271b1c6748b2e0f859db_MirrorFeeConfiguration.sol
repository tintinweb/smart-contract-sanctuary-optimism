// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "../lib/Ownable.sol";

interface IMirrorFeeConfigurationEvents {
    event FeeSwitch(bool on);

    event MinimumFee(uint16 fee);

    event MaximumFee(uint16 fee);
}

interface IMirrorFeeConfiguration {
    function on() external returns (bool);

    function maximumFee() external returns (uint16);

    function minimumFee() external returns (uint16);

    function switchFee() external;

    function updateMinimumFee(uint16 newFee) external;

    function updateMaximumFee(uint16 newFe) external;

    function valid(uint16) external view returns (bool);
}

/**
 * @title MirrorFeeConfiguration
 * Allows to turn fees on and off. Fee values are stored in Basis Points.
 * @author MirrorXYZ
 */
contract MirrorFeeConfiguration is
    Ownable,
    IMirrorFeeConfiguration,
    IMirrorFeeConfigurationEvents
{
    bool public on = false;

    uint16 public override minimumFee = 250;

    uint16 public override maximumFee = 500;

    constructor(address owner_) Ownable(owner_) {}

    /// @notice Toggle fees on/off.
    function switchFee() external onlyOwner {
        on = !on;

        emit FeeSwitch(on);
    }

    /// @notice Update the minimum fee allowed.
    function updateMinimumFee(uint16 newFee) external override onlyOwner {
        require(newFee <= maximumFee, "cannot update");

        minimumFee = newFee;

        emit MinimumFee(newFee);
    }

    /// @notice Update the maximum fee allowed.
    function updateMaximumFee(uint16 newFee) external override onlyOwner {
        require(newFee >= minimumFee, "cannot update");

        maximumFee = newFee;

        emit MaximumFee(newFee);
    }

    /// @notice Check if a fee is valid.
    function valid(uint16 fee) external view returns (bool) {
        return (minimumFee <= fee) && (fee <= maximumFee);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOwnableEvents {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}

contract Ownable is IOwnableEvents {
    address public owner;
    address private nextOwner;

    // modifiers

    modifier onlyOwner() {
        require(isOwner(), "caller is not the owner.");
        _;
    }

    modifier onlyNextOwner() {
        require(isNextOwner(), "current owner must set caller as next owner.");
        _;
    }

    /**
     * @dev Initialize contract by setting transaction submitter as initial owner.
     */
    constructor(address owner_) {
        _setInitialOwner(owner_);
    }

    /**
     * @dev Initiate ownership transfer by setting nextOwner.
     */
    function transferOwnership(address nextOwner_) external onlyOwner {
        require(nextOwner_ != address(0), "Next owner is the zero address.");

        nextOwner = nextOwner_;
    }

    /**
     * @dev Cancel ownership transfer by deleting nextOwner.
     */
    function cancelOwnershipTransfer() external onlyOwner {
        delete nextOwner;
    }

    /**
     * @dev Accepts ownership transfer by setting owner.
     */
    function acceptOwnership() external onlyNextOwner {
        delete nextOwner;

        owner = msg.sender;

        emit OwnershipTransferred(owner, msg.sender);
    }

    /**
     * @dev Renounce ownership by setting owner to zero address.
     */
    function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }

    /**
     * @dev Returns true if the caller is the next owner.
     */
    function isNextOwner() public view returns (bool) {
        return msg.sender == nextOwner;
    }

    function _setOwner(address previousOwner, address newOwner) internal {
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, owner);
    }

    function _setInitialOwner(address newOwner) internal {
        owner = newOwner;
        emit OwnershipTransferred(address(0), newOwner);
    }

    function _renounceOwnership() internal {
        emit OwnershipTransferred(owner, address(0));

        owner = address(0);
    }
}