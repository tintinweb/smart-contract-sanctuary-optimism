// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "../lib/Ownable.sol";
import {IFeeConfiguration, IFeeConfigurationEvents} from "./interface/IFeeConfiguration.sol";

/**
 * @title FeeConfiguration
 * Allows to turn fees on/off and set minimum and maximum fees.
 * Fee values are stored in Basis Points.
 * @author MirrorXYZ
 */
contract FeeConfiguration is
    Ownable,
    IFeeConfiguration,
    IFeeConfigurationEvents
{
    /// @notice Fee status.
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
    /// @param newFee the new minimum fee allowed.
    function updateMinimumFee(uint16 newFee) external override onlyOwner {
        require(newFee <= maximumFee, "cannot update");

        minimumFee = newFee;

        emit MinimumFee(newFee);
    }

    /// @notice Update the maximum fee allowed.
    /// @param newFee the new maximum fee allowed.
    function updateMaximumFee(uint16 newFee) external override onlyOwner {
        require(newFee >= minimumFee, "cannot update");

        maximumFee = newFee;

        emit MaximumFee(newFee);
    }

    /// @notice Check if a fee is valid.
    /// @param fee the fee to validate.
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

interface IOwnable {
    function transferOwnership(address nextOwner_) external;

    function cancelOwnershipTransfer() external;

    function acceptOwnership() external;

    function renounceOwnership() external;

    function isOwner() external view returns (bool);

    function isNextOwner() external view returns (bool);
}

contract Ownable is IOwnable, IOwnableEvents {
    address public owner;
    address private nextOwner;

    /// > [[[[[[[[[[[ Modifiers ]]]]]]]]]]]

    modifier onlyOwner() {
        require(isOwner(), "caller is not the owner.");
        _;
    }

    modifier onlyNextOwner() {
        require(isNextOwner(), "current owner must set caller as next owner.");
        _;
    }

    /// @notice Initialize contract by setting the initial owner.
    constructor(address owner_) {
        _setInitialOwner(owner_);
    }

    /// @notice Initiate ownership transfer by setting nextOwner.
    function transferOwnership(address nextOwner_) external override onlyOwner {
        require(nextOwner_ != address(0), "Next owner is the zero address.");

        nextOwner = nextOwner_;
    }

    /// @notice Cancel ownership transfer by deleting nextOwner.
    function cancelOwnershipTransfer() external override onlyOwner {
        delete nextOwner;
    }

    /// @notice Accepts ownership transfer by setting owner.
    function acceptOwnership() external override onlyNextOwner {
        delete nextOwner;

        owner = msg.sender;

        emit OwnershipTransferred(owner, msg.sender);
    }

    /// @notice Renounce ownership by setting owner to zero address.
    function renounceOwnership() external override onlyOwner {
        _renounceOwnership();
    }

    /// @notice Returns true if the caller is the current owner.
    function isOwner() public view override returns (bool) {
        return msg.sender == owner;
    }

    /// @notice Returns true if the caller is the next owner.
    function isNextOwner() public view override returns (bool) {
        return msg.sender == nextOwner;
    }

    /// > [[[[[[[[[[[ Internal Functions ]]]]]]]]]]]

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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IFeeConfigurationEvents {
    event FeeSwitch(bool on);

    event MinimumFee(uint16 fee);

    event MaximumFee(uint16 fee);
}

interface IFeeConfiguration {
    function on() external returns (bool);

    function maximumFee() external returns (uint16);

    function minimumFee() external returns (uint16);

    function switchFee() external;

    function updateMinimumFee(uint16 newFee) external;

    function updateMaximumFee(uint16 newFe) external;

    function valid(uint16) external view returns (bool);
}