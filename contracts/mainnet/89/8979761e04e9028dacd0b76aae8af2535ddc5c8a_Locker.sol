/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-14
*/

// Sources flattened with hardhat v2.10.0 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

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


// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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


// File @openzeppelin/contracts/token/ERC20/[email protected]


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


// File @openzeppelin/contracts/token/ERC20/extensions/[email protected]


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


// File @openzeppelin/contracts/utils/[email protected]


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
}


// File @openzeppelin/contracts/token/ERC20/utils/[email protected]


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;



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
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File contracts/interfaces/OwnableInterface.sol


pragma solidity ^0.8.0;

//borrowed from Chainlink
//https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/OwnableInterface.sol
interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}


// File contracts/ConfirmedOwnerWithProposal.sol


pragma solidity ^0.8.0;

// Borrowed from Chainlink
//https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ConfirmedOwnerWithProposal.sol

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}


// File contracts/interfaces/IVoter.sol

pragma solidity 0.8.9;

interface IVoter {
    function _ve() external view returns (address);
    function governor() external view returns (address);
    function emergencyCouncil() external view returns (address);
    function attachTokenToGauge(uint _tokenId, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distribute(address _gauge) external;
    function vote( uint tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;
    function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint _tokenId) external;
    function claimFees(address[] memory _fees, address[][] memory _tokens, uint _tokenId) external ;
    function reset(uint256 _tokenId) external;
    function gauges(address pool) external view returns(address);
}


// File contracts/interfaces/IVotingEscrow.sol

pragma solidity 0.8.9;

interface IVotingEscrow {

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function token() external view returns (address);
    function team() external returns (address);
    function epoch() external view returns (uint);
    function point_history(uint loc) external view returns (Point memory);
    function user_point_history(uint tokenId, uint loc) external view returns (Point memory);
    function user_point_epoch(uint tokenId) external view returns (uint);

    function ownerOf(uint) external view returns (address);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function transferFrom(address, address, uint) external;

    function voting(uint tokenId) external;
    function abstain(uint tokenId) external;
    function attach(uint tokenId) external;
    function detach(uint tokenId) external;

    function checkpoint() external;
    function deposit_for(uint tokenId, uint value) external;
    function create_lock_for(uint, uint, address) external returns (uint);
    function create_lock(uint _value, uint _lock_duration) external returns (uint);
    function increase_unlock_time(uint tokenId, uint lock_duration) external;

    function balanceOfNFT(uint) external view returns (uint);
    function totalSupply() external view returns (uint);

    function withdraw(uint _tokenId) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

}


// File contracts/interfaces/IRewardsDistributor.sol

pragma solidity 0.8.9;

interface IRewardsDistributor {
    function claim_many(uint[] memory _tokenIds) external returns (bool);
}


// File contracts/Locker.sol

pragma solidity =0.8.9;





//ConfirmedOwnerWithProposal is an upgraded form of Ownable created by Chainlink with 2 stage proposal/acceptance for ownership
contract Locker is ConfirmedOwnerWithProposal(msg.sender, address(0)) {

    using SafeERC20 for IERC20;

    // VELO governance token
    IERC20 immutable public velo; 
    // Velodrome voter contract 
    IVoter immutable public voter;
    // Velodrome veVELO NFT contract, used to create voting locks
    IVotingEscrow immutable public votingEscrow;
    //Velodrome rewards distributor, used to claim VELO rebases for locked VELO tokens
    IRewardsDistributor immutable public rewardsDistributor;

    //array storing the Ids of each veNFT generated by lockVELO()
    uint256[] public veNFTIds;

    event RemoveExcessTokens(address token, address to, uint256 amount);
    event GenerateVeNFT(uint256 id, uint256 lockedAmount, uint256 lockDuration);
    event RelockVeNFT(uint256 id, uint256 lockDuration);
    event NFTVoted(uint256 id, uint256 timestamp);
    event WithdrawVeNFT(uint256 id, uint256 timestamp);
    event ClaimedBribes(uint256 id, uint256 timestamp);
    event ClaimedFees(uint256 id, uint256 timestamp);
    event ClaimedRebases(uint256[] id, uint256 timestamp);


    

    constructor(address _VeloAddress, 
                address _VoterAddress, 
                address _VotingEscrowAddress, 
                address _RewardsDistributorAddress){

        velo = IERC20(_VeloAddress);
        voter = IVoter(_VoterAddress);
        votingEscrow = IVotingEscrow(_VotingEscrowAddress);
        rewardsDistributor = IRewardsDistributor(_RewardsDistributorAddress);
    }

    /////// External functions callable by only the owner ///////

    /**
    *    @notice Function to lock the contracts VELO tokens as a veNFT for voting with
    *    @param _tokenAmount amount of VELO to lock into veNFT
    *    @param _lockDuration time in seconds you wish to lock the tokens for, 
    *           must be less than or equal to 4 years (4*365*24*60*60 = 126144000)
    **/
    function lockVELO(uint256 _tokenAmount, uint256 _lockDuration) external onlyOwner {
        //approve transfer of VELO to votingEscrow contract, bad pattern, prefer increaseApproval but VotingEscrow is not upgradable so should be ok
        velo.approve(address(votingEscrow), _tokenAmount);
        //create lock
        uint256 NFTId = votingEscrow.create_lock(_tokenAmount, _lockDuration);
        //store new NFTId for reference
        veNFTIds.push(NFTId);
        emit GenerateVeNFT(NFTId, _tokenAmount, _lockDuration);

    }
    
    /**
    *    @notice Function to relock existing veNFTs to get the maximum amount of voting power
    *    @param _NFTId Id of the veNFT you wish to relock
    *    @param _lockDuration time in seconds you wish to lock the tokens for, 
    *           must exceed current lock and must be less than or equal to 4 years (4*365*24*60*60 = 126144000)
    **/
    function relockVELO(uint256 _NFTId, uint256 _lockDuration) external onlyOwner{
        votingEscrow.increase_unlock_time(_NFTId, _lockDuration);
        emit RelockVeNFT(_NFTId, _lockDuration);
    }

    /**
    *    @notice Function to vote for pool gauge using one or more veNFTs
    *    @param _NFTIds array of Ids of the veNFTs you wish to vote with
    *    @param _poolVote the array of pools you wish to vote for, with weight stored in the respective slot of the _weights array
    *    @param _weights the array of pool weights relating to the pool addresses passed in, max value 10000 is 100%
    **/
    function vote(uint[] calldata _NFTIds, address[] calldata _poolVote, uint256[] calldata _weights) external onlyOwner {
        uint256 length = _NFTIds.length;
        for(uint256 i = 0; i < length; ++i ){
            voter.vote(_NFTIds[i], _poolVote, _weights);
            emit NFTVoted(_NFTIds[i], block.timestamp);
        }
        
    }

    /**
    *    @notice Function to withdraw veNFT's VELO tokens after lock has expired.
    *    @dev we delete the array entry related to this veNFT but leave it as 0 rather than resorting 
    *         this is a degisn decision as we are unlikely to call withdrawNFT for a long while (1+ years)
    *    @param _tokenId the Id of the veNFT you wish to burn and redeem the VELO associated with
    *    @param _index the slot of the array where this veNFT's id is stored.
    **/
    function withdrawNFT(uint256 _tokenId, uint256 _index) external onlyOwner {
        //ensure we are deleting the right veNFTId slot
        require(veNFTIds[_index] == _tokenId , "Wrong index slot");
        //abstain from current epoch vote to reset voted to false, allowing withdrawal
        voter.reset(_tokenId);
        //request withdrawal
        votingEscrow.withdraw(_tokenId);
        //delete stale veNFTId as veNFT is now burned.
        delete veNFTIds[_index];
        emit WithdrawVeNFT(_tokenId, block.timestamp);
    }
   
    /**
    *    @notice Function to withdraw VELO tokens or bribe rewards from contract by owner.
    *    @param _tokens array of addresses of ERC20 token you wish to receive
    *    @param _amounts array of amounts of ERC20 token you wish to withdraw, relating to the same slot of the _tokens array.
    **/
    function removeERC20Tokens(address[] calldata _tokens, uint256[] calldata _amounts) external onlyOwner {
        uint256 length = _tokens.length;
        require(length == _amounts.length, "Mismatched arrays");

        for (uint256 i = 0; i < length; ++i){
            IERC20(_tokens[i]).safeTransfer(msg.sender, _amounts[i]);
            emit RemoveExcessTokens(_tokens[i], msg.sender, _amounts[i]);
        }
        
    }

    /**
    *    @notice Function to transfer veNFT to another account
    *    @dev Because veNFTs can be transferred if the protocol should ever wish to sell 
              some veNFTs this enables them to do so before the 4 year lock expires.
    *    @param _tokenIds The array of ids of the veNFT tokens that we are transfering 
    **/
    function transferNFTs(uint256[] calldata _tokenIds, uint256[] calldata _indexes ) external onlyOwner {
        uint256 length = _tokenIds.length;
        require(length == _indexes.length, "Mismatched arrays");

        for (uint256 i =0; i < length; ++i){
            require(veNFTIds[_indexes[i]] == _tokenIds[i] , "Wrong index slot");
            delete veNFTIds[_indexes[i]];
            //abstain from current epoch vote to reset voted to false, allowing transfer
            voter.reset(_tokenIds[i]);
            //here msg.sender is always owner.
            votingEscrow.safeTransferFrom(address(this), msg.sender, _tokenIds[i]);
            //no event needed as votingEscrow emits one on transfer anyway
        }
    }

    /////// External functions callable by anyone ///////

    /**
    *    @notice Function to claim bribes associated to pools previously voted for
    *    @dev Anyone can call this function to reduce pressure on Multisig owner to sign every week
    *    @param _bribes array of addresses for the wrapped external bribe contract of each bribe
    *    @param _tokens array of token addresses we are claiming bribes in, i.e. the tokens we wish to receive
    *    @param _tokenIds The array of ids of the veNFT tokens that we are claiming for 
    **/
    function claimBribesMultiNFTs(address[] calldata _bribes, address[][] calldata _tokens, uint[] calldata _tokenIds) external {
        uint256 length = _tokenIds.length;
        for (uint256 i =0; i < length; ++i){
            voter.claimBribes(_bribes, _tokens, _tokenIds[i]);
            emit ClaimedBribes(_tokenIds[i], block.timestamp);
        }
    }

    /**
    *    @notice Function to claim fees associated to a pool previously voted for
    *    @dev Anyone can call this function to reduce pressure on Multisig owner to sign every week
    *    @dev internally claimFees and claimBribes are identical functions in Velodrome's voter contract, this is here for readability
    *    @param _fees array of addresses for the internal bribe contract of each fee pool
    *    @param _tokens array of token addresses we are claiming fees in, i.e. the tokens we wish to receive
    *    @param _tokenIds The array of ids of the veNFT tokens that we are claiming for 
    **/
    function claimFeesMultiNFTs(address[] calldata _fees, address[][] calldata _tokens, uint[] calldata _tokenIds) external {
        uint256 length = _tokenIds.length;
        for (uint256 i =0; i < length; ++i){
            voter.claimFees(_fees, _tokens, _tokenIds[i]);
            emit ClaimedFees(_tokenIds[i], block.timestamp);
        }
    }

    /**
    *    @notice Function to claim VELO rebase associated to NFTs previously voted with
    *    @dev Anyone can call this function to reduce pressure on Multisig owner to sign every week
    *    @param _tokenIds The array of ids of the veNFT tokens that we are claiming for 
    **/
    function claimRebaseMultiNFTs(uint256[] calldata _tokenIds) external {
       rewardsDistributor.claim_many(_tokenIds);
       emit ClaimedRebases(_tokenIds, block.timestamp);
    }

  
}