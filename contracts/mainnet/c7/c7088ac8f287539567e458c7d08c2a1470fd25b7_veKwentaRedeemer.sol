// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

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
pragma solidity ^0.8.0;

library VestingEntries {
    struct VestingEntry {
        uint64 endTime;
        uint256 escrowAmount;
        uint256 duration;
    }
    struct VestingEntryWithID {
        uint64 endTime;
        uint256 escrowAmount;
        uint256 entryID;
    }
}

interface IRewardEscrow {
    // Views
    function getKwentaAddress() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function numVestingEntries(address account) external view returns (uint256);

    function totalEscrowedAccountBalance(address account)
        external
        view
        returns (uint256);

    function totalVestedAccountBalance(address account)
        external
        view
        returns (uint256);

    function getVestingQuantity(address account, uint256[] calldata entryIDs)
        external
        view
        returns (uint256, uint256);

    function getVestingSchedules(
        address account,
        uint256 index,
        uint256 pageSize
    ) external view returns (VestingEntries.VestingEntryWithID[] memory);

    function getAccountVestingEntryIDs(
        address account,
        uint256 index,
        uint256 pageSize
    ) external view returns (uint256[] memory);

    function getVestingEntryClaimable(address account, uint256 entryID)
        external
        view
        returns (uint256, uint256);

    function getVestingEntry(address account, uint256 entryID)
        external
        view
        returns (
            uint64,
            uint256,
            uint256
        );

    // Mutative functions
    function vest(uint256[] calldata entryIDs) external;

    function createEscrowEntry(
        address beneficiary,
        uint256 deposit,
        uint256 duration
    ) external;

    function appendVestingEntry(
        address account,
        uint256 quantity,
        uint256 duration
    ) external;

    function stakeEscrow(uint256 _amount) external;

    function unstakeEscrow(uint256 _amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@kwenta/interfaces/IRewardEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title $veKWENTA redeemer for $KWENTA (Optimism)
/// @author JaredBorders ([email protected])
/// @notice exchanges $veKWENTA for equal amount of $KWENTA
/// and creates reward escrow entry for address specified by the caller
contract veKwentaRedeemer {
    /*///////////////////////////////////////////////////////////////
                                Constants
    ///////////////////////////////////////////////////////////////*/

    /// @notice token to be burned
    address public immutable veKwenta;

    /// @notice token to be redeemed
    /// @dev token will be sent to escrow
    address public immutable kwenta;

    /// @notice reward escrow address
    address public immutable rewardEscrow;

    /*///////////////////////////////////////////////////////////////
                                Events
    ///////////////////////////////////////////////////////////////*/

    /// @notice emitted when $veKWENTA is exchanged for $KWENTA
    /// @param redeemer: caller who exchanged $veKWENTA for $KWENTA
    /// @param beneficiary: account address used when creating escrow entry
    /// @param redeemedAmount: amount of $KWENTA redeemed and then escrowed
    event Redeemed(
        address indexed redeemer,
        address indexed beneficiary,
        uint256 redeemedAmount
    );

    /*///////////////////////////////////////////////////////////////
                                Errors
    ///////////////////////////////////////////////////////////////*/

    /// @notice caller has no $veKWENTA to exchange
    /// @param caller: caller of the redeem() function
    /// @param callerBalance: caller's balance of $veKWENTA
    error InvalidCallerBalance(address caller, uint256 callerBalance);

    /// @notice contract does not have enough $KWENTA to exchange
    /// @param contractBalance: veKwentaRedeemer's $KWENTA balance
    error InvalidContractBalance(uint256 contractBalance);

    /// @notice $veKWENTA transfer to this address failed
    /// @param caller: caller of the redeem() function
    error TransferFailed(address caller);

    /*///////////////////////////////////////////////////////////////
                                Constructor
    ///////////////////////////////////////////////////////////////*/

    /// @notice establish necessary addresses
    /// @param _veKwenta: L2 token address of $veKWENTA
    /// @param _kwenta: L2 token address $KWENTA
    /// @param _rewardEscrow: address of reward escrow for $KWENTA
    constructor(
        address _veKwenta,
        address _kwenta,
        address _rewardEscrow
    ) {
        veKwenta = _veKwenta;
        kwenta = _kwenta;
        rewardEscrow = _rewardEscrow;
    }

    /*///////////////////////////////////////////////////////////////
                        Redemption and Escrow Creation
    ///////////////////////////////////////////////////////////////*/

    /// @notice exchange caller's $veKWENTA for $KWENTA
    /// @dev $KWENTA will be sent to reward escrow
    /// @dev caller must approve this contract to spend $veKWENTA
    /// @param _beneficiary: account address used when creating escrow entry
    function redeem(address _beneficiary) external {
        // establish $veKWENTA and $KWENTA balances
        uint256 callerveKwentaBalance = IERC20(veKwenta).balanceOf(msg.sender);
        uint256 contractKwentaBalance = IERC20(kwenta).balanceOf(address(this));

        /// ensure valid $veKWENTA balance
        if (callerveKwentaBalance == 0) {
            revert InvalidCallerBalance({
                caller: msg.sender,
                callerBalance: callerveKwentaBalance
            });
        }

        /// ensure valid $KWENTA balance
        if (callerveKwentaBalance > contractKwentaBalance) {
            revert InvalidContractBalance({
                contractBalance: contractKwentaBalance
            });
        }

        /// lock $veKWENTA in this contract
        bool success = IERC20(veKwenta).transferFrom(
            msg.sender,
            address(this),
            callerveKwentaBalance
        );

        // ensure transfer suceeded
        if (!success) {
            revert TransferFailed({caller: msg.sender});
        }

        // create escrow entry
        IERC20(kwenta).approve(rewardEscrow, callerveKwentaBalance);
        IRewardEscrow(rewardEscrow).createEscrowEntry(
            _beneficiary,
            callerveKwentaBalance,
            52 weeks
        );

        emit Redeemed({
            redeemer: msg.sender,
            beneficiary: _beneficiary,
            redeemedAmount: callerveKwentaBalance
        });
    }
}