// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// > [[[[[[[[[[[ Imports ]]]]]]]]]]]

import "../treasury/interface/ITreasuryConfiguration.sol";
import "../lib/Governable.sol";

/**
 * @title TreasuryConfiguration
 * @notice Maintains a configuration of different contracts in the Mirror ecosystem.
 * @author MirrorXYZ
 * @custom:security-contact [email protected]
 */
contract TreasuryConfiguration is
    ITreasuryConfiguration,
    ITreasuryConfigurationEvents,
    Governable
{
    /// @notice Treasury address to receive fees.
    address payable public override treasury;

    /// @notice Tributary registry address to register clones to tributaries.
    address public override tributaryRegistry;

    /// @notice Distribution address to issue rewards.
    address public override distribution;

    /// @notice Fee configuration.
    address public override feeConfiguration;

    /// > [[[[[[[[[[[ Constructor ]]]]]]]]]]]

    constructor(
        address _owner,
        address payable _treasury,
        address _tributaryRegistry,
        address _distribution,
        address _feeConfiguration
    ) Governable(_owner) {
        treasury = _treasury;
        distribution = _distribution;
        tributaryRegistry = _tributaryRegistry;
        feeConfiguration = _feeConfiguration;
    }

    /// > [[[[[[[[[[[ Configuration ]]]]]]]]]]]

    /// @notice Governance can update treasury address.
    function setTreasury(address payable newTreasury)
        external
        override
        onlyGovernance
    {
        emit TreasurySet(treasury, newTreasury);

        treasury = newTreasury;
    }

    /// @notice Governance can update tributary registry.
    function setTributaryRegistry(address newTributaryRegistry)
        external
        override
        onlyGovernance
    {
        emit TributaryRegistrySet(tributaryRegistry, newTributaryRegistry);

        tributaryRegistry = newTributaryRegistry;
    }

    /// @notice Governance can update distribution.
    function setDistribution(address newDistribution)
        external
        override
        onlyGovernance
    {
        emit DistributionSet(distribution, newDistribution);

        distribution = newDistribution;
    }

    /// @notice Governance can update fee configuration.
    function setFeeConfiguration(address newFeeConfiguration)
        external
        override
        onlyGovernance
    {
        emit FeeConfigurationSet(feeConfiguration, newFeeConfiguration);

        feeConfiguration = newFeeConfiguration;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITreasuryConfigurationEvents {
    event TreasurySet(address indexed treasury, address indexed newTreasury);

    event TributaryRegistrySet(
        address indexed tributaryRegistry,
        address indexed newTributaryRegistry
    );

    event DistributionSet(
        address indexed distribution,
        address indexed newDistribution
    );

    event FeeConfigurationSet(
        address indexed feeConfiguration,
        address indexed newFeeConfiguration
    );
}

interface ITreasuryConfiguration {
    function treasury() external returns (address payable);

    function tributaryRegistry() external returns (address);

    function distribution() external returns (address);

    function feeConfiguration() external returns (address);

    function setTreasury(address payable newTreasury) external;

    function setTributaryRegistry(address newTributaryRegistry) external;

    function setDistribution(address newDistribution) external;

    function setFeeConfiguration(address newFeeConfiguration) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Ownable.sol";

interface IGovernable {
    function changeGovernor(address governor_) external;

    function isGovernor() external view returns (bool);

    function governor() external view returns (address);
}

contract Governable is Ownable, IGovernable {
    // Mirror governance contract.
    address public override governor;

    /// > [[[[[[[[[[[ Modifiers ]]]]]]]]]]]

    modifier onlyGovernance() {
        require(isOwner() || isGovernor(), "caller is not governance");
        _;
    }

    modifier onlyGovernor() {
        require(isGovernor(), "caller is not governor");
        _;
    }

    /// > [[[[[[[[[[[ Constructor ]]]]]]]]]]]

    constructor(address owner_) Ownable(owner_) {}

    /// > [[[[[[[[[[[ Administration ]]]]]]]]]]]

    function changeGovernor(address governor_) public override onlyGovernance {
        governor = governor_;
    }

    /// > [[[[[[[[[[[ View Functions ]]]]]]]]]]]

    function isGovernor() public view override returns (bool) {
        return msg.sender == governor;
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