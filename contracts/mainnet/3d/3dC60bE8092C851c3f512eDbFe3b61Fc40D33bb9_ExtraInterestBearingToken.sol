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
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
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
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
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
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
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
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
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
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
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
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
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
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(
                oldAllowance >= value,
                "SafeERC20: decreased allowance below zero"
            );
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
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
        require(
            nonceAfter == nonceBefore + 1,
            "SafeERC20: permit did not succeed"
        );
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

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                0,
                "Address: low-level call failed"
            );
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
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
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
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return
            verifyCallResultFromTarget(
                target,
                success,
                returndata,
                errorMessage
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
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
        return
            verifyCallResultFromTarget(
                target,
                success,
                returndata,
                errorMessage
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
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
        return
            verifyCallResultFromTarget(
                target,
                success,
                returndata,
                errorMessage
            );
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

    function _revert(
        bytes memory returndata,
        string memory errorMessage
    ) private pure {
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
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

import "../external/openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IExtraInterestBearingToken is IERC20 {
    /**
     * @dev Emitted after the mint action
     * @param to The address receive tokens
     * @param value The amount being
     **/
    event Mint(address indexed to, uint256 value);

    /**
     * @dev Mints `amount` eTokens to `user`
     * @param user The address receiving the minted tokens
     * @param amount The amount of tokens getting minted
     */
    function mint(address user, uint256 amount) external;

    /**
     * @dev Emitted after eTokens are burned
     * @param from The owner of the eTokens, getting them burned
     * @param target The address that will receive the underlying tokens
     * @param eTokenAmount The amount being burned
     * @param underlyingTokenAmount The amount of underlying tokens being transferred to user
     **/
    event Burn(
        address indexed from,
        address indexed target,
        uint256 eTokenAmount,
        uint256 underlyingTokenAmount
    );

    /**
     * @dev Burns eTokens from `user` and sends the underlying tokens to `receiverOfUnderlying`
     * Can only be called by the lending pool;
     * The `underlyingTokenAmount` should be calculated based on the current exchange rate in lending pool
     * @param receiverOfUnderlying The address that will receive the underlying
     * @param eTokenAmount The amount of eTokens being burned
     * @param underlyingTokenAmount The amount of underlying tokens being transferred to user
     **/
    function burn(
        address receiverOfUnderlying,
        uint256 eTokenAmount,
        uint256 underlyingTokenAmount
    ) external;

    /**
     * @dev Emitted after the minted to treasury
     * @param treasury The treasury address
     * @param value The amount being minted
     **/
    event MintToTreasury(address indexed treasury, uint256 value);

    /**
     * @dev Mints eTokens to the treasury of the reserve
     * @param treasury The address of treasury
     * @param amount The amount of ftokens getting minted
     */
    function mintToTreasury(address treasury, uint256 amount) external;

    /**
     * @dev Transfers the underlying tokens to `target`. Called by the LendingPool to transfer
     * underlying tokens to target in functions like borrow(), withdraw()
     * @param target The recipient of the eTokens
     * @param amount The amount getting transferred
     * @return The amount transferred
     **/
    function transferUnderlyingTo(
        address target,
        uint256 amount
    ) external returns (uint256);
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../libraries/types/DataTypes.sol";

interface ILendingPool {
    function utilizationRateOfReserve(
        uint256 reserveId
    ) external view returns (uint256);

    function borrowingRateOfReserve(
        uint256 reserveId
    ) external view returns (uint256);

    function exchangeRateOfReserve(
        uint256 reserveId
    ) external view returns (uint256);

    function totalLiquidityOfReserve(
        uint256 reserveId
    ) external view returns (uint256 totalLiquidity);

    function totalBorrowsOfReserve(
        uint256 reserveId
    ) external view returns (uint256 totalBorrows);

    function getReserveIdOfDebt(uint256 debtId) external view returns (uint256);

    event InitReserve(
        address indexed reserve,
        address indexed eTokenAddress,
        address stakingAddress,
        uint256 id
    );
    /**
     * @dev Emitted on deposit()
     * @param reserveId The id of the reserve
     * @param user The address initiating the deposit
     * @param onBehalfOf The beneficiary of the deposit, receiving the eTokens
     * @param reserveAmount The reserve amount deposited
     * @param eTokenAmount The eToken amount received
     * @param referral The referral code used
     **/
    event Deposited(
        uint256 indexed reserveId,
        address user,
        address indexed onBehalfOf,
        uint256 reserveAmount,
        uint256 eTokenAmount,
        uint16 indexed referral
    );

    /**
     * @dev Emitted on redeem()
     * @param reserveId The id of the reserve
     * @param user The address initiating the withdrawal, owner of eTokens
     * @param to Address that will receive the underlying tokens
     * @param eTokenAmount The amount of eTokens to redeem
     * @param underlyingTokenAmount The amount of underlying tokens user received after redeem
     **/
    event Redeemed(
        uint256 indexed reserveId,
        address indexed user,
        address indexed to,
        uint256 eTokenAmount,
        uint256 underlyingTokenAmount
    );

    /**
     * @dev Emitted on borrow() when debt needs to be opened
     * @param reserveId The id of the reserve
     * @param contractAddress The address of the contract to initiate this borrow
     * @param onBehalfOf The beneficiary of the borrowing, receiving the tokens in his vaultPosition
     * @param amount The amount borrowed out
     **/
    event Borrow(
        uint256 indexed reserveId,
        address indexed contractAddress,
        address indexed onBehalfOf,
        uint256 amount
    );

    /**
     * @dev Emitted on repay()
     * @param reserveId The id of the reserve
     * @param onBehalfOf The user who repay debts in his vaultPosition
     * @param contractAddress The address of the contract to initiate this repay
     * @param amount The amount repaid
     **/
    event Repay(
        uint256 indexed reserveId,
        address indexed onBehalfOf,
        address indexed contractAddress,
        uint256 amount
    );

    /**
     * @dev Emitted when the pause is triggered.
     */
    event Paused();

    /**
     * @dev Emitted when the pause is lifted.
     */
    event UnPaused();

    event EnableVaultToBorrow(
        uint256 indexed vaultId,
        address indexed vaultAddress
    );

    event DisableVaultToBorrow(
        uint256 indexed vaultId,
        address indexed vaultAddress
    );

    event SetCreditsOfVault(
        uint256 indexed vaultId,
        address indexed vaultAddress,
        uint256 indexed reserveId,
        uint256 credit
    );

    event SetInterestRateConfig(
        uint256 indexed reserveId,
        uint16 utilizationA,
        uint16 borrowingRateA,
        uint16 utilizationB,
        uint16 borrowingRateB,
        uint16 maxBorrowingRate
    );

    event SetReserveCapacity(uint256 indexed reserveId, uint256 cap);

    event SetReserveFeeRate(uint256 indexed reserveId, uint256 feeRate);

    event ReserveActivated(uint256 indexed reserveId);
    event ReserveDeActivated(uint256 indexed reserveId);
    event ReserveFrozen(uint256 indexed reserveId);
    event ReserveUnFreeze(uint256 indexed reserveId);
    event ReserveBorrowEnabled(uint256 indexed reserveId);
    event ReserveBorrowDisabled(uint256 indexed reserveId);

    struct ReserveStatus {
        uint256 reserveId;
        address underlyingTokenAddress;
        address eTokenAddress;
        address stakingAddress;
        uint256 totalLiquidity;
        uint256 totalBorrows;
        uint256 exchangeRate;
        uint256 borrowingRate;
    }

    struct PositionStatus {
        uint256 reserveId;
        address user;
        uint256 eTokenStaked;
        uint256 eTokenUnStaked;
        uint256 liquidity;
    }

    function getReserveStatus(
        uint256[] calldata reserveIdArr
    ) external view returns (ReserveStatus[] memory statusArr);

    function getPositionStatus(
        uint256[] calldata reserveIdArr,
        address user
    ) external view returns (PositionStatus[] memory statusArr);

    /**
     * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying eTokens.
     * - E.g. User deposits 100 USDC and gets in return for specific amount of eUSDC
     * the eUSDC amount depends on the exchange rate between USDC and eUSDC
     * @param reserveId The ID of the reserve
     * @param amount The amount of reserve to be deposited
     * @param onBehalfOf The address that will receive the eTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of eTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function deposit(
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external payable returns (uint256);

    /**
     * @dev User redeems eTokens in exchange for the underlying asset
     * E.g. User has 100 eUSDC, and the current exchange rate of eUSDC and USDC is 1:1.1
     * he will receive 110 USDC after redeem 100eUSDC
     * @param reserveId The id of the reserve
     * @param eTokenAmount The amount of eTokens to redeem
     *   - If the amount is type(uint256).max, all of user's eTokens will be redeemed
     * @param to Address that will receive the underlying tokens, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @param receiveNativeETH If receive native ETH, set this param to true
     * @return The underlying token amount user finally receive
     **/
    function redeem(
        uint256 reserveId,
        uint256 eTokenAmount,
        address to,
        bool receiveNativeETH
    ) external returns (uint256);

    function newDebtPosition(uint256 reserveId) external returns (uint256);

    function getCurrentDebt(
        uint256 debtId
    ) external view returns (uint256 currentDebt, uint256 latestBorrowingIndex);

    /**
     * @dev Allows farming users to borrow a specific `amount` of the reserve underlying asset.
     * The user's borrowed tokens is transferred to the vault position contract and is recorded in the user's vault position(VaultPositionManageContract).
     * When debt ratio of user's vault position reach the liquidate limit,
     * the position will be liquidated and repay his debt(borrowed value + accrued interest)
     * @param onBehalfOf The beneficiary of the borrowing, receiving the tokens in his vaultPosition
     * @param debtId The debtPositionId
     * @param amount The amount to be borrowed
     */
    function borrow(
        address onBehalfOf,
        uint256 debtId,
        uint256 amount
    ) external;

    /**
     * @notice Repays borrowed underlying tokens to the reserve pool
     * The user's debt is recorded in the vault position(VaultPositionManageContract).
     * After this function successfully executed, user's debt should be reduced in VaultPositionManageContract.
     * @param onBehalfOf The user who repay debts in his vaultPosition
     * @param debtId The debtPositionId
     * @param amount The amount to be borrowed
     * @return The final amount repaid
     **/
    function repay(
        address onBehalfOf,
        uint256 debtId,
        uint256 amount
    ) external returns (uint256);

    function getUnderlyingTokenAddress(
        uint256 reserveId
    ) external view returns (address underlyingTokenAddress);

    function getETokenAddress(
        uint256 reserveId
    ) external view returns (address underlyingTokenAddress);

    function getStakingAddress(
        uint256 reserveId
    ) external view returns (address);

    function reserves(
        uint256
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            address,
            address,
            address,
            uint256,
            DataTypes.InterestRateConfig memory,
            uint256,
            uint128,
            uint16,
            DataTypes.Flags memory
        );
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

import "../external/openzeppelin/contracts/utils/math/SafeMath.sol";
import "../external/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../external/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../external/openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../external/openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IExtraInterestBearingToken.sol";
import "../interfaces/ILendingPool.sol";
import "../libraries/helpers/Errors.sol";

/**
 * @title ExtraInterestBearingToken(EToken)
 * @dev Implementation of the interest bearing token(eToken) for the extraFi Lending Pool
 * @author extraFi Team
 */
contract ExtraInterestBearingToken is
    IExtraInterestBearingToken,
    ReentrancyGuard,
    ERC20
{
    using SafeERC20 for IERC20;

    address public immutable lendingPool;
    address public immutable underlyingAsset;

    uint8 private _decimals;

    modifier onlyLendingPool() {
        require(
            msg.sender == lendingPool,
            Errors.LP_CALLER_MUST_BE_LENDING_POOL
        );
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address underlyingAsset_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;

        require(underlyingAsset_ != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        underlyingAsset = underlyingAsset_;
        lendingPool = msg.sender;
    }

    /**
     * @dev Mints `amount` eTokens to `user`, only the LendingPool Contract can call this function.
     * @param user The address receiving the minted tokens
     * @param amount The amount of tokens getting minted
     */
    function mint(
        address user,
        uint256 amount
    ) external onlyLendingPool nonReentrant {
        _mint(user, amount);
        emit Mint(user, amount);
    }

    /**
     * @dev Burns eTokens from `user` and sends the underlying tokens to `receiverOfUnderlying`
     * Can only be called by the lending pool;
     * The `underlyingTokenAmount` should be calculated based on the current exchange rate in lending pool
     * @param receiverOfUnderlying The address that will receive the underlying tokens
     * @param eTokenAmount The amount of eTokens being burned
     * @param underlyingTokenAmount The amount of underlying tokens being transferred to user
     **/
    function burn(
        address receiverOfUnderlying,
        uint256 eTokenAmount,
        uint256 underlyingTokenAmount
    ) external onlyLendingPool nonReentrant {
        _burn(msg.sender, eTokenAmount);

        IERC20(underlyingAsset).safeTransfer(
            receiverOfUnderlying,
            underlyingTokenAmount
        );

        emit Burn(
            msg.sender,
            receiverOfUnderlying,
            eTokenAmount,
            underlyingTokenAmount
        );
    }

    /**
     * @dev Mints eTokens to the reserve's fee receiver
     * @param treasury The address of treasury
     * @param amount The amount of tokens getting minted
     */
    function mintToTreasury(
        address treasury,
        uint256 amount
    ) external onlyLendingPool nonReentrant {
        require(treasury != address(0), "zero address");
        _mint(treasury, amount);
        emit MintToTreasury(treasury, amount);
    }

    /**
     * @dev Transfers the underlying tokens to `target`. Called by the LendingPool to transfer
     * underlying tokens to target in functions like borrow(), withdraw()
     * @param target The recipient of the eTokens
     * @param amount The amount getting transferred
     * @return The amount transferred
     **/
    function transferUnderlyingTo(
        address target,
        uint256 amount
    ) external onlyLendingPool nonReentrant returns (uint256) {
        IERC20(underlyingAsset).safeTransfer(target, amount);
        return amount;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @notice Defines the error messages emitted by the different contracts
 * @dev Error messages prefix glossary:
 *  - VL = ValidationLogic
 *  - VT = Vault
 *  - LP = LendingPool
 *  - P = Pausable
 */
library Errors {
    //contract specific errors
    string internal constant VL_TRANSACTION_TOO_OLD = "0"; // 'Transaction too old'
    string internal constant VL_NO_ACTIVE_RESERVE = "1"; // 'Action requires an active reserve'
    string internal constant VL_RESERVE_FROZEN = "2"; // 'Action cannot be performed because the reserve is frozen'
    string internal constant VL_CURRENT_AVAILABLE_LIQUIDITY_NOT_ENOUGH = "3"; // 'The current liquidity is not enough'
    string internal constant VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE = "4"; // 'User cannot withdraw more than the available balance'
    string internal constant VL_TRANSFER_NOT_ALLOWED = "5"; // 'Transfer cannot be allowed.'
    string internal constant VL_BORROWING_NOT_ENABLED = "6"; // 'Borrowing is not enabled'
    string internal constant VL_INVALID_DEBT_OWNER = "7"; // 'Invalid interest rate mode selected'
    string internal constant VL_BORROWING_CALLER_NOT_IN_WHITELIST = "8"; // 'The collateral balance is 0'
    string internal constant VL_DEPOSIT_TOO_MUCH = "9"; // 'Deposit too much'
    string internal constant VL_OUT_OF_CAPACITY = "10"; // 'There is not enough collateral to cover a new borrow'
    string internal constant VL_OUT_OF_CREDITS = "11"; // 'Out of credits, there is not enough credits to borrow'
    string internal constant VL_PERCENT_TOO_LARGE = "12"; // 'Percentage too large'
    string internal constant VL_ADDRESS_CANNOT_ZERO = "13"; // vault address cannot be zero
    string internal constant VL_VAULT_UN_ACTIVE = "14";
    string internal constant VL_VAULT_FROZEN = "15";
    string internal constant VL_VAULT_BORROWING_DISABLED = "16";
    string internal constant VL_NOT_WETH9 = "17";
    string internal constant VL_INSUFFICIENT_WETH9 = "18";
    string internal constant VL_INSUFFICIENT_TOKEN = "19";
    string internal constant VL_LIQUIDATOR_NOT_IN_WHITELIST = "20";
    string internal constant VL_COMPOUNDER_NOT_IN_WHITELIST = "21";
    string internal constant VL_VAULT_ALREADY_INITIALIZED = "22";
    string internal constant VL_TREASURY_ADDRESS_NOT_SET = "23";

    string internal constant VT_INVALID_RESERVE_ID = "40"; // invalid reserve id
    string internal constant VT_INVALID_POOL = "41"; // invalid uniswap v3 pool
    string internal constant VT_INVALID_VAULT_POSITION_MANAGER = "42"; // invalid vault position manager
    string internal constant VT_VAULT_POSITION_NOT_ACTIVE = "43"; // vault position is not active
    string internal constant VT_VAULT_POSITION_AUTO_COMPOUND_NOT_ENABLED = "44"; // 'auto compound not enabled'
    string internal constant VT_VAULT_POSITION_ID_INVALID = "45"; // 'VaultPositionId invalid'
    string internal constant VT_VAULT_PAUSED = "46"; // 'vault is paused'
    string internal constant VT_VAULT_FROZEN = "47"; // 'vault is frozen'
    string internal constant VT_VAULT_CALLBACK_INVALID_SENDER = "48"; // 'callback must be initiate by the vault self
    string internal constant VT_VAULT_DEBT_RATIO_TOO_LOW_TO_LIQUIDATE = "49"; // 'debt ratio haven't reach liquidate ratio'
    string internal constant VT_VAULT_POSITION_MANAGER_INVALID = "50"; // 'invalid vault manager'
    string internal constant VT_VAULT_POSITION_RANGE_STOP_DISABLED = "60"; // 'vault positions' range stop is disabled'
    string internal constant VT_VAULT_POSITION_RANGE_STOP_PRICE_INVALID = "61"; // 'invalid range stop price'
    string internal constant VT_VAULT_POSITION_OUT_OF_MAX_LEVERAGE = "62";
    string internal constant VT_VAULT_POSITION_SHARES_INVALID = "63";

    string internal constant LP_NOT_ENOUGH_LIQUIDITY_TO_BORROW = "80"; // 'There is not enough liquidity available to borrow'
    string internal constant LP_CALLER_MUST_BE_LENDING_POOL = "81"; // 'Caller must be lending pool contract'
    string internal constant LP_BORROW_INDEX_OVERFLOW = "82"; // 'The borrow index overflow'
    string internal constant LP_IS_PAUSED = "83"; // lending pool is paused
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

library DataTypes {
    struct DebtPositionData {
        uint256 reserveId;
        address owner;
        uint256 borrowed;
        uint256 borrowedIndex;
    }

    struct VaultPositionData {
        // manager of the position, who can adjust the position
        address manager;
        // tokenId of the v3 NFT position
        uint256 v3TokenId;
        // The debt positionId for token0
        uint256 debtPositionId0;
        // The debt share for token0
        uint256 debtShare0;
        // The debt positionId for token1
        uint256 debtPositionId1;
        // The debt share for token1
        uint256 debtShare1;
        // Total shares of this position
        uint256 totalShares;
    }

    // Interest Rate Config
    // The utilization rate and borrowing rate are expressed in RAY
    // utilizationB must gt utilizationA
    struct InterestRateConfig {
        // The utilization rate a, the end of the first slope on interest rate curve
        uint128 utilizationA;
        // The borrowing rate at utilization_rate_a
        uint128 borrowingRateA;
        // The utilization rate a, the end of the first slope on interest rate curve
        uint128 utilizationB;
        // The borrowing rate at utilization_rate_b
        uint128 borrowingRateB;
        // the max borrowing rate while the utilization is 100%
        uint128 maxBorrowingRate;
    }

    struct ReserveData {
        // variable borrow index.
        uint256 borrowingIndex;
        // the current borrow rate.
        uint256 currentBorrowingRate;
        // the total borrows of the reserve at a variable rate. Expressed in the currency decimals
        uint256 totalBorrows;
        // underlying token address
        address underlyingTokenAddress;
        // eToken address
        address eTokenAddress;
        // staking address
        address stakingAddress;
        // the capacity of the reserve pool
        uint256 reserveCapacity;
        // borrowing rate config
        InterestRateConfig borrowingRateConfig;
        // the id of the reserve. Represents the position in the list of the reserves
        uint256 id;
        uint128 lastUpdateTimestamp;
        // reserve fee charged, percent of the borrowing interest that is put into the treasury.
        uint16 reserveFeeRate;
        Flags flags;
    }

    struct Flags {
        bool isActive; // set to 1 if the reserve is properly configured
        bool frozen; // set to 1 if reserve is frozen, only allows repays and withdraws, but not deposits or new borrowings
        bool borrowingEnabled; // set to 1 if borrowing is enabled, allow borrowing from this pool
    }
}