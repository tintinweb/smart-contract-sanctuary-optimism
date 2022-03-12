// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;
/* solhint-disable reason-string */

import { CircusAccessControlled } from "../libraries/access/CircusAccessControlled.sol";
import { ICircusAuthority } from "../interfaces/ICircusAuthority.sol";

/// @title CircusAuthority
contract CircusAuthority is CircusAccessControlled, ICircusAuthority {
	/* ========== STATE VARIABLES ========== */

	address public override governor;
	address public override guardian;
	address public override policy;
	address public override vault;

	address public newGovernor;
	address public newGuardian;
	address public newPolicy;
	address public newVault;

	/* ========== CONSTRUCTOR ========== */

	constructor(
		address _governor,
		address _guardian,
		address _policy,
		address _vault
	) CircusAccessControlled(ICircusAuthority(address(this))) {
		governor = _governor;
		emit GovernorPushed(address(0), governor, true);

		guardian = _guardian;
		emit GuardianPushed(address(0), guardian, true);

		policy = _policy;
		emit PolicyPushed(address(0), policy, true);

		vault = _vault;
		emit VaultPushed(address(0), vault, true);
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	function pushGovernor(address _newGovernor, bool _effectiveImmediately) external onlyGovernor {
		if (_effectiveImmediately) governor = _newGovernor;
		newGovernor = _newGovernor;
		emit GovernorPushed(governor, newGovernor, _effectiveImmediately);
	}

	function pushGuardian(address _newGuardian, bool _effectiveImmediately) external onlyGovernor {
		if (_effectiveImmediately) guardian = _newGuardian;
		newGuardian = _newGuardian;
		emit GuardianPushed(guardian, newGuardian, _effectiveImmediately);
	}

	function pushPolicy(address _newPolicy, bool _effectiveImmediately) external onlyGovernor {
		if (_effectiveImmediately) policy = _newPolicy;
		newPolicy = _newPolicy;
		emit PolicyPushed(policy, newPolicy, _effectiveImmediately);
	}

	function pushVault(address _newVault, bool _effectiveImmediately) external onlyGovernor {
		if (_effectiveImmediately) vault = _newVault;
		newVault = _newVault;
		emit VaultPushed(vault, newVault, _effectiveImmediately);
	}

	function pullGovernor() external {
		require(msg.sender == newGovernor, "CircusAuthority::pullGovernor: caller is not the new governor");
		emit GovernorPulled(governor, newGovernor);
		governor = newGovernor;
	}

	function pullGuardian() external {
		require(msg.sender == newGuardian, "CircusAuthority::pullGuardian: caller is not the new guardian");
		emit GuardianPulled(guardian, newGuardian);
		guardian = newGuardian;
	}

	function pullPolicy() external {
		require(msg.sender == newPolicy, "CircusAuthority::pullPolicy: caller is not the new governance");
		emit PolicyPulled(policy, newPolicy);
		policy = newPolicy;
	}

	function pullVault() external {
		require(msg.sender == newVault, "CircusAuthority::pullVault: caller is not the new vault");
		emit VaultPulled(vault, newVault);
		vault = newVault;
	}
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;
/* solhint-disable reason-string */

import { ICircusAuthority } from "../../interfaces/ICircusAuthority.sol";

abstract contract CircusAccessControlled {
	/* ========== EVENTS ========== */

	event AuthorityUpdated(ICircusAuthority indexed authority);

	/* ========== STATE VARIABLES ========== */

	ICircusAuthority public authority;

	/* ========== CONSTRUCTOR ========== */

	constructor(ICircusAuthority _authority) {
		authority = _authority;
		emit AuthorityUpdated(_authority);
	}

	/* ========== MODIFIERS ========== */

	modifier onlyGovernor() {
		require(msg.sender == authority.governor(), "CircusAccessControlled::onlyGovernor: caller is not the governor");
		_;
	}

	modifier onlyGuardian() {
		require(msg.sender == authority.guardian(), "CircusAccessControlled::onlyGuardian: caller is not the guardian");
		_;
	}

	modifier onlyGovernorOrGuardian() {
		require(
			msg.sender == authority.governor() || msg.sender == authority.guardian(),
			"CircusAccessControlled::onlyGovernorOrGuardian: caller is neither governor nor guardian"
		);
		_;
	}

	modifier onlyPolicy() {
		require(msg.sender == authority.policy(), "CircusAccessControlled::onlyPolicy: caller is not the governance");
		_;
	}

	modifier onlyVault() {
		require(msg.sender == authority.vault(), "CircusAccessControlled::onlyVault: caller is not the vault");
		_;
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	function setAuthority(ICircusAuthority _newAuthority) external onlyGovernor {
		authority = _newAuthority;
		emit AuthorityUpdated(_newAuthority);
	}
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface ICircusAuthority {
	/* ========== EVENTS ========== */

	event GovernorPushed(address indexed from, address indexed to, bool immediately);
	event GuardianPushed(address indexed from, address indexed to, bool immediately);
	event PolicyPushed(address indexed from, address indexed to, bool immediately);
	event VaultPushed(address indexed from, address indexed to, bool immediately);

	event GovernorPulled(address indexed from, address indexed to);
	event GuardianPulled(address indexed from, address indexed to);
	event PolicyPulled(address indexed from, address indexed to);
	event VaultPulled(address indexed from, address indexed to);

	/* ========== VIEW FUNCTIONS ========== */

	function governor() external view returns (address);

	function guardian() external view returns (address);

	function policy() external view returns (address);

	function vault() external view returns (address);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function pushGovernor(address newGovernor, bool effectiveImmediately) external;

	function pushGuardian(address newGuardian, bool effectiveImmediately) external;

	function pushPolicy(address newPolicy, bool effectiveImmediately) external;

	function pushVault(address newVault, bool effectiveImmediately) external;

	function pullGovernor() external;

	function pullGuardian() external;

	function pullPolicy() external;

	function pullVault() external;
}