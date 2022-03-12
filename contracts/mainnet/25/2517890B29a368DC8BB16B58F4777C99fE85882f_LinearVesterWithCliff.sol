//SPDX-License-Identifier: MIT
//copyright ZipSwap
pragma solidity ^0.8.11;

import { Ownable } from "Ownable.sol";
import { BoringERC20 } from "BoringERC20.sol";
import { BoringBatchable } from "BoringBatchable.sol";
import "IERC20.sol";

// Linear vesting with a cliff. Linear vesting starts after cliff ends.
contract LinearVesterWithCliff is Ownable, BoringBatchable {
    IERC20 public immutable token;

    struct VestingInfo {
        uint128 initialVestedAmount;
        uint128 claimedAmount;
        uint64 startTime;
        uint64 linearVestingDuration;
        uint64 cliffDuration;
    }

    mapping(address => VestingInfo) public vestee;
    uint128 public totalLocked;
    uint128 public totalClaimed;

    event Lockup(address indexed user, uint amount, uint64 startTime, uint64 linearVestingDuration, uint64 cliffDuration);
    event Claim(address indexed user, uint amount);

    constructor(IERC20 _token) {
        token = _token;
    }

    //startTime = 0 means block.timestamp
    function createLockup(address to, uint128 amount, uint64 startTime, uint64 linearVestingDuration, uint64 cliffDuration) external onlyOwner {
        require(amount > 0);
        uint unclaimedTokenBalance = token.balanceOf(address(this)) - totalLocked;
        require(unclaimedTokenBalance >= amount, 'token balance too low');
        require(vestee[to].initialVestedAmount == 0, 'vestee already exists');
        uint64 _startTime = startTime == 0 ? uint64(block.timestamp) : startTime;
        vestee[to] = VestingInfo(amount, 0, _startTime, linearVestingDuration, cliffDuration);
        totalLocked += amount;

        emit Lockup(to, amount, _startTime, linearVestingDuration, cliffDuration);
    }

    function getUnlockedUnclaimed(address who) public view returns (uint128 unlockedUnclaimed) {
        VestingInfo memory vi = vestee[who];
        //cliff
        if(vi.startTime + vi.cliffDuration > block.timestamp) {
            unlockedUnclaimed = 0;
        }
        //cliff over
        else {
            uint128 linearStartTime = vi.startTime + vi.cliffDuration;
            uint128 passed = uint64(block.timestamp)-linearStartTime;
            if(passed >= vi.linearVestingDuration) {
                unlockedUnclaimed = vi.initialVestedAmount - vi.claimedAmount;
            }
            else {
                unlockedUnclaimed = vi.initialVestedAmount*passed/vi.linearVestingDuration - vi.claimedAmount;
            }
        }
    }

    function claimUnlocked() external returns (uint128 unlockedUnclaimed) {
        unlockedUnclaimed = getUnlockedUnclaimed(msg.sender);
        require(unlockedUnclaimed > 0, 'nothing unlocked');
        vestee[msg.sender].claimedAmount += unlockedUnclaimed;
        totalLocked -= unlockedUnclaimed;
        totalClaimed += unlockedUnclaimed;
        require(token.transfer(msg.sender, unlockedUnclaimed));
        emit Claim(msg.sender, unlockedUnclaimed);
    }

    function moveVesting(address from, address to) internal {
        VestingInfo storage targetVestingInfo = vestee[to];
        require(targetVestingInfo.initialVestedAmount == 0, 'target exists');
        VestingInfo storage sourceVestingInfo = vestee[from];
        require(sourceVestingInfo.initialVestedAmount != 0, "source doesn't exist");
        vestee[to] = sourceVestingInfo;
        vestee[from] = VestingInfo(0, 0, 0, 0, 0);
    }

    function transferVesting(address to) external {
        moveVesting(msg.sender, to);
    }

    //owner functions - intended only during the initial period - owner can be renounced later

    //can only withdraw tokens that aren't already locked
    function ownerWithdrawToken(IERC20 _token, address recipient, uint amount) external onlyOwner returns (uint) {
        if(_token == token) {
            uint freeBalance = _token.balanceOf(address(this))-totalLocked;
            if(amount == 0) {
                amount = freeBalance;
                require(amount > 0, 'no unlocked tokens');
            }
            else {
                require(amount <= freeBalance, 'can only withdraw unlocked');
            }
        }
        else if(amount == 0) {
            amount = _token.balanceOf(address(this));
        }
        BoringERC20.safeTransfer(_token, recipient, amount);
        return amount;
    }

    function ownerMoveVesting(address from, address to) external onlyOwner {
        moveVesting(from, to);
    }

    function ownerForceVestAll(address user) external onlyOwner {
        VestingInfo storage vi = vestee[user];
        vi.startTime = 0;
        vi.cliffDuration = 0;
        vi.linearVestingDuration = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

abstract contract Ownable {
    address private _owner;
    address private newOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
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
    function transferOwnership(address _newOwner) public virtual onlyOwner {
        require(_newOwner != address(0), "Ownable: new owner is the zero address");
        newOwner = _newOwner;
    }

    function acceptOwnership() public virtual {
        require(msg.sender == newOwner, "Ownable: sender != newOwner");
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address _newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "IERC20.sol";

// solhint-disable avoid-low-level-calls

library BoringERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_BALANCE_OF = 0x70a08231; // balanceOf(address)
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    function returnDataToString(bytes memory data) internal pure returns (string memory) {
        unchecked {
            if (data.length >= 64) {
                return abi.decode(data, (string));
            } else if (data.length == 32) {
                uint8 i = 0;
                while (i < 32 && data[i] != 0) {
                    i++;
                }
                bytes memory bytesArray = new bytes(i);
                for (i = 0; i < 32 && data[i] != 0; i++) {
                    bytesArray[i] = data[i];
                }
                return string(bytesArray);
            } else {
                return "???";
            }
        }
    }

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @notice Provides a gas-optimized balance check to avoid a redundant extcodesize check in addition to the returndatasize check.
    /// @param token The address of the ERC-20 token.
    /// @param to The address of the user to check.
    /// @return amount The token amount.
    function safeBalanceOf(IERC20 token, address to) internal view returns (uint256 amount) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_BALANCE_OF, to));
        require(success && data.length >= 32, "BoringERC20: BalanceOf failed");
        amount = abi.decode(data, (uint256));
    }

    /// @notice Provides a safe ERC20.transfer version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    /// @notice Provides a safe ERC20.transferFrom version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param from Transfer tokens from.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}

pragma solidity >=0.5.0;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "IERC20.sol";

//from BoringSolidity - original forced solidity version 0.6.12

contract BoringBatchable {
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    /// @param revertOnFail If True then reverts after a failed call and stops doing further calls.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success && revertOnFail) {
                revert(_getRevertMsg(result));
            }
        }
    }

    function batchRevertOnFailure(bytes[] calldata calls) external payable {
        //copy-pasted to save on copying arguments from calldata to memory (in a public function)
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success) {
                revert(_getRevertMsg(result));
            }
        }
    }
}

contract BoringBatchableWithPermit is BoringBatchable {
    /// @notice Call wrapper that performs `ERC20.permit` on `token`.
    /// Lookup `IERC20.permit`.
    // F6: Parameters can be used front-run the permit and the user's permit will fail (due to nonce or other revert)
    //     if part of a batch this could be used to grief once as the second call would not need the permit
    function batchPermitToken(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        token.permit(from, to, amount, deadline, v, r, s);
    }
}