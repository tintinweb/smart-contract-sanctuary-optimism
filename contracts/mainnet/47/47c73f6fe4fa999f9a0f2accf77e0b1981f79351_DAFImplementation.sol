/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-24
*/

// SPDX-License-Identifier: MIT


// File @openzeppelin/contracts/token/ERC20/[email protected]

// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

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


// File @openzeppelin/contracts/token/ERC20/extensions/[email protected]

// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

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


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

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


// File @openzeppelin/contracts/token/ERC20/utils/[email protected]

// OpenZeppelin Contracts v4.4.0 (token/ERC20/utils/SafeERC20.sol)

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


// File contracts/interfaces/WETH/IWETH.sol

pragma solidity ^0.8.16;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external returns (uint256);
}


// File contracts/DAFImplementation.sol

pragma solidity ^0.8.16;




interface IRillaIndex {
    function feeAddress() external view returns (address);

    function feeOutBps() external view returns (uint256);

    function feeInBps() external view returns (uint256);

    function feeSwapBps() external view returns (uint256);

    function waitTime() external view returns (uint256);

    function interimWaitTime() external view returns (uint256);

    function expireTime() external view returns (uint256);

    function rillaVoteMin() external view returns (uint256);

    function rilla() external view returns (address);

    function rillaSwapRate() external view returns (uint256);

    function treasury() external view returns (address);

    function isRillaSwapLive() external view returns (bool);

    function isPaused() external view returns (bool);

    function isAcceptedEIN(uint256 EIN) external view returns (bool);

    function createDonation(uint256 amount, uint256 EIN) external;

    function rillaFee(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) external returns (uint256);
}

// TODO: change requires for a DAF with 1 member so there is no wait time
contract DAFImplementation {
    using SafeERC20 for IERC20;
    string public name;
    address[] public members;
    Donation[] public donations;
    MemberChange[] public memberChanges;
    Swap[] public swaps;
    mapping(address => uint256) public availableFunds;
    address[] public availableTokens;

    // =========================================================
    // ============== STATE VARS WITH SETTER ===================
    // =========================================================
    address public rillaIndex;
    address public treasuryAddress;

    // =========================================================
    // ===================== CONSTANTS =========================
    // =========================================================
    uint256 constant BPS = 10000;
    address constant usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant swap0x = 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10;
    uint8 constant maxMembers = 10;

    /// @notice initializes contract
    /// @dev acts as constructor
    /// @param _rillaIndex Index contract
    /// @param _name Name of DAF
    /// @param _members All members of this DAF
    /// @return success Reports success
    function initialize(
        address _rillaIndex,
        string memory _name,
        address[] memory _members
    ) external returns (bool success) {
        require(members.length == 0, "Contract already initialized");
        require(_members.length <= maxMembers, "Max 10 members");

        for (uint256 i = 0; i < _members.length; i++) {
            members.push(_members[i]);
        }
        name = _name;
        rillaIndex = _rillaIndex;
        availableTokens.push(weth);
        availableTokens.push(usdc);
        success = true;
    }

    // =======================================================================
    // ===================== PUBLIC VIEW FUNCTIONS ===========================
    // =======================================================================
    /// @notice Helper function to grab funds and view
    /// @return tuple of tokens and balances
    function getAvailableFunds()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 length = availableTokens.length;
        address[] memory tokens = new address[](length);
        uint256[] memory balances = new uint256[](length);
        for (uint256 i = 0; i < length; ++i) {
            tokens[i] = availableTokens[i];
            balances[i] = availableFunds[tokens[i]];
        }
        return (tokens, balances);
    }

    /// @notice gets members
    /// @return an array of addresses who are members
    function getMembers() public view returns (address[] memory) {
        return members;
    }

    /// @notice Easy check if vote is passing
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    /// @return isPassing
    function voteIsPassing(uint256 id, VoteType voteType)
        public
        view
        returns (bool isPassing)
    {
        if (voteType == VoteType.DONATION) {
            Donation storage donation = donations[id];
            (isPassing, ) = voteIsPassing(donation.votes, donation.createTime);
        } else if (voteType == VoteType.MEMBERCHANGE) {
            MemberChange storage memberChange = memberChanges[id];
            (isPassing, ) = voteIsPassing(
                memberChange.votes,
                memberChange.createTime
            );
        } else {
            Swap storage swap = swaps[id];
            (isPassing, ) = voteIsPassing(swap.votes, swap.createTime);
        }
    }

    // =======================================================================
    // ===================== GENERAL FUNCTIONS ===============================
    // =======================================================================
    function executeSwap0x(
        address token,
        uint256 amount,
        bytes memory swapCallData
    ) internal {
        if (IERC20(token).allowance(address(this), swap0x) < amount) {
            IERC20(token).safeApprove(address(swap0x), type(uint256).max);
        }
        (bool success, ) = swap0x.call(swapCallData);
        require(success, "0x swap unsuccessful");
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    /// @notice reconciles balances
    /// @dev Just calls balanceOf, it's fine whoever calls this
    /// @param token Token to determine balance of
    function updateFundsAvailable(address token) public {
        if (availableFunds[token] == 0) {
            availableTokens.push(token);
        }
        availableFunds[token] = IERC20(token).balanceOf(address(this));

        // if it's 0, it's still in the availableTokens array so to avoid pushing that token to that array again, set balance to 1
        if (availableFunds[token] == 0) {
            availableFunds[token] = 1;
        }
    }

    /// @notice Actual donation to the DAF. Anyone can donate to any DAF
    /// @param token Token to donate
    /// @param amount Amount to donate
    /// @param swapCallData For the fee
    function donateToDaf(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) public onlyWhenUnpaused {
        // transfer token to here
        if (token == weth) {
            IWETH(weth).deposit{value: amount}();
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // grant allowances for RillaIndex
        if (IERC20(token).allowance(address(this), rillaIndex) < amount) {
            IERC20(token).safeApprove(address(rillaIndex), type(uint256).max);
        }

        // RillaIndex handles the fee charged
        uint256 rillaAmount = IRillaIndex(rillaIndex).rillaFee(
            token,
            amount,
            swapCallData
        );

        // After receiving RILLA, we send back to msg.sender
        IERC20(IRillaIndex(rillaIndex).rilla()).safeTransfer(
            msg.sender,
            rillaAmount
        );

        // update funds and emit event
        updateFundsAvailable(token);
        emit DonationIn(token, amount);
    }

    /// @notice Accepts ETH native payments
    /// @dev Payable to allow ETH
    function donateEthToDaf(bytes calldata swapCallData) public payable {
        donateToDaf(weth, msg.value, swapCallData);
    }

    // =======================================================================
    // ===================== VOTE CREATE FUNCTIONS ===========================
    // =======================================================================

    /// @notice Creates vote for an out donation
    /// @dev only a member of the daf may do this
    /// @param amount Amount of tokens to donate
    /// @param EIN identifier for charity to donate to
    function createOutDonation(uint256 amount, uint256 EIN)
        public
onlyWhenUnpaused 
        onlyDafMember
    {
        require(
            IRillaIndex(rillaIndex).isAcceptedEIN(EIN),
            "Charity not enabled"
        );
        require(
            IERC20(usdc).balanceOf(address(this)) >= amount,
            "RILLA: Not enough funds"
        );

        Donation storage newDonation = donations.push();
        newDonation.amount = amount;
        newDonation.EIN = uint32(EIN);
        newDonation.createTime = uint64(block.timestamp);
        // create new donation to be put up for voting
    }

    /// @notice Creates vote for a member change
    /// @param _members Members to add or remove
    /// @param add Indicates add or remove
    function createMemberChange(address[] calldata _members, bool add)
        public
onlyWhenUnpaused 
        onlyDafMember
    {
        require(_members.length + members.length < 11, "Max 10 members");
        MemberChange storage vote = memberChanges.push();
        vote.createTime = uint64(block.timestamp);
        vote.add = add;
        for (uint256 i = 0; i < _members.length; ++i) {
            vote.members.push(_members[i]);
        }

        emit MemberVoteCreation(msg.sender, _members, add);
    }

    /// @notice Create vote to swap tokens in DAF
    /// @param fromToken Token to swap from
    /// @param toToken Token to swap to
    /// @param amount Amount of fromToken to swap
    function createSwap(
        address fromToken,
        address toToken,
        uint256 amount
    ) public onlyWhenUnpaused onlyDafMember onlyRillaHolder(0) {
        Swap storage swap = swaps.push();
        swap.from = fromToken;
        swap.to = toToken;
        swap.amount = amount;
        swap.createTime = uint64(block.timestamp);
    }

    // =======================================================================
    // ===================== VOTE RELATED FUNCTIONS ==========================
    // =======================================================================
    enum VoteType {
        DONATION,
        MEMBERCHANGE,
        SWAP
    }

    /// @notice Cast vote for an active vote
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    /// @param vote Vote amount, + is yes and - is no
    function castVote(
        uint256 id,
        int256 vote,
        VoteType voteType
    )
        public
onlyWhenUnpaused 
        onlyDafMember
        onlyRillaHolder(vote)
        onlyUnfinalizedVote(id, voteType)
    {
        uint256 balance = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
            msg.sender
        );
        if (abs(int256(balance)) > vote) {
            // set to max voting power if not enough
            vote = vote > 0 ? int256(balance) : -int256(balance);
        }
        if (voteType == VoteType.DONATION) {
            donations[id].votes[msg.sender] = vote;
        } else if (voteType == VoteType.MEMBERCHANGE) {
            memberChanges[id].votes[msg.sender] = vote;
        } else if (voteType == VoteType.SWAP) {
            swaps[id].votes[msg.sender] = vote;
        }
    }

    function voteIsPassedOnCurrentVotePower(
        int256 voteResult,
        uint256 votePowerUsed,
        uint256 votesRemaining
    ) internal pure returns (bool) {
        return
            votePowerUsed >= 5000 &&
            voteResult >= 0 &&
            uint256(voteResult) >= votesRemaining;
    }

    // if votes are greater than 50% and voteResult is negative and voteresult is further negative than there are votes left, it fails
    function voteIsFailedOnCurrentVotePower(
        int256 voteResult,
        uint256 votePowerUsed,
        uint256 votesRemaining
    ) internal pure returns (bool) {
        return
            votePowerUsed >= 5000 &&
            voteResult < 0 &&
            uint256(abs(voteResult)) >= votesRemaining;
    }

    function voteIsPassing(
        mapping(address => int256) storage votes,
        uint64 createTime
    ) internal view returns (bool passing, string memory errorMessage) {
        (int256 voteResult, uint256 votePowerUsed) = computeVoteBps(votes);
        uint256 votesRemaining = BPS - votePowerUsed;

        if (
            voteIsPassedOnCurrentVotePower(
                voteResult,
                votePowerUsed,
                votesRemaining
            )
        ) {
            passing =
                block.timestamp >=
                createTime + IRillaIndex(rillaIndex).interimWaitTime();
            errorMessage = "Must allow the interim wait time before fulfilling vote";
        } else if (
            voteIsFailedOnCurrentVotePower(
                voteResult,
                votePowerUsed,
                votesRemaining
            )
        ) {
            passing = false;
            errorMessage = "Vote failed.";
        } else if (
            voteResult > 0 &&
            block.timestamp < createTime + IRillaIndex(rillaIndex).expireTime()
        ) {
            passing =
                block.timestamp >=
                createTime + IRillaIndex(rillaIndex).waitTime();
            errorMessage = "Must allow the wait time if voting power < 50%";
        }
    }

    /// @notice Check if vote is active
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    /// @return True if vote is active
    function isVoteActive(uint256 id, VoteType voteType)
        public 
        view
        returns (bool)
    {
        uint256 createTime;
        bool finalized;
        if (voteType == VoteType.DONATION) {
            createTime = donations[id].createTime;
            finalized = donations[id].finalized;
        } else if (voteType == VoteType.MEMBERCHANGE) {
            createTime = memberChanges[id].createTime;
            finalized = memberChanges[id].finalized;
        } else {
            createTime = swaps[id].createTime;
            finalized = swaps[id].finalized;
        }
        return
            block.timestamp >= createTime &&
            createTime <
            block.timestamp + IRillaIndex(rillaIndex).expireTime() &&
            !finalized;
    }

    /// @notice Computes voteresult and votepowerused
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    function computeGeneralVoteBps(uint256 id, VoteType voteType)
        public
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        if (voteType == VoteType.DONATION) {
            return computeVoteBps(donations[id].votes);
        } else if (voteType == VoteType.MEMBERCHANGE) {
            return computeVoteBps(memberChanges[id].votes);
        } else if (voteType == VoteType.SWAP) {
            return computeVoteBps(swaps[id].votes);
        }
    }

    function computeVoteBps(mapping(address => int256) storage votes)
        internal
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        uint256[] memory votingPower = new uint256[](members.length);
        uint256 votingPowerSum;
        for (uint256 i = 0; i < members.length; ++i) {
            votingPower[i] = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
                members[i]
            );
            votingPowerSum += votingPower[i];
            voteResult += votes[members[i]];
            votePowerUsed += uint256(abs(votes[members[i]]));
        }
        voteResult = (int256(BPS) * voteResult) / int256(votingPowerSum);
        votePowerUsed = (BPS * votePowerUsed) / votingPowerSum;
    }

    // =======================================================================
    // ===================== FULFILLMENT FUNCTIONS ===========================
    // =======================================================================

    /// @notice Fulfills donation if vote is passing
    /// @param donationId id of donation
    function fulfillDonation(uint256 donationId) public onlyWhenUnpaused onlyDafMember {
        Donation storage donation = donations[donationId];

        // check for expired status
        require(
            isVoteActive(donationId, VoteType.DONATION),
            "Vote has expired."
        );
        (bool passing, string memory errorMessage) = (
            voteIsPassing(donation.votes, donation.createTime)
        );
        require(passing, errorMessage);

        // charge fees
        uint256 outFee = chargeFee(
            usdc,
            donation.amount,
            FeeType.OUT,
            new bytes(0)
        );
        IERC20(usdc).safeTransfer(rillaIndex, donation.amount - outFee);
        // bookkeeping
        donation.finalized = true;
        updateFundsAvailable(usdc);

        // log in index
        IRillaIndex(rillaIndex).createDonation(
            donation.amount - outFee,
            donation.EIN
        );
        emit DonationOut(donation.amount - outFee, donation.EIN);
    }

    /// @notice Fulfills member change if vote is passing
    /// @param voteId id of memberchange vote
    function fulfillMemberChange(uint256 voteId) public onlyWhenUnpaused onlyDafMember {
        MemberChange storage memberChange = memberChanges[voteId];

        // check for expired status
        require(isVoteActive(voteId, VoteType.MEMBERCHANGE), "Vote expired.");
        (bool passing, string memory errorMessage) = (
            voteIsPassing(memberChange.votes, memberChange.createTime)
        );
        require(passing, errorMessage);

        address[] memory _members = memberChanges[voteId].members;
        if (memberChanges[voteId].add) {
            for (uint256 i = 0; i < _members.length; ++i) {
                members.push(_members[i]);
            }
            emit MembersChanged(_members, true);
        } else {
            for (uint256 i = 0; i < _members.length; ++i) {
                // find index in array
                uint256 idx = maxMembers;
                for (uint256 j = 0; j < members.length; ++j) {
                    if (members[j] == _members[i]) {
                        idx = j;
                        break;
                    }
                }
                // if index is found, overwrite entry to delete and then and pop last entry
                if (idx < maxMembers) {
                    members[idx] = members[members.length - 1];
                    members.pop();
                } else {
                    revert("Member not found");
                }
            }
            emit MembersChanged(_members, false);
        }
    }

    /// @notice Fulfills swap if vote is passing
    /// @param swapId id of swap vote
    /// @param swapCallData call data to swap tokens
    /// @param swapCallDataFee swap data for fee in USDC
    function fulfillSwap(
        uint256 swapId,
        bytes calldata swapCallData,
        bytes calldata swapCallDataFee
    ) public onlyWhenUnpaused {
        Swap storage swap = swaps[swapId];

        // check for expired status
        require(isVoteActive(swapId, VoteType.SWAP), "Vote expired.");
        (bool passing, string memory errorMessage) = (
            voteIsPassing(swap.votes, swap.createTime)
        );
        require(passing, errorMessage);
        require(
            availableFunds[swap.from] >= swap.amount,
            "Funds not available in DAF"
        );

        // execute swap, ensure usdc is the 'to' token
        uint256 prevTo = IERC20(swap.to).balanceOf(address(this));
        executeSwap0x(swap.from, swap.amount, swapCallData);
        uint256 newTo = IERC20(swap.to).balanceOf(address(this));

        // charge fee after swap
        chargeFee(swap.to, newTo - prevTo, FeeType.SWAP, swapCallDataFee);

        // book keeping
        updateFundsAvailable(swap.from);
        updateFundsAvailable(swap.to);
        emit DafSwap(swap.from, swap.to, swap.amount);
    }

    // =======================================================================
    // ================================= FEES ================================
    // =======================================================================
    enum FeeType {
        OUT,
        SWAP
    }

    function chargeFee(
        address token,
        uint256 totalAmount,
        FeeType feeType,
        bytes memory swapCallData
    ) internal returns (uint256) {
        // calculate token fee
        uint256 fee;
        if (feeType == FeeType.OUT) {
            fee = IRillaIndex(rillaIndex).feeOutBps();
        } else if (feeType == FeeType.SWAP) {
            fee = IRillaIndex(rillaIndex).feeSwapBps();
        }

        // calculate fee
        uint256 amount = (totalAmount * fee) / BPS;

        // if USDC, no swap needed
        if (token == usdc) {
            IERC20(usdc).safeTransfer(
                IRillaIndex(rillaIndex).feeAddress(),
                amount
            );
            return amount;
        }

        uint256 usdcPrevBal = IERC20(usdc).balanceOf(address(this));
        // execute swap, ensure usdc is the 'to' token
        executeSwap0x(token, amount, swapCallData);

        uint256 usdcCurBal = IERC20(usdc).balanceOf(address(this));
        require(usdcCurBal - usdcPrevBal > 0, "0x route invalid");
        IERC20(usdc).safeTransfer(
            IRillaIndex(rillaIndex).feeAddress(),
            usdcCurBal - usdcPrevBal
        );
        return usdcCurBal - usdcPrevBal;
    }

    // =======================================================================
    // ============================= FETCHING ================================
    // =======================================================================

    /// @notice Helper for active donations
    /// @dev only returns last 50 at most
    function fetchActiveDonations()
        external
        view
        returns (ViewDonations[] memory, uint256)
    {
        uint256 length = donations.length;
        ViewDonations[] memory votes = new ViewDonations[](length);
        uint256 head = 0;
        bool lenOver50 = length > 50;
        for (uint256 i = length; lenOver50 ? i > length - 50 : i > 0; i--) {
            // only grab last 50 max
            uint256 idx = i - 1;
            if (isVoteActive(idx, VoteType.DONATION)) {
                ViewDonations memory vote = votes[head];
                vote.id = idx;
                vote.amount = donations[idx].amount;
                vote.EIN = donations[idx].EIN;
                vote.createTime = donations[idx].createTime;
                vote.finalized = donations[idx].finalized;
                head++;
            }
        }
        return (votes, head);
    }

    /// @notice Helper for active member changes
    /// @dev only fetches last 50 max
    function fetchActiveMemberChanges()
        external
        view
        returns (ViewMemberVotes[] memory, uint256)
    {
        uint256 length = memberChanges.length;
        ViewMemberVotes[] memory votes = new ViewMemberVotes[](length);
        uint256 head = 0;
        bool lenOver50 = length > 50;
        for (uint256 i = length; lenOver50 ? i > length - 50 : i > 0; --i) {
            // only grab last 50 max
            uint256 idx = i - 1;
            if (isVoteActive(idx, VoteType.MEMBERCHANGE)) {
                ViewMemberVotes memory vote = votes[head];
                vote.id = idx;
                vote.add = memberChanges[idx].add;
                vote.finalized = memberChanges[idx].finalized;
                vote.members = memberChanges[idx].members;
                head++;
            }
        }
        return (votes, head);
    }

    /// @notice Helper for active swaps
    /// @dev only fetches last 50 max
    function fetchActiveSwaps()
        external
        view
        returns (ViewSwaps[] memory, uint256)
    {
        ViewSwaps[] memory viewSwaps = new ViewSwaps[](swaps.length);
        uint256 head = 0;
        uint256 length = swaps.length;
        bool lenOver50 = length > 50;
        for (uint256 i = length; lenOver50 ? i > length - 50 : i > 0; i--) {
            uint256 idx = i - 1;
            // only grab last 50 max
            if (isVoteActive(idx, VoteType.SWAP)) {
                ViewSwaps memory swap = viewSwaps[head];
                swap.id = idx;
                swap.finalized = swaps[idx].finalized;
                swap.amount = swaps[idx].amount;
                swap.from = swaps[idx].from;
                swap.to = swaps[idx].to;
                swap.toSymbol = IERC20Metadata(swap.to).symbol();
                swap.toDecimals = IERC20Metadata(swap.to).decimals();
                swap.fromSymbol = IERC20Metadata(swap.from).symbol();
                swap.fromDecimals = IERC20Metadata(swap.from).decimals();
                head++;
            }
        }
        return (viewSwaps, head);
    }

    /// @notice returns donations length (highest id)
    function getDonationsLength() external view returns (uint256) {
        return donations.length;
    }

    /// @notice returns memberChanges length (highest id)
    function getMemberChangesLength() external view returns (uint256) {
        return memberChanges.length;
    }

    /// @notice returns swaps length (highest id)
    function getSwapsLength() external view returns (uint256) {
        return swaps.length;
    }

    // =========================================================
    // =========== EVENTS, MODIFIERS, AND STRUCTS  =============
    // =========================================================
    event DonationIn(address token, uint256 amount);
    event DonationOut(uint256 amount, uint32 EIN);
    event DafSwap(address from, address to, uint256 amount);
    event MemberVoteCreation(
        address creator,
        address[] members,
        bool addOrRemove
    );
    event MembersChanged(address[] modified, bool addOrRemove);

    modifier onlyDafMember() {
        bool isMember = false;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Sender is not a member of this DAF.");
        _;
    }

    modifier onlyUnfinalizedVote(uint256 id, VoteType voteType) {
        require(
            voteType == VoteType.DONATION
                ? !donations[id].finalized
                : voteType == VoteType.MEMBERCHANGE
                ? !memberChanges[id].finalized
                : !swaps[id].finalized,
            "Vote already finalized"
        );
        require(isVoteActive(id, voteType), "Vote is not active");
        _;
    }

    modifier onlyRillaHolder(int256 voteSize) {
        uint256 balance = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
            msg.sender
        );
        require(
            balance >= uint256(abs(voteSize)) &&
                balance > IRillaIndex(rillaIndex).rillaVoteMin(),
            "Not enough RILLA voting power"
        );
        _;
    }

    modifier onlyWhenUnpaused() {
        require(!IRillaIndex(rillaIndex).isPaused(), "Contract is paused");
        _;
    }

    struct Donation {
        uint64 createTime;
        bool finalized;
        uint256 amount;
        uint32 EIN;
        mapping(address => int256) votes;
    }

    struct MemberChange {
        uint64 createTime;
        bool finalized;
        bool add;
        address[] members;
        mapping(address => int256) votes;
    }

    struct Swap {
        uint64 createTime;
        bool finalized;
        uint256 amount;
        address from;
        address to;
        mapping(address => int256) votes;
    }

    struct ViewDonations {
        uint256 id;
        uint256 amount;
        uint32 EIN;
        uint64 createTime;
        bool finalized;
    }

    struct ViewMemberVotes {
        uint256 id;
        bool add;
        bool finalized;
        address[] members;
    }

    struct ViewSwaps {
        uint256 id;
        bool finalized;
        uint256 amount;
        address from;
        address to;
        string toSymbol;
        string fromSymbol;
        uint256 toDecimals;
        uint256 fromDecimals;
    }
}