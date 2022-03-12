// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.11;
/* solhint-disable not-rely-on-time, reason-string, var-name-mixedcase */

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { CircusAccessControlled, ICircusAuthority } from "./libraries/access/CircusAccessControlled.sol";
import { IBalloons } from "./interfaces/IBalloons.sol";
import { IGoldenTickets } from "./interfaces/IGoldenTickets.sol";
import { IGovernableTreasury } from "./interfaces/IGovernableTreasury.sol";
import { IBalloonsVendingCalculator } from "./interfaces/IBalloonsVendingCalculator.sol";

/**
 * @title BarnabyBobSafe
 * @notice Governable treasury with the purpose of:
 * - backing the 🎟️s intrinsic (and floor) value
 * - allowing the management and productive allocation of excess reserves
 * - allowing for the minting of new 🎟️ and for incurring debt against excess reserves
 * @dev Too many things to explain here!
 */
contract BarnabyBobSafe is CircusAccessControlled, IGovernableTreasury {
	/* ========== DEPENDENCIES ========== */

	using SafeERC20 for IERC20;
	using SafeERC20 for IBalloons;

	/* ========== STATE VARIABLES ========== */

	IGoldenTickets public immutable TICKETS;
	IBalloons public balloons;
	Policy[] public policyQueue;

	mapping(PolicyAction => address[]) public registry;
	mapping(PolicyAction => mapping(address => bool)) public permissions;
	mapping(address => address) public bondCalculator;
	mapping(address => uint256) public debtLimitOf;

	uint256 public totalReserves;
	uint256 public totalDebt;
	uint256 public ticketsDebt;

	bool public timelockEnabled;
	bool public initialized;

	uint256 public policyQueueTimelock;
	uint256 public onChainGovernanceTimelock;

	/* ========== CONSTRUCTOR ========== */

	constructor(
		IGoldenTickets _tickets,
		uint256 _timelock,
		ICircusAuthority _authority
	) CircusAccessControlled(_authority) {
		require(address(_tickets) != address(0), unicode"BarnabyBobSafe::constructor: 🎟️ cannot be the 0-address");

		TICKETS = _tickets;
		policyQueueTimelock = _timelock;

		timelockEnabled = false;
		initialized = false;
	}

	/* ========== VIEW FUNCTIONS ========== */

	/**
	 * @notice Returns supply metric that cannot be manipulated by debt
	 * @dev Use this anytime you need to query the safest 🎟️ supply source
	 */
	function baseSupply() external view override returns (uint256) {
		return TICKETS.totalSupply() - ticketsDebt;
	}

	/**
	 * @notice Returns excess reserves not backing tokens
	 * @return uint256
	 */
	function excessReserves() public view override returns (uint256) {
		return totalReserves - TICKETS.totalSupply() - totalDebt;
	}

	/**
	 * @notice Returns the nominal valuation of the given asset in 🎟️ units
	 * @param _token address
	 * @param _amount uint256
	 * @return value_ uint256
	 */
	function tokenValue(address _token, uint256 _amount) public view override returns (uint256 value_) {
		value_ = (_amount * (10**TICKETS.decimals())) / (10**IERC20Metadata(_token).decimals());

		if (permissions[PolicyAction.LIQUIDITY_TOKEN][_token]) {
			if (bondCalculator[_token] == address(0)) {
				return 0;
			}
			value_ = IBalloonsVendingCalculator(bondCalculator[_token]).valuation(_token, _amount);
		}
	}

	/**
	 * @notice Checks in the registry if the given address has the given policy action
	 * @return bool Whether there was a match
	 * @return uint256 At what index in the registry the match was found, if any
	 */
	function indexInRegistry(address _target, PolicyAction _policyAction) public view returns (bool, uint256) {
		address[] memory entries = registry[_policyAction];
		for (uint256 i = 0; i < entries.length; i++) {
			if (_target == entries[i]) {
				return (true, i);
			}
		}
		return (false, 0);
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	/**
	 * @notice Allows approved depositors to deposit assets in exchange for 🎟️
	 * @param _amount uint256
	 * @param _token address
	 * @param _excessReservesAmount uint256
	 * @return send_ uint256
	 */
	function deposit(
		uint256 _amount,
		address _token,
		uint256 _excessReservesAmount
	) external override returns (uint256 send_) {
		if (permissions[PolicyAction.RESERVE_TOKEN][_token]) {
			require(permissions[PolicyAction.RESERVE_DEPOSITOR][msg.sender], "BarnabyBobSafe::deposit: unauthorized RD");
		} else if (permissions[PolicyAction.LIQUIDITY_TOKEN][_token]) {
			require(permissions[PolicyAction.LIQUIDITY_DEPOSITOR][msg.sender], "BarnabyBobSafe::deposit: unauthorized LD");
		} else {
			revert("BarnabyBobSafe::deposit: unsupported reserve or liquidity token");
		}

		IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

		uint256 value = tokenValue(_token, _amount);
		// mint the needed 🎟️ and store the asset among the reserves
		send_ = value - _excessReservesAmount;

		if (send_ > 0) {
			TICKETS.mint(msg.sender, send_);
		}

		totalReserves += value;

		emit Deposit(_token, _amount, value);
	}

	/**
	 * @notice Allows approved addresses to burn 🎟️ for underlying reserves
	 * @param _amount uint256
	 * @param _token address
	 */
	function withdraw(uint256 _amount, address _token) external override {
		require(permissions[PolicyAction.RESERVE_TOKEN][_token], "BarnabyBobSafe::withdraw: unsupported reserve token");
		require(
			permissions[PolicyAction.RESERVE_SPENDER][msg.sender] == true,
			"BarnabyBobSafe::withdraw: unauthorized RS"
		);

		uint256 value = tokenValue(_token, _amount);
		TICKETS.burnFrom(msg.sender, value);

		totalReserves -= value;

		IERC20(_token).safeTransfer(msg.sender, _amount);

		emit Withdrawal(_token, _amount, value);
	}

	/**
	 * @notice Allows approved address to borrow reserves.
	 * The debt functions allow approved addresses to borrow treasury assets or 🎟️ from the treasury, using 🎈 as collateral.
	 * This might allow an 🎈 holder to provide 🎟️ liquidity without taking on the opportunity cost of un-staking, or
	 * alter their backing without imposing risk onto the treasury.

	 * Many of these use cases are yet to be defined, but they appear promising. However, we urge the community to think
	 * critically and move slowly upon proposals to acquire these permissions.
	 * @param _amount uint256
	 * @param _token address
	 */
	function incurDebt(uint256 _amount, address _token) external override {
		uint256 value;
		if (_token == address(TICKETS)) {
			require(
				permissions[PolicyAction.TICKETS_DEBTOR][msg.sender],
				unicode"BarnabyBobSafe::incurDebt: unauthorized 🎟️ debtor"
			);
			require(_token == address(TICKETS), unicode"BarnabyBobSafe::incurDebt: token is not 🎟️");
			value = _amount;
		} else {
			require(
				permissions[PolicyAction.RESERVE_DEBTOR][msg.sender],
				"BarnabyBobSafe::incurDebt: unauthorized reserve debtor"
			);
			require(
				permissions[PolicyAction.RESERVE_TOKEN][_token],
				"BarnabyBobSafe::incurDebt: unsupported reserve token"
			);
			value = tokenValue(_token, _amount);
		}
		require(value != 0, "BarnabyBobSafe::incurDebt: asset value is 0");

		balloons.changeDebt(value, msg.sender, true);
		require(
			balloons.debtBalances(msg.sender) <= debtLimitOf[msg.sender],
			"BarnabyBobSafe::incurDebt: exceeds account debt limit"
		);
		totalDebt += value;

		if (_token == address(TICKETS)) {
			TICKETS.mint(msg.sender, value);
			ticketsDebt += value;
		} else {
			totalReserves -= value;
			IERC20(_token).safeTransfer(msg.sender, _amount);
		}

		emit CreateDebt(msg.sender, _token, _amount, value);
	}

	/**
	 * @notice Allows approved address to repay borrowed reserves with reserves
	 * @param _amount uint256
	 * @param _token address
	 */
	function repayDebtWithReserve(uint256 _amount, address _token) external override {
		require(
			permissions[PolicyAction.RESERVE_DEBTOR][msg.sender],
			"BarnabyBobSafe::repayDebtWithReserve: unauthorized reserve debtor"
		);
		require(
			permissions[PolicyAction.RESERVE_TOKEN][_token],
			"BarnabyBobSafe::repayDebtWithReserve: unsupported reserve token"
		);

		IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

		uint256 value = tokenValue(_token, _amount);
		balloons.changeDebt(value, msg.sender, false);
		totalDebt -= value;

		totalReserves += value;

		emit RepayDebt(msg.sender, _token, _amount, value);
	}

	/**
	 * @notice Allows approved address to repay borrowed reserves with 🎟️
	 * @param _amount uint256
	 */
	function repayDebtWithTickets(uint256 _amount) external {
		require(
			permissions[PolicyAction.RESERVE_DEBTOR][msg.sender] || permissions[PolicyAction.TICKETS_DEBTOR][msg.sender],
			"BarnabyBobSafe::repayDebtWithReserve: unauthorized debtor"
		);

		TICKETS.burnFrom(msg.sender, _amount);

		balloons.changeDebt(_amount, msg.sender, false);
		totalDebt -= _amount;
		ticketsDebt -= _amount;

		emit RepayDebt(msg.sender, address(TICKETS), _amount, _amount);
	}

	/**
	 * @notice Allows approved addresses to manage excess reserve assets
	 * @param _token address
	 * @param _amount uint256
	 */
	function manage(address _token, uint256 _amount) external override {
		if (permissions[PolicyAction.LIQUIDITY_TOKEN][_token]) {
			require(permissions[PolicyAction.LIQUIDITY_MANAGER][msg.sender], "BarnabyBobSafe::manage: unauthorized LM");
		} else {
			require(permissions[PolicyAction.RESERVE_MANAGER][msg.sender], "BarnabyBobSafe::manage: unauthorized RM");
		}

		if (permissions[PolicyAction.RESERVE_TOKEN][_token] || permissions[PolicyAction.LIQUIDITY_TOKEN][_token]) {
			uint256 value = tokenValue(_token, _amount);
			require(value <= excessReserves(), "BarnabyBobSafe::manage: insufficient excess reserves");
			totalReserves -= value;
		}

		IERC20(_token).safeTransfer(msg.sender, _amount);
		emit ReservesManaged(_token, _amount);
	}

	/// @notice Mints new 🎟️ against excess reserves for the recipient
	function mint(address _recipient, uint256 _amount) external override {
		require(permissions[PolicyAction.REWARD_MANAGER][msg.sender], "BarnabyBobSafe::mint: unauthorized RM");
		require(_amount <= excessReserves(), "BarnabyBobSafe::mint: insufficient excess reserves");

		TICKETS.mint(_recipient, _amount);
		emit Minted(msg.sender, _recipient, _amount);
	}

	/**
	 * @notice Reports inventory of all tracked assets
	 * @dev Always consolidate to recognized reserves before auditing
	 */
	function auditReserves() external onlyGovernorOrGuardian {
		uint256 reserves;

		address[] memory reserveToken = registry[PolicyAction.RESERVE_TOKEN];
		for (uint256 i = 0; i < reserveToken.length; i++) {
			reserves += tokenValue(reserveToken[i], IERC20(reserveToken[i]).balanceOf(address(this)));
		}

		address[] memory liquidityToken = registry[PolicyAction.LIQUIDITY_TOKEN];
		for (uint256 i = 0; i < liquidityToken.length; i++) {
			reserves += tokenValue(liquidityToken[i], IERC20(liquidityToken[i]).balanceOf(address(this)));
		}

		totalReserves = reserves;
		emit ReservesAudited(reserves);
	}

	/**
	 * @notice Enables the policy action for the target
	 * @dev Also used to update bonding calculators for liquidity tokens
	 * @param _policyAction PolicyAction
	 * @param _target address
	 * @param _calculator address
	 */
	function enable(
		PolicyAction _policyAction,
		address _target,
		address _calculator
	) external onlyGovernor {
		require(timelockEnabled == false, "BarnabyBobSafe::enable: on-chain governance is disabled"); // use `queuePolicyAction` instead

		if (_policyAction == PolicyAction.BALLOONS) {
			require(address(balloons) == address(0), unicode"BarnabyBobSafe::enable: 🎈 can only be set once");
			balloons = IBalloons(_target);
		} else {
			permissions[_policyAction][_target] = true;

			if (_policyAction == PolicyAction.LIQUIDITY_TOKEN) {
				bondCalculator[_target] = _calculator;
			}

			(bool registered, ) = indexInRegistry(_target, _policyAction);
			if (!registered) {
				registry[_policyAction].push(_target);

				if (_policyAction == PolicyAction.LIQUIDITY_TOKEN) {
					(bool reg, uint256 index) = indexInRegistry(_target, PolicyAction.RESERVE_TOKEN);
					if (reg) {
						delete registry[PolicyAction.RESERVE_TOKEN][index];
					}
				} else if (_policyAction == PolicyAction.RESERVE_TOKEN) {
					(bool reg, uint256 index) = indexInRegistry(_target, PolicyAction.LIQUIDITY_TOKEN);
					if (reg) {
						delete registry[PolicyAction.LIQUIDITY_TOKEN][index];
					}
				}
			}
		}
		emit Permissioned(_target, _policyAction, true);
	}

	/**
	 * @notice Revokes a policy effect from the target and erases the entry from the policy registry
	 * @param _policyAction PolicyAction to be rolled back
	 * @param _target address
	 */
	function revoke(PolicyAction _policyAction, address _target) external onlyGovernor {
		require(permissions[_policyAction][_target], "BarnabyBobSafe::disable: policy action already disabled");
		permissions[_policyAction][_target] = false;

		(bool registered, uint256 index) = indexInRegistry(_target, _policyAction);
		if (registered) {
			delete registry[_policyAction][index];
		}

		emit Permissioned(_target, _policyAction, false);
	}

	/**
	 * @notice Queues a new policy action
	 * @param _policyAction PolicyAction
	 * @param _target address Target for the policy action
	 * @param _calculator address Extra data for the policy action
	 */
	function queuePolicyAction(
		PolicyAction _policyAction,
		address _target,
		address _calculator
	) external onlyGovernor {
		require(_target != address(0), "BarnabyBobSafe::queuePolicyAction: receiving address cannot be 0");
		require(timelockEnabled == true, "BarnabyBobSafe::queuePolicyAction: on-chain governance is enabled"); // use `enable` instead

		uint256 policyTimelock = block.timestamp + policyQueueTimelock;
		if (_policyAction == PolicyAction.RESERVE_MANAGER || _policyAction == PolicyAction.LIQUIDITY_MANAGER) {
			policyTimelock = block.timestamp + (policyQueueTimelock * 2); // x2 time-lock multiplier for RM and LM
		}

		policyQueue.push(
			Policy({
				managing: _policyAction,
				toPermit: _target,
				calculator: _calculator,
				timelockEnd: policyTimelock,
				canceled: false,
				executed: false
			})
		);
		emit PermissionQueued(_policyAction, _target);
	}

	/// @notice Executes the queued policy action
	/// @param _index uint256
	function execute(uint256 _index) external {
		require(timelockEnabled == true, "BarnabyBobSafe::execute: on-chain governance is enabled"); // use `enable` instead

		Policy memory info = policyQueue[_index];

		require(!info.canceled, "BarnabyBobSafe::execute: action already canceled");
		require(!info.executed, "BarnabyBobSafe::execute: action already executed");
		if (_index > 3) {
			// 3 free policy actions for deployment purposes
			require(block.timestamp >= info.timelockEnd, "BarnabyBobSafe::execute: time-lock not expired");
		}

		if (info.managing == PolicyAction.BALLOONS) {
			require(address(balloons) == address(0), unicode"BarnabyBobSafe::execute: 🎈 can only be set once");
			balloons = IBalloons(info.toPermit);
		} else {
			permissions[info.managing][info.toPermit] = true;

			if (info.managing == PolicyAction.LIQUIDITY_TOKEN) {
				bondCalculator[info.toPermit] = info.calculator;
			}

			(bool registered, ) = indexInRegistry(info.toPermit, info.managing);
			if (!registered) {
				registry[info.managing].push(info.toPermit);

				if (info.managing == PolicyAction.LIQUIDITY_TOKEN) {
					(bool reg, uint256 index) = indexInRegistry(info.toPermit, PolicyAction.RESERVE_TOKEN);
					if (reg) {
						delete registry[PolicyAction.RESERVE_TOKEN][index];
					}
				} else if (info.managing == PolicyAction.RESERVE_TOKEN) {
					(bool reg, uint256 index) = indexInRegistry(info.toPermit, PolicyAction.LIQUIDITY_TOKEN);
					if (reg) {
						delete registry[PolicyAction.LIQUIDITY_TOKEN][index];
					}
				}
			}
		}

		policyQueue[_index].executed = true;
		emit Permissioned(info.toPermit, info.managing, true);
	}

	/// @notice Cancels a time-locked action
	/// @param _index uint256
	function cancel(uint256 _index) external onlyGovernor {
		policyQueue[_index].canceled = true;
	}

	/// @notice Disables time-locked functions
	function disableTimelock() external onlyGovernor {
		require(timelockEnabled == true, "BarnabyBobSafe::enableTimelock: time-lock already disabled");

		if (onChainGovernanceTimelock != 0 && onChainGovernanceTimelock <= block.timestamp) {
			timelockEnabled = false;
		} else {
			onChainGovernanceTimelock = block.timestamp + (policyQueueTimelock * 3); // 3x time-lock multiplier for enabling on-chain gov
		}
	}

	/// @notice Sets max debt ceiling for a given account in 🎈 units
	/// @param _target address
	/// @param _limit uint256
	function setDebtLimit(address _target, uint256 _limit) external onlyGovernor {
		debtLimitOf[_target] = _limit;
	}

	/// @notice Sets a new time-lock period for the policy queue
	/// @param _timelock the new policy timelock duration (between 12 hours and 30.5 days)
	function setPolicyTimelock(uint256 _timelock) external onlyGovernor {
		require(_timelock >= 12 hours, "BarnabyBobSafe::setTimelock: time-lock must last more than 12 hours");
		require(_timelock <= 30.5 days, "BarnabyBobSafe::setTimelock: time-lock cannot last more than 30.5 days");
		policyQueueTimelock = _timelock;
	}

	/// @notice Enables time-lock after initialization
	function initialize() external onlyGovernor {
		require(initialized == false, "BarnabyBobSafe::initialize: time-lock already initialized");
		timelockEnabled = true;
		initialized = true;
	}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IBalloons is IERC20Metadata {
	/* ========== EVENTS ========== */

	event SupplyAt(uint256 indexed epoch, uint256 timestamp, uint256 totalSupply);
	event Rebasing(uint256 indexed epoch, uint256 rebase, uint256 index);
	event MainShowUpdated(address mainShow);

	/* ========== DATA STRUCTURES ========== */

	struct Rebase {
		uint256 mainShow;
		uint256 rebase; // 18 decimals
		uint256 totalStakedBefore;
		uint256 totalStakedAfter;
		uint256 amountRebased;
		uint256 index;
		uint256 blockNumberOccured;
	}

	/* ========== VIEW FUNCTIONS ========== */

	function circulatingSupply() external view returns (uint256);

	function gonsForBalance(uint256 amount) external view returns (uint256);

	function balanceForGons(uint256 gons) external view returns (uint256);

	function index() external view returns (uint256);

	function toCottonCandy(uint256 amount) external view returns (uint256);

	function fromCottonCandy(uint256 amount) external view returns (uint256);

	function changeDebt(
		uint256 amount,
		address debtor,
		bool add
	) external;

	function debtBalances(address debtor) external view returns (uint256);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function rebase(uint256 profit, uint256 mainShow) external returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IGoldenTicketsLiquefier } from "./IGoldenTicketsLiquefier.sol";

interface IGoldenTickets is IERC20Metadata {
	/* ========== VIEW FUNCTIONS ========== */

	function ticketsBurnt() external view returns (uint256);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function mint(address account, uint256 amount) external;

	function burn(uint256 amount) external;

	function burnFrom(address account, uint256 amount) external;

	function changeMetadata(string memory name, string memory symbol) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IGovernableTreasury {
	/* ========== EVENTS ========== */

	event Deposit(address indexed token, uint256 amount, uint256 value);
	event Withdrawal(address indexed token, uint256 amount, uint256 value);
	event CreateDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
	event RepayDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
	event ReservesManaged(address indexed token, uint256 amount);
	event ReservesAudited(uint256 indexed totalReserves);
	event Minted(address indexed caller, address indexed recipient, uint256 amount);
	event PermissionQueued(PolicyAction indexed status, address queued);
	event Permissioned(address addr, PolicyAction indexed status, bool result);

	/* ========== DATA STRUCTURES ========== */

	enum PolicyAction {
		RESERVE_DEPOSITOR,
		RESERVE_SPENDER,
		RESERVE_TOKEN,
		RESERVE_MANAGER,
		LIQUIDITY_DEPOSITOR,
		LIQUIDITY_TOKEN,
		LIQUIDITY_MANAGER,
		RESERVE_DEBTOR,
		REWARD_MANAGER,
		BALLOONS,
		TICKETS_DEBTOR
	}

	struct Policy {
		PolicyAction managing;
		address toPermit;
		address calculator;
		uint256 timelockEnd;
		bool canceled;
		bool executed;
	}

	/* ========== VIEW FUNCTIONS ========== */

	function excessReserves() external view returns (uint256);

	function baseSupply() external view returns (uint256);

	function tokenValue(address token, uint256 amount) external view returns (uint256 value);

	function indexInRegistry(address target, PolicyAction action) external view returns (bool, uint256);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function deposit(
		uint256 amount,
		address token,
		uint256 excessReservesAmount
	) external returns (uint256);

	function withdraw(uint256 amount, address token) external;

	function mint(address recipient, uint256 amount) external;

	function manage(address token, uint256 amount) external;

	function incurDebt(uint256 amount, address token) external;

	function repayDebtWithReserve(uint256 amount, address token) external;

	function repayDebtWithTickets(uint256 amount) external;

	function auditReserves() external;

	function enable(
		PolicyAction action,
		address target,
		address extra
	) external;

	function revoke(PolicyAction action, address target) external;

	function queuePolicyAction(
		PolicyAction action,
		address target,
		address extra
	) external;

	function execute(uint256 index) external;

	function cancel(uint256 index) external;

	function disableTimelock() external;

	function setDebtLimit(address target, uint256 limit) external;

	function setPolicyTimelock(uint256 timelock) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

/* solhint-disable var-name-mixedcase */

interface IBalloonsVendingCalculator {
	/* ========== VIEW FUNCTIONS ========== */

	function markdown(address LP) external view returns (uint256);

	function valuation(address pair, uint256 amount) external view returns (uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IGoldenTicketsLiquefier {
	/* ========== EVENTS ========== */

	event TicketsLiquefied(uint256 _wei, uint256 tickets);

	/* ========== VIEW FUNCTIONS ========== */

	function router() external view returns (address);

	function pair() external view returns (address);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function liquefy(uint256) external;
}