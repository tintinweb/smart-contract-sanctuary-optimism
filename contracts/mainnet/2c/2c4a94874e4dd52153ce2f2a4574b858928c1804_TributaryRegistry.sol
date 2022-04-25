// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// > [[[[[[[[[[[ Imports ]]]]]]]]]]]

import "../treasury/interface/ITributaryRegistry.sol";
import "../lib/Governable.sol";

/**
 * @title TributaryRegistry
 * @notice Allows a registrar contract to register a new proxy as a block
 * that directs Mirror Token distribution to a tributary.
 * Ensures that the tributary is a Mirror DAO member, and that only a valid
 * "Mirror Economic Block" created by a registered registrar, can contribute ETH
 * to the treasury.
 * Nomenclature:
 *   - economic producer: asset contract contributing to the treasury.
 *   - singletone producer: non-asset economic producer e.g. marketplace/auction etc.
 *   - tributary: an account that receives rewards on behalf of the economic producer.
 *   - registrar: a contract usually a factory, that is allowed to register
 *     an economic producer to a tributary.
 * @author MirrorXYZ
 * @custom:security-contact [email protected]
 */
contract TributaryRegistry is Governable, ITributaryRegistry {
    /// @notice Allowed registrars.
    mapping(address => bool) public override allowedRegistrar;

    /// @notice Economic producer to tributary.
    mapping(address => address) public override producerToTributary;

    /// @notice Singletone producer to tributary.
    mapping(address => bool) public override singletonProducer;

    /// > [[[[[[[[[[[ Modifiers ]]]]]]]]]]]

    modifier onlyRegistrar() {
        require(allowedRegistrar[msg.sender], "sender not registered");
        _;
    }

    constructor(address _owner) Governable(_owner) {}

    /// > [[[[[[[[[[[ Configuration ]]]]]]]]]]]

    /// @notice Adds a new registrar to register tributaries.
    /// @param registrar new registrar
    function addRegistrar(address registrar) public override onlyGovernance {
        allowedRegistrar[registrar] = true;
    }

    /// @notice Removes an existing registrar.
    /// @param registrar registrar to remove.
    function removeRegistrar(address registrar) public override onlyGovernance {
        delete allowedRegistrar[registrar];
    }

    /// @notice Adds a new singletone producer.
    /// @param producer new producer.
    function addSingletonProducer(address producer)
        public
        override
        onlyGovernance
    {
        singletonProducer[producer] = true;
    }

    /// @notice Remove a an existing singletone producer.
    /// @param producer producer to remove.
    function removeSingletonProducer(address producer)
        public
        override
        onlyGovernance
    {
        delete singletonProducer[producer];
    }

    /// > [[[[[[[[[[[ Tributary Configuration ]]]]]]]]]]]

    /// @notice Allows the producer to update to a new tributary.
    /// @param producer the producer to update register.
    /// @param newTributary the tributary for the producer.
    function setTributary(address producer, address newTributary)
        external
        override
        onlyRegistrar
    {
        // Allow the current tributary to update to a new tributary.
        producerToTributary[producer] = newTributary;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITributaryRegistry {
    function allowedRegistrar(address account) external view returns (bool);

    function producerToTributary(address producer)
        external
        view
        returns (address tributary);

    function singletonProducer(address producer) external view returns (bool);

    function addRegistrar(address registrar) external;

    function removeRegistrar(address registrar) external;

    function addSingletonProducer(address producer) external;

    function removeSingletonProducer(address producer) external;

    function setTributary(address producer, address newTributary) external;
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