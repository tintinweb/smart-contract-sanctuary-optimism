// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
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

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 248 bits");
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 240 bits");
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 232 bits");
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 224 bits");
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 216 bits");
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 208 bits");
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 200 bits");
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 192 bits");
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 184 bits");
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 176 bits");
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 168 bits");
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 160 bits");
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 152 bits");
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 144 bits");
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 136 bits");
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 120 bits");
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 112 bits");
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 104 bits");
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 96 bits");
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 88 bits");
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 80 bits");
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 72 bits");
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 56 bits");
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 48 bits");
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 40 bits");
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 24 bits");
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { FixedPointMathLib } from "../libraries/FixedPointMathLib.sol";
import { IERC4626Accounting } from "../interfaces/ERC4626/IERC4626Accounting.sol";

// import "hardhat/console.sol";

abstract contract Accounting is IERC4626Accounting {
	using FixedPointMathLib for uint256;

	function totalAssets() public view virtual returns (uint256);

	function totalSupply() public view virtual returns (uint256);

	function toSharesAfterDeposit(uint256 assets) public view virtual returns (uint256) {
		uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.
		uint256 _totalAssets = totalAssets() - assets;
		if (_totalAssets == 0) return assets;
		return supply == 0 ? assets : assets.mulDivDown(supply, _totalAssets);
	}

	function convertToShares(uint256 assets) public view virtual returns (uint256) {
		uint256 supply = totalSupply();

		return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
	}

	function convertToAssets(uint256 shares) public view virtual returns (uint256) {
		uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

		return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
	}

	function previewDeposit(uint256 assets) public view virtual returns (uint256) {
		return convertToShares(assets);
	}

	function previewMint(uint256 shares) public view virtual returns (uint256) {
		uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

		return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
	}

	function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
		uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.
		return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
	}

	function previewRedeem(uint256 shares) public view virtual returns (uint256) {
		return convertToAssets(shares);
	}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

struct AuthConfig {
	address owner;
	address guardian;
	address manager;
}

contract Auth is AccessControl {
	event OwnershipTransferInitiated(address owner, address pendingOwner);
	event OwnershipTransferred(address oldOwner, address newOwner);

	////////// CONSTANTS //////////

	/// Update vault params, perform time-sensitive operations, set manager
	bytes32 public constant GUARDIAN = keccak256("GUARDIAN");

	/// Hot-wallet bots that route funds between vaults, rebalance and harvest strategies
	bytes32 public constant MANAGER = keccak256("MANAGER");

	/// Add and remove vaults and strategies and other critical operations behind timelock
	/// Default admin role
	/// There should only be one owner, so it is not a role
	address public owner;
	address public pendingOwner;

	modifier onlyOwner() {
		require(msg.sender == owner, "ONLY_OWNER");
		_;
	}

	constructor(AuthConfig memory authConfig) {
		/// Set up the roles
		// owner can manage all roles
		owner = authConfig.owner;
		emit OwnershipTransferred(address(0), authConfig.owner);

		// TODO do we want cascading roles like this?
		_grantRole(DEFAULT_ADMIN_ROLE, authConfig.owner);
		_grantRole(GUARDIAN, owner);
		_grantRole(GUARDIAN, authConfig.guardian);
		_grantRole(MANAGER, authConfig.owner);
		_grantRole(MANAGER, authConfig.guardian);
		_grantRole(MANAGER, authConfig.manager);

		/// Allow the guardian role to manage manager
		_setRoleAdmin(MANAGER, GUARDIAN);
	}

	// ----------- Ownership -----------

	/// @dev Init transfer of ownership of the contract to a new account (`_pendingOwner`).
	/// @param _pendingOwner pending owner of contract
	/// Can only be called by the current owner.
	function transferOwnership(address _pendingOwner) external onlyOwner {
		pendingOwner = _pendingOwner;
		emit OwnershipTransferInitiated(owner, pendingOwner);
	}

	/// @dev Accept transfer of ownership of the contract.
	/// Can only be called by the pendingOwner.
	function acceptOwnership() external {
		require(msg.sender == pendingOwner, "ONLY_PENDING_OWNER");
		address oldOwner = owner;
		owner = pendingOwner;

		// revoke the DEFAULT ADMIN ROLE from prev owner
		_revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);
		_revokeRole(GUARDIAN, oldOwner);
		_revokeRole(MANAGER, oldOwner);

		_grantRole(DEFAULT_ADMIN_ROLE, owner);
		_grantRole(GUARDIAN, owner);
		_grantRole(MANAGER, owner);

		emit OwnershipTransferred(oldOwner, owner);
	}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Auth } from "./Auth.sol";

// import "hardhat/console.sol";

struct FeeConfig {
	address treasury;
	uint256 performanceFee;
	uint256 managementFee;
}

abstract contract Fees is Auth {
	uint256 public constant MAX_MANAGEMENT_FEE = .05e18; // 5%
	uint256 public constant MAX_PERFORMANCE_FEE = .25e18; // 25%

	/// @notice The percentage of profit recognized each harvest to reserve as fees.
	/// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
	uint256 public performanceFee;

	/// @notice Annual management fee.
	/// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
	uint256 public managementFee;

	/// @notice address where all fees are sent to
	address public treasury;

	constructor(FeeConfig memory feeConfig) {
		treasury = feeConfig.treasury;
		performanceFee = feeConfig.performanceFee;
		managementFee = feeConfig.managementFee;
		emit SetTreasury(feeConfig.treasury);
		emit SetPerformanceFee(feeConfig.performanceFee);
		emit SetManagementFee(feeConfig.managementFee);
	}

	/// @notice Sets a new performanceFee.
	/// @param _performanceFee The new performance fee.
	function setPerformanceFee(uint256 _performanceFee) public onlyOwner {
		if (_performanceFee > MAX_PERFORMANCE_FEE) revert OverMaxFee();

		performanceFee = _performanceFee;
		emit SetPerformanceFee(performanceFee);
	}

	/// @notice Sets a new performanceFee.
	/// @param _managementFee The new performance fee.
	function setManagementFee(uint256 _managementFee) public onlyOwner {
		if (_managementFee > MAX_MANAGEMENT_FEE) revert OverMaxFee();

		managementFee = _managementFee;
		emit SetManagementFee(_managementFee);
	}

	/// @notice Updates treasury.
	/// @param _treasury New treasury address.
	function setTreasury(address _treasury) public onlyOwner {
		treasury = _treasury;
		emit SetTreasury(_treasury);
	}

	/// @notice Emitted when performance fee is updated.
	/// @param performanceFee The new perforamance fee.
	event SetPerformanceFee(uint256 performanceFee);

	/// @notice Emitted when management fee is updated.
	/// @param managementFee The new management fee.
	event SetManagementFee(uint256 managementFee);

	event SetTreasury(address indexed treasury);

	error OverMaxFee();
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

interface IERC4626 {
	event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

	event Withdraw(
		address indexed sender,
		address indexed receiver,
		address indexed owner,
		uint256 assets,
		uint256 shares
	);

	/*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

	function deposit(uint256 assets, address receiver) external payable returns (uint256 shares);

	function mint(uint256 shares, address receiver) external payable returns (uint256 assets);

	function withdraw(
		uint256 assets,
		address receiver,
		address owner
	) external returns (uint256 shares);

	function redeem(
		uint256 shares,
		address receiver,
		address owner
	) external returns (uint256 assets);

	/*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

	function maxDeposit(address receiver) external view returns (uint256 maxAssets);

	function maxMint(address receiver) external view returns (uint256 maxShares);

	function maxWithdraw(address owner) external view returns (uint256 maxAssets);

	function maxRedeem(address owner) external view returns (uint256 maxShares);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

interface IERC4626Accounting {
	function totalAssets() external view returns (uint256);

	function convertToShares(uint256 assets) external view returns (uint256);

	function convertToAssets(uint256 shares) external view returns (uint256);

	function previewDeposit(uint256 assets) external view returns (uint256);

	function previewMint(uint256 shares) external view returns (uint256);

	function previewWithdraw(uint256 assets) external view returns (uint256);

	function previewRedeem(uint256 shares) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.16;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VaultType } from "./Structs.sol";

interface IVaultStrategy is IERC20 {
	// scy deposit
	function deposit(
		address receiver,
		address tokenIn,
		uint256 amountTokenToPull,
		uint256 minSharesOut
	) external payable returns (uint256 amountSharesOut);

	// erc4626 deposit
	function deposit(uint256 amount, address to) external payable returns (uint256 amountSharesOut);

	function vaultType() external view returns (VaultType);

	function redeem(
		address receiver,
		uint256 amountSharesToPull,
		address tokenOut,
		uint256 minTokenOut
	) external returns (uint256 amountTokenOut);

	function requestRedeem(uint256 shares) external;

	function redeem() external returns (uint256 amountTokenOut);

	function getAndUpdateTvl() external returns (uint256 tvl);

	function getTvl() external view returns (uint256 tvl);

	function MIN_LIQUIDITY() external view returns (uint256);

	function underlying() external view returns (IERC20);

	function sendERC20ToStrategy() external view returns (bool);

	function strategy() external view returns (address payable);

	function underlyingBalance(address) external view returns (uint256);

	function underlyingToShares(uint256 amnt) external view returns (uint256);

	function exchangeRateUnderlying() external view returns (uint256);

	function sharesToUnderlying(uint256 shares) external view returns (uint256);

	function getUpdatedUnderlyingBalance(address) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

enum CallType {
	ADD_LIQUIDITY_AND_MINT,
	BORROWB,
	REMOVE_LIQ_AND_REPAY
}

enum VaultType {
	Strategy,
	Aggregator
}

enum NativeToken {
	None,
	Underlying,
	Short
}

struct CalleeData {
	CallType callType;
	bytes data;
}
struct AddLiquidityAndMintCalldata {
	uint256 uAmnt;
	uint256 sAmnt;
}
struct BorrowBCalldata {
	uint256 borrowAmount;
	bytes data;
}
struct RemoveLiqAndRepayCalldata {
	uint256 removeLpAmnt;
	uint256 repayUnderlying;
	uint256 repayShort;
	// uint256 amountAMin;
	// uint256 amountBMin;
}

struct HarvestSwapParams {
	address[] path; //path that the token takes
	uint256 min; // min price of in token * 1e18 (computed externally based on spot * slippage + fees)
	uint256 deadline;
	bytes pathData; // uniswap3 path data
}

struct IMXConfig {
	address vault;
	address underlying;
	address short;
	address uniPair;
	address poolToken;
	address farmToken;
	address farmRouter;
	uint256 maxTvl;
}

struct HLPConfig {
	string symbol;
	string name;
	address underlying;
	address short;
	address cTokenLend;
	address cTokenBorrow;
	address uniPair;
	address uniFarm;
	address farmToken;
	uint256 farmId;
	address farmRouter;
	address comptroller;
	address lendRewardRouter;
	address lendRewardToken;
	address vault;
	uint256 maxTvl;
	NativeToken nativeToken;
}

struct EAction {
	address target;
	uint256 value;
	bytes data;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IWETH {
	function deposit() external payable;

	function transfer(address to, uint256 value) external returns (bool);

	function withdraw(uint256) external;

	function balanceOf(address) external returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
	/*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

	uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

	function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
		return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
	}

	function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
		return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
	}

	function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
		return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
	}

	function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
		return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
	}

	/*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

	function mulDivDown(
		uint256 x,
		uint256 y,
		uint256 denominator
	) internal pure returns (uint256 z) {
		assembly {
			// Store x * y in z for now.
			z := mul(x, y)

			// Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
			if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
				revert(0, 0)
			}

			// Divide z by the denominator.
			z := div(z, denominator)
		}
	}

	function mulDivUp(
		uint256 x,
		uint256 y,
		uint256 denominator
	) internal pure returns (uint256 z) {
		assembly {
			// Store x * y in z for now.
			z := mul(x, y)

			// Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
			if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
				revert(0, 0)
			}

			// First, divide z - 1 by the denominator and add 1.
			// We allow z - 1 to underflow if z is 0, because we multiply the
			// end result by 0 if z is zero, ensuring we return 0 if z is zero.
			z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
		}
	}

	function rpow(
		uint256 x,
		uint256 n,
		uint256 scalar
	) internal pure returns (uint256 z) {
		assembly {
			switch x
			case 0 {
				switch n
				case 0 {
					// 0 ** 0 = 1
					z := scalar
				}
				default {
					// 0 ** n = 0
					z := 0
				}
			}
			default {
				switch mod(n, 2)
				case 0 {
					// If n is even, store scalar in z for now.
					z := scalar
				}
				default {
					// If n is odd, store x in z for now.
					z := x
				}

				// Shifting right by 1 is like dividing by 2.
				let half := shr(1, scalar)

				for {
					// Shift n right by 1 before looping to halve it.
					n := shr(1, n)
				} n {
					// Shift n right by 1 each iteration to halve it.
					n := shr(1, n)
				} {
					// Revert immediately if x ** 2 would overflow.
					// Equivalent to iszero(eq(div(xx, x), x)) here.
					if shr(128, x) {
						revert(0, 0)
					}

					// Store x squared.
					let xx := mul(x, x)

					// Round to the nearest number.
					let xxRound := add(xx, half)

					// Revert if xx + half overflowed.
					if lt(xxRound, xx) {
						revert(0, 0)
					}

					// Set x to scaled xxRound.
					x := div(xxRound, scalar)

					// If n is even:
					if mod(n, 2) {
						// Compute z * x.
						let zx := mul(z, x)

						// If z * x overflowed:
						if iszero(eq(div(zx, x), z)) {
							// Revert if x is non-zero.
							if iszero(iszero(x)) {
								revert(0, 0)
							}
						}

						// Round to the nearest number.
						let zxRound := add(zx, half)

						// Revert if zx + half overflowed.
						if lt(zxRound, zx) {
							revert(0, 0)
						}

						// Return properly scaled zxRound.
						z := div(zxRound, scalar)
					}
				}
			}
		}
	}

	/*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

	function sqrt(uint256 x) internal pure returns (uint256 z) {
		assembly {
			// Start off with z at 1.
			z := 1

			// Used below to help find a nearby power of 2.
			let y := x

			// Find the lowest power of 2 that is at least sqrt(x).
			if iszero(lt(y, 0x100000000000000000000000000000000)) {
				y := shr(128, y) // Like dividing by 2 ** 128.
				z := shl(64, z) // Like multiplying by 2 ** 64.
			}
			if iszero(lt(y, 0x10000000000000000)) {
				y := shr(64, y) // Like dividing by 2 ** 64.
				z := shl(32, z) // Like multiplying by 2 ** 32.
			}
			if iszero(lt(y, 0x100000000)) {
				y := shr(32, y) // Like dividing by 2 ** 32.
				z := shl(16, z) // Like multiplying by 2 ** 16.
			}
			if iszero(lt(y, 0x10000)) {
				y := shr(16, y) // Like dividing by 2 ** 16.
				z := shl(8, z) // Like multiplying by 2 ** 8.
			}
			if iszero(lt(y, 0x100)) {
				y := shr(8, y) // Like dividing by 2 ** 8.
				z := shl(4, z) // Like multiplying by 2 ** 4.
			}
			if iszero(lt(y, 0x10)) {
				y := shr(4, y) // Like dividing by 2 ** 4.
				z := shl(2, z) // Like multiplying by 2 ** 2.
			}
			if iszero(lt(y, 0x8)) {
				// Equivalent to 2 ** z.
				z := shl(1, z)
			}

			// Shifting right by 1 is like dividing by 2.
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))
			z := shr(1, add(z, div(x, z)))

			// Compute a rounded down version of z.
			let zRoundDown := div(x, z)

			// If zRoundDown is smaller, use it.
			if lt(zRoundDown, z) {
				z := zRoundDown
			}
		}
	}
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

library SafeETH {
	function safeTransferETH(address to, uint256 amount) internal {
		bool callStatus;

		assembly {
			// Transfer the ETH and store if it succeeded or not.
			callStatus := call(gas(), to, amount, 0, 0, 0, 0)
		}

		require(callStatus, "ETH_TRANSFER_FAILED");
	}
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626, IWETH } from "./ERC4626.sol";
import { SafeETH } from "../../libraries/SafeETH.sol";

// import "hardhat/console.sol";

struct WithdrawRecord {
	uint256 timestamp;
	uint256 shares;
	uint256 value; // this the current value (also max withdraw value)
}

abstract contract BatchedWithdraw is ERC4626 {
	using SafeERC20 for ERC20;

	event RequestWithdraw(address indexed caller, address indexed owner, uint256 shares);

	uint256 public lastHarvestTimestamp;
	uint256 public pendingRedeem;

	mapping(address => WithdrawRecord) public withdrawLedger;

	constructor() {
		lastHarvestTimestamp = block.timestamp;
	}

	function requestRedeem(uint256 shares) public {
		return requestRedeem(shares, msg.sender);
	}

	function requestRedeem(uint256 shares, address owner) public {
		if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);
		_requestRedeem(shares, owner, msg.sender);
	}

	/// @dev redeem request records the value of the redeemed shares at the time of request
	/// at the time of claim, user is able to withdraw the minimum of the
	/// current value and value at time of request
	/// this is to prevent users from pre-emptively submitting redeem claims
	/// and claiming any rewards after the request has been made
	function _requestRedeem(
		uint256 shares,
		address owner,
		address redeemer
	) internal {
		_transfer(owner, address(this), shares);
		WithdrawRecord storage withdrawRecord = withdrawLedger[redeemer];
		withdrawRecord.timestamp = block.timestamp;
		withdrawRecord.shares += shares;
		uint256 value = convertToAssets(shares);
		withdrawRecord.value += value;
		pendingRedeem += shares;
		emit RequestWithdraw(msg.sender, owner, shares);
	}

	function withdraw(
		uint256,
		address,
		address
	) public pure virtual override returns (uint256) {
		revert NotImplemented();
	}

	function redeem(
		uint256,
		address receiver,
		address
	) public virtual override returns (uint256 amountOut) {
		return redeem(receiver);
	}

	/// @dev safest UI method
	function redeem() public virtual returns (uint256 amountOut) {
		return redeem(msg.sender);
	}

	/// @dev safest UI method
	function redeemNative() public virtual returns (uint256 amountOut) {
		return redeemNative(msg.sender);
	}

	function redeemNative(address receiver) public virtual returns (uint256 amountOut) {
		if (!useNativeAsset) revert NotNativeAsset();
		uint256 shares;
		(amountOut, shares) = _redeem(msg.sender);

		emit Withdraw(msg.sender, receiver, msg.sender, amountOut, shares);

		IWETH(address(asset)).withdraw(amountOut);
		SafeETH.safeTransferETH(receiver, amountOut);
	}

	function redeem(address receiver) public virtual returns (uint256 amountOut) {
		uint256 shares;
		(amountOut, shares) = _redeem(msg.sender);
		emit Withdraw(msg.sender, receiver, msg.sender, amountOut, shares);
		asset.safeTransfer(receiver, amountOut);
	}

	/// @dev should only be called by manager on behalf of xVaults
	function _xRedeem(address xVault, address _vault) internal virtual returns (uint256 amountOut) {
		uint256 shares;
		(amountOut, shares) = _redeem(xVault);
		emit Withdraw(_vault, _vault, _vault, amountOut, shares);
	}

	function _redeem(address account) internal returns (uint256 amountOut, uint256 shares) {
		WithdrawRecord storage withdrawRecord = withdrawLedger[account];

		if (withdrawRecord.value == 0) revert ZeroAmount();
		if (withdrawRecord.timestamp >= lastHarvestTimestamp) revert NotReady();

		shares = withdrawRecord.shares;
		// value of shares at time of redemption request
		uint256 redeemValue = withdrawRecord.value;

		// actual amount out is the smaller of currentValue and redeemValue
		amountOut = _getWithdrawAmount(shares, redeemValue);

		// update total pending redeem
		pendingRedeem -= shares;

		// important pendingRedeem should update prior to beforeWithdraw call
		beforeWithdraw(amountOut, shares);
		withdrawRecord.value = 0;
		withdrawRecord.shares = 0;
		_burn(address(this), shares);
	}

	/// helper method to get xChain bridge amount
	// function pendingRedeem(address account) public view returns (uint256 amountOut) {
	// 	WithdrawRecord storage withdrawRecord = withdrawLedger[account];

	// 	if (withdrawRecord.value == 0) revert ZeroAmount();
	// 	if (withdrawRecord.timestamp >= lastHarvestTimestamp) revert NotReady();

	// 	// value of shares at time of redemption request
	// 	return _getWithdrawAmount(withdrawRecord.shares, withdrawRecord.value);
	// }

	function _getWithdrawAmount(uint256 shares, uint256 redeemValue)
		internal
		view
		returns (uint256 amountOut)
	{
		// value of shares at time of redemption request
		uint256 currentValue = convertToAssets(shares);
		// actual amount out is the smaller of currentValue and redeemValue
		amountOut = currentValue < redeemValue ? currentValue : redeemValue;
	}

	function cancelRedeem() public virtual {
		WithdrawRecord storage withdrawRecord = withdrawLedger[msg.sender];

		uint256 shares = withdrawRecord.shares;
		// value of shares at time of redemption request
		uint256 redeemValue = withdrawRecord.value;
		uint256 currentValue = convertToAssets(shares);

		// update accounting
		withdrawRecord.value = 0;
		withdrawRecord.shares = 0;
		pendingRedeem -= shares;

		// if vault lost money, shares stay the same
		if (currentValue < redeemValue) return _transfer(address(this), msg.sender, shares);

		// // if vault earned money, subtract earnings since withdrawal request
		uint256 sharesOut = (shares * redeemValue) / currentValue;
		uint256 sharesToBurn = shares - sharesOut;

		_transfer(address(this), msg.sender, sharesOut);
		_burn(address(this), sharesToBurn);
	}

	/// @notice UI method to view cancellation penalty
	function getPenalty() public view returns (uint256) {
		WithdrawRecord storage withdrawRecord = withdrawLedger[msg.sender];
		uint256 shares = withdrawRecord.shares;

		uint256 redeemValue = withdrawRecord.value;
		uint256 currentValue = convertToAssets(shares);

		if (currentValue < redeemValue) return 0;
		return (1e18 * (currentValue - redeemValue)) / redeemValue;
	}

	/// UTILS
	function redeemIsReady(address user) external view returns (bool) {
		WithdrawRecord storage withdrawRecord = withdrawLedger[user];
		return lastHarvestTimestamp > withdrawRecord.timestamp && withdrawRecord.value > 0;
	}

	function getWithdrawStatus(address user) external view returns (WithdrawRecord memory) {
		return withdrawLedger[user];
	}

	error NotNativeAsset();
	error Expired();
	error NotImplemented();
	error NotReady();
	error ZeroAmount();
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "../../libraries/FixedPointMathLib.sol";
import { IERC4626 } from "../../interfaces/ERC4626/IERC4626.sol";
import { Accounting } from "../../common/Accounting.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Auth, AuthConfig } from "../../common/Auth.sol";
import { Fees, FeeConfig } from "../../common/Fees.sol";
import { IWETH } from "../../interfaces/uniswap/IWETH.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// import "hardhat/console.sol";

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol)
abstract contract ERC4626 is Auth, Accounting, Fees, IERC4626, ERC20, ReentrancyGuard {
	using SafeERC20 for ERC20;
	using FixedPointMathLib for uint256;

	/*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

	// locked liquidity to prevent rounding errors
	uint256 public constant MIN_LIQUIDITY = 1e3;

	/*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

	ERC20 immutable asset;
	// flag that allows the vault to consume native asset
	bool public useNativeAsset;
	uint256 public maxTvl;

	constructor(
		ERC20 _asset,
		string memory _name,
		string memory _symbol,
		bool _useNativeAsset
	) ERC20(_name, _symbol) {
		useNativeAsset = _useNativeAsset;
		asset = _asset;
	}

	receive() external payable {}

	function decimals() public view override returns (uint8) {
		return asset.decimals();
	}

	function totalAssets() public view virtual override returns (uint256);

	/*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

	function deposit(uint256 assets, address receiver)
		public
		payable
		virtual
		nonReentrant
		returns (uint256 shares)
	{
		if (totalAssets() + assets > maxTvl) revert OverMaxTvl();

		// This check is no longer necessary because we use MIN_LIQUIDITY
		// Check for rounding error since we round down in previewDeposit.
		// require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
		shares = previewDeposit(assets);

		// Need to transfer before minting or ERC777s could reenter.
		if (useNativeAsset && msg.value == assets) IWETH(address(asset)).deposit{ value: assets }();
		else asset.safeTransferFrom(msg.sender, address(this), assets);

		// lock minimum liquidity if totalSupply is 0
		if (totalSupply() == 0) {
			if (MIN_LIQUIDITY > shares) revert MinLiquidity();
			shares -= MIN_LIQUIDITY;
			_mint(address(1), MIN_LIQUIDITY);
		}

		_mint(receiver, shares);

		emit Deposit(msg.sender, receiver, assets, shares);

		afterDeposit(assets, shares);
	}

	function mint(uint256 shares, address receiver)
		public
		payable
		virtual
		nonReentrant
		returns (uint256 assets)
	{
		assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.
		if (totalAssets() + assets > maxTvl) revert OverMaxTvl();

		// Need to transfer before minting or ERC777s could reenter.
		if (useNativeAsset && msg.value == assets) IWETH(address(asset)).deposit{ value: assets }();
		else asset.safeTransferFrom(msg.sender, address(this), assets);

		// lock minimum liquidity if totalSupply is 0
		if (totalSupply() == 0) {
			if (MIN_LIQUIDITY > shares) revert MinLiquidity();
			shares -= MIN_LIQUIDITY;
			_mint(address(1), MIN_LIQUIDITY);
		}

		_mint(receiver, shares);

		emit Deposit(msg.sender, receiver, assets, shares);

		afterDeposit(assets, shares);
	}

	function withdraw(
		uint256 assets,
		address receiver,
		address owner
	) public virtual returns (uint256 shares) {
		shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

		// if not owner, allowance must be enforced
		if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

		beforeWithdraw(assets, shares);

		_burn(owner, shares);

		emit Withdraw(msg.sender, receiver, owner, assets, shares);

		asset.safeTransfer(receiver, assets);
	}

	function redeem(
		uint256 shares,
		address receiver,
		address owner
	) public virtual returns (uint256 assets) {
		// if not owner, allowance must be enforced
		if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

		// This check is no longer necessary because we use MIN_LIQUIDITY
		// Check for rounding error since we round down in previewRedeem.
		// require((assets = previewRedeem(shares)) != 0, "ZEROassetS");
		assets = previewRedeem(shares);

		beforeWithdraw(assets, shares);

		_burn(owner, shares);

		emit Withdraw(msg.sender, receiver, owner, assets, shares);

		asset.safeTransfer(receiver, assets);
	}

	/*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

	function setMaxTvl(uint256 _maxTvl) public onlyRole(MANAGER) {
		maxTvl = _maxTvl;
		emit MaxTvlUpdated(_maxTvl);
	}

	function maxDeposit(address) public view override returns (uint256) {
		uint256 _totalAssets = totalAssets();
		return _totalAssets > maxTvl ? 0 : maxTvl - _totalAssets;
	}

	function maxMint(address) public view override returns (uint256) {
		return convertToShares(maxDeposit(address(0)));
	}

	function maxWithdraw(address owner) public view virtual returns (uint256) {
		return convertToAssets(balanceOf(owner));
	}

	function maxRedeem(address owner) public view virtual returns (uint256) {
		return balanceOf(owner);
	}

	/*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

	function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

	function afterDeposit(uint256 assets, uint256 shares) internal virtual {}

	// OVERRIDES
	function totalSupply() public view override(Accounting, ERC20) returns (uint256) {
		return ERC20.totalSupply();
	}

	event MaxTvlUpdated(uint256 maxTvl);

	error OverMaxTvl();
	error MinLiquidity();
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626, FixedPointMathLib, SafeERC20 } from "./ERC4626.sol";
import { BatchedWithdraw } from "./BatchedWithdraw.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { EAction } from "../../interfaces/Structs.sol";
import { VaultType } from "../../interfaces/Structs.sol";

// import "hardhat/console.sol";

abstract contract SectorBase is BatchedWithdraw {
	using FixedPointMathLib for uint256;
	using SafeERC20 for ERC20;

	VaultType public constant vaultType = VaultType.Aggregator;

	uint256 public totalChildHoldings;
	uint256 public floatAmnt; // amount of underlying tracked in vault
	uint256 public maxHarvestInterval; // emergency redeem is enabled after this time

	function setMaxHarvestInterval(uint256 maxHarvestInterval_) public onlyOwner {
		maxHarvestInterval = maxHarvestInterval_;
		emit SetMaxHarvestInterval(maxHarvestInterval);
	}

	function _harvest(uint256 currentChildHoldings) internal {
		// withdrawFromStrategies should be called prior to harvest to ensure this tx doesn't revert
		// pendingWithdraw may be larger than the actual withdrawable amount if vault sufferred losses
		// since the previous harvest

		uint256 tvl = currentChildHoldings + floatAmnt;
		uint256 _totalSupply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

		/// this is actually a max amount that can be withdrawn given current tvl
		/// actual withdraw amount may be slightly less if there are stale withdraw requests
		uint256 pendingWithdraw = pendingRedeem.mulDivDown(tvl, _totalSupply);
		if (floatAmnt < pendingWithdraw) revert NotEnoughtFloat();

		uint256 profit = currentChildHoldings > totalChildHoldings
			? currentChildHoldings - totalChildHoldings
			: 0;

		uint256 timestamp = block.timestamp;

		// totalChildHoldings need to be updated before fees computation
		totalChildHoldings = currentChildHoldings;

		// PROCESS VAULT FEES
		uint256 _performanceFee = profit == 0 ? 0 : (profit * performanceFee) / 1e18;
		uint256 _managementFee = managementFee == 0
			? 0
			: (managementFee * tvl * (timestamp - lastHarvestTimestamp)) / 1e18 / 365 days;

		uint256 totalFees = _performanceFee + _managementFee;
		uint256 feeShares;

		if (totalFees > 0) {
			// this results in more accurate accounting considering dilution
			feeShares = totalFees.mulDivDown(_totalSupply, tvl - totalFees);
			_mint(treasury, feeShares);
		}

		emit Harvest(treasury, profit, _performanceFee, _managementFee, feeShares, tvl);

		// this enables withdrawals requested prior to this timestamp
		lastHarvestTimestamp = timestamp;
	}

	/// @notice this method allows an arbitrary method to be called by the owner in case of emergency
	/// owner must be a timelock contract in order to allow users to redeem funds in case they suspect
	/// this action to be malicious
	function emergencyAction(EAction[] calldata actions) public onlyOwner {
		uint256 l = actions.length;
		for (uint256 i = 0; i < l; i++) {
			address target = actions[i].target;
			bytes memory data = actions[i].data;
			(bool success, ) = target.call{ value: actions[i].value }(data);
			require(success, "emergencyAction failed");
			emit EmergencyAction(target, data);
		}
	}

	function _checkSlippage(
		uint256 expectedValue,
		uint256 actualValue,
		uint256 maxDelta
	) internal pure {
		uint256 delta = expectedValue > actualValue
			? expectedValue - actualValue
			: actualValue - expectedValue;
		if (delta > maxDelta) revert SlippageExceeded();
	}

	function totalAssets() public view virtual override returns (uint256) {
		return floatAmnt + totalChildHoldings;
	}

	/// INTERFACE UTILS

	/// @dev returns a cached value used for withdrawals
	function underlyingBalance(address user) public view returns (uint256) {
		uint256 shares = balanceOf(user);
		return convertToAssets(shares);
	}

	function getUpdatedUnderlyingBalance(address user) public view returns (uint256) {
		uint256 shares = balanceOf(user);
		return convertToAssets(shares);
	}

	function underlyingDecimals() public view returns (uint8) {
		return asset.decimals();
	}

	function underlying() public view returns (address) {
		return address(asset);
	}

	/// OVERRIDES

	function afterDeposit(uint256 assets, uint256) internal override {
		if (block.timestamp - lastHarvestTimestamp > maxHarvestInterval)
			revert EmergencyRedeemEnabled();

		floatAmnt += assets;
	}

	function beforeWithdraw(uint256 assets, uint256) internal override {
		// this check prevents withdrawing more underlying from the vault then
		// what we need to keep to honor withdrawals
		uint256 pendingWithdraw = convertToAssets(pendingRedeem);
		if (floatAmnt < assets + pendingWithdraw) revert NotEnoughtFloat();
		floatAmnt -= assets;
	}

	event RegisterDeposit(uint256 total);
	event EmergencyWithdraw(address vault, address client, uint256 shares);
	event EmergencyAction(address target, bytes callData);
	event Harvest(
		address indexed treasury,
		uint256 underlyingProfit,
		uint256 performanceFee,
		uint256 managementFee,
		uint256 sharesFees,
		uint256 tvl
	);
	event SetMaxHarvestInterval(uint256 maxHarvestInterval);

	error RecentHarvest();
	error MaxRedeemNotZero();
	error NotEnoughtFloat();
	error WrongUnderlying();
	error SlippageExceeded();
	error StrategyExists();
	error StrategyNotFound();
	error MissingDepositValue();
	error EmergencyRedeemEnabled();
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626, FixedPointMathLib, SafeERC20, Fees, FeeConfig, Auth, AuthConfig } from "../ERC4626/ERC4626.sol";
import { IVaultStrategy } from "../../interfaces/IVaultStrategy.sol";
import { BatchedWithdraw } from "../ERC4626/BatchedWithdraw.sol";
import { SectorBase } from "../ERC4626/SectorBase.sol";
import { VaultType } from "../../interfaces/Structs.sol";

// import "hardhat/console.sol";
// TODO native asset deposit + flow

struct RedeemParams {
	IVaultStrategy strategy;
	VaultType vaultType;
	uint256 shares;
	uint256 minTokenOut;
}

struct DepositParams {
	IVaultStrategy strategy;
	VaultType vaultType;
	uint256 amountIn;
	uint256 minSharesOut;
}

// Sector Aggregator Vault
contract AggregatorVault is SectorBase {
	using FixedPointMathLib for uint256;
	using SafeERC20 for ERC20;

	/// if vaults accepts native asset we set asset to address 0;
	address internal constant NATIVE = address(0);

	// resonable amount to not go over gas limit when doing emergencyWithdraw
	// in reality can go up to 200
	uint8 MAX_STRATS = 100;

	mapping(IVaultStrategy => bool) public strategyExists;
	address[] public strategyIndex;

	uint256 public totalStrategyHoldings;

	constructor(
		ERC20 asset_,
		string memory _name,
		string memory _symbol,
		bool _useNativeAsset,
		uint256 _maxHarvestInterval,
		uint256 _maxTvl,
		AuthConfig memory authConfig,
		FeeConfig memory feeConfig
	)
		ERC4626(asset_, _name, _symbol, _useNativeAsset)
		Auth(authConfig)
		Fees(feeConfig)
		BatchedWithdraw()
	{
		maxTvl = _maxTvl;
		emit MaxTvlUpdated(_maxTvl);

		maxHarvestInterval = _maxHarvestInterval;
		emit SetMaxHarvestInterval(_maxHarvestInterval);
	}

	function addStrategy(IVaultStrategy strategy) public onlyOwner {
		if (strategyIndex.length >= MAX_STRATS) revert TooManyStrategies();
		if (strategyExists[strategy]) revert StrategyExists();

		/// make sure underlying matches
		if (address(strategy.underlying()) != address(asset)) revert WrongUnderlying();

		strategyExists[strategy] = true;
		strategyIndex.push(address(strategy));
		emit AddStrategy(address(strategy));
	}

	function removeStrategy(IVaultStrategy strategy) public onlyOwner {
		if (!strategyExists[strategy]) revert StrategyNotFound();
		strategyExists[strategy] = false;
		uint256 length = strategyIndex.length;
		// replace current index with last strategy and pop the index array
		uint256 i;
		for (i; i < length; ++i) if (address(strategy) == strategyIndex[i]) break;
		strategyIndex[i] = strategyIndex[length - 1];
		strategyIndex.pop();
		emit RemoveStrategy(address(strategy));
	}

	function totalStrategies() external view returns (uint256) {
		return strategyIndex.length;
	}

	function getAllStrategies() external view returns (address[] memory) {
		return strategyIndex;
	}

	/// We compute expected tvl off-chain first, to ensure this transactions isn't sandwitched
	function harvest(uint256 expectedTvl, uint256 maxDelta) public onlyRole(MANAGER) {
		uint256 currentChildHoldings = _getStrategyHoldings();
		uint256 tvl = currentChildHoldings + floatAmnt;
		_checkSlippage(expectedTvl, tvl, maxDelta);
		// harvest event emitted here
		_harvest(currentChildHoldings);
	}

	/// this can be done in parts in case gas limit is reached
	function depositIntoStrategies(DepositParams[] calldata params) public onlyRole(MANAGER) {
		uint256 l = params.length;
		for (uint256 i; i < l; ++i) {
			DepositParams memory param = params[i];
			uint256 amountIn = param.amountIn;
			if (amountIn == 0) continue;
			IVaultStrategy strategy = param.strategy;

			if (!strategyExists[strategy]) revert StrategyNotFound();

			// update underlying float accouting
			beforeWithdraw(amountIn, 0);
			/// push funds to avoid approvals
			if (param.vaultType == VaultType.Strategy) {
				// send funds - more gas efficient
				if (strategy.sendERC20ToStrategy() == true)
					asset.safeTransfer(strategy.strategy(), amountIn);
				else asset.safeTransfer(address(strategy), amountIn);

				// process deposit
				strategy.deposit(address(this), address(asset), 0, param.minSharesOut);
			} else if (param.vaultType == VaultType.Aggregator) {
				asset.safeApprove(address(strategy), amountIn);
				strategy.deposit(amountIn, address(this));
			}
			totalChildHoldings += amountIn;

			emit DepositIntoStrategy(msg.sender, address(strategy), amountIn);
		}
	}

	function requestRedeemFromStrategies(RedeemParams[] calldata params) public onlyRole(MANAGER) {
		uint256 l = params.length;
		for (uint256 i; i < l; ++i) {
			if (params[i].vaultType != VaultType.Aggregator) continue;
			params[i].strategy.requestRedeem(params[i].shares);
		}
	}

	/// this can be done in parts in case gas limit is reached
	function withdrawFromStrategies(RedeemParams[] calldata params) public onlyRole(MANAGER) {
		uint256 l = params.length;
		for (uint256 i; i < l; ++i) {
			RedeemParams memory param = params[i];
			uint256 shares = param.shares;
			if (shares == 0) continue;
			IVaultStrategy strategy = param.strategy;
			if (!strategyExists[strategy]) revert StrategyNotFound();

			uint256 amountOut;
			if (param.vaultType == VaultType.Strategy)
				// no need to push share tokens - contract can burn them
				amountOut = strategy.redeem(
					address(this),
					shares,
					address(asset), // token out is allways asset
					param.minTokenOut
				);
			else if (param.vaultType == VaultType.Aggregator) amountOut = strategy.redeem();

			// if strategy was profitable, we may end up withdrawing more than totalChildHoldings
			totalChildHoldings = amountOut > totalChildHoldings
				? 0
				: totalChildHoldings - amountOut;

			// update underlying float accounting
			afterDeposit(amountOut, 0);
			emit WithdrawFromStrategy(msg.sender, address(strategy), amountOut);
		}
	}

	/// @dev this method allows direct redemption of shares in exchange for
	/// a portion of the float amount + a portion of all the strategy shares the vault holds
	/// deposits are paused when we are in the emergency redeem state
	function emergencyRedeem() public nonReentrant {
		if (block.timestamp - lastHarvestTimestamp < maxHarvestInterval) revert RecentHarvest();
		uint256 _totalSupply = totalSupply();
		uint256 shares = balanceOf(msg.sender);
		if (shares == 0) return;

		// redeem proportional share of vault's underlying float balance
		// (minus pendingWithdraw)
		uint256 pendingWithdraw = convertToAssets(pendingRedeem);

		if (floatAmnt > pendingWithdraw) {
			uint256 availableFloat = floatAmnt - pendingWithdraw;
			uint256 underlyingShare = (availableFloat * shares) / (_totalSupply - pendingRedeem);
			beforeWithdraw(underlyingShare, 0);
			asset.safeTransfer(msg.sender, underlyingShare);
		}

		uint256 l = strategyIndex.length;

		// redeem proportional share of each strategy
		for (uint256 i; i < l; ++i) {
			ERC20 stratToken = ERC20(strategyIndex[i]);
			uint256 balance = stratToken.balanceOf(address(this));
			uint256 userShares = (shares * balance) / _totalSupply;
			if (userShares == 0) continue;
			stratToken.safeTransfer(msg.sender, userShares);
		}

		_burn(msg.sender, shares);
	}

	/// gets accurate strategy holdings denominated in asset
	function _getStrategyHoldings() internal returns (uint256 tvl) {
		uint256 l = strategyIndex.length;
		/// TODO compute realistic limit for strategy array lengh to stay within gas limit
		for (uint256 i; i < l; ++i) {
			IVaultStrategy strategy = IVaultStrategy(payable(strategyIndex[i]));
			tvl += strategy.getUpdatedUnderlyingBalance(address(this));
		}
	}

	/// returns expected tvl (used for estimate)
	function getTvl() public view returns (uint256 tvl) {
		uint256 l = strategyIndex.length;
		// there should be no untrusted strategies in this array
		for (uint256 i; i < l; ++i) {
			IVaultStrategy strategy = IVaultStrategy(payable(strategyIndex[i]));
			tvl += strategy.underlyingBalance(address(this));
		}
		tvl += asset.balanceOf(address(this));
	}

	function totalAssets() public view virtual override returns (uint256) {
		return floatAmnt + totalChildHoldings;
	}

	/// INTERFACE UTILS

	/// @dev returns accurate value used to estimate current value
	function estimateUnderlyingBalance(address user) external view returns (uint256) {
		uint256 shares = balanceOf(user);
		// value based on last harvest exchange rate
		uint256 cachedValue = convertToAssets(shares);
		// valued based on current tvl
		uint256 currentValue = sharesToUnderlying(shares);
		return cachedValue > currentValue ? currentValue : cachedValue;
	}

	/// @dev current exchange rate (different from previewDeposit rate)
	/// this should be used for estiamtes of withdrawals
	function sharesToUnderlying(uint256 shares) public view returns (uint256) {
		uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.
		return supply == 0 ? shares : shares.mulDivDown(getTvl(), supply);
	}

	/// @dev current exchange rate (different from previewDeposit / previewWithdrawal rate)
	/// this should be used estimate of deposit fee
	function underlyingToShares(uint256 underlyingAmnt) public view returns (uint256) {
		uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.
		return supply == 0 ? underlyingAmnt : underlyingAmnt.mulDivDown(supply, getTvl());
	}

	error TooManyStrategies();
	error VaultAddressNotMatch();
	event AddStrategy(address indexed strategy);
	event RemoveStrategy(address indexed strategy);
	event DepositIntoStrategy(address caller, address strategy, uint256 amount);
	event WithdrawFromStrategy(address caller, address strategy, uint256 amount);
}