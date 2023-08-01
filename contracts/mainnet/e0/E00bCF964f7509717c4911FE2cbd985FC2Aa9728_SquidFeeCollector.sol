// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// General interface for upgradable contracts
interface IUpgradable {
    error NotOwner();
    error InvalidOwner();
    error InvalidCodeHash();
    error InvalidImplementation();
    error SetupFailed();
    error NotProxy();

    event Upgraded(address indexed newImplementation);
    event OwnershipTransferred(address indexed newOwner);

    // Get current owner
    function owner() external view returns (address);

    function contractId() external pure returns (bytes32);

    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata params
    ) external;

    function setup(bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../interfaces/IUpgradable.sol';

abstract contract Upgradable is IUpgradable {
    // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // keccak256('owner')
    bytes32 internal constant _OWNER_SLOT = 0x02016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040c0;

    modifier onlyOwner() {
        if (owner() != msg.sender) revert NotOwner();
        _;
    }

    function owner() public view returns (address owner_) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            owner_ := sload(_OWNER_SLOT)
        }
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();

        emit OwnershipTransferred(newOwner);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(_OWNER_SLOT, newOwner)
        }
    }

    function implementation() public view returns (address implementation_) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            implementation_ := sload(_IMPLEMENTATION_SLOT)
        }
    }

    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata params
    ) external override onlyOwner {
        if (IUpgradable(newImplementation).contractId() != IUpgradable(this).contractId())
            revert InvalidImplementation();
        if (newImplementationCodeHash != newImplementation.codehash) revert InvalidCodeHash();

        if (params.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = newImplementation.delegatecall(abi.encodeWithSelector(this.setup.selector, params));

            if (!success) revert SetupFailed();
        }

        emit Upgraded(newImplementation);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    function setup(bytes calldata data) external override {
        // Prevent setup from being called on the implementation
        if (implementation() == address(0)) revert NotProxy();

        _setup(data);
    }

    // solhint-disable-next-line no-empty-blocks
    function _setup(bytes calldata data) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISquidFeeCollector {
    event FeeCollected(address token, address integrator, uint256 squidFee, uint256 integratorFee);
    event FeeWithdrawn(address token, address account, uint256 amount);

    error TransferFailed();
    error ExcessiveIntegratorFee();

    function collectFee(address token, uint256 amountToTax, address integratorAddress, uint256 integratorFee) external;

    function withdrawFee(address token) external;

    function getBalance(address token, address account) external view returns (uint256 accountBalance);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Upgradable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/upgradables/Upgradable.sol";
import {ISquidFeeCollector} from "../interfaces/ISquidFeeCollector.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SquidFeeCollector is ISquidFeeCollector, Upgradable {
    bytes32 private constant BALANCES_PREFIX = keccak256("SquidFeeCollector.balances");
    bytes32 private constant SPECIFIC_FEES_PREFIX = keccak256("SquidFeeCollector.specificFees");
    address public immutable squidTeam;
    // Value expected with 2 decimals
    /// eg. 825 is 8.25%
    uint256 public immutable squidDefaultFee;

    error ZeroAddressProvided();

    constructor(address _squidTeam, uint256 _squidDefaultFee) {
        if (_squidTeam == address(0)) revert ZeroAddressProvided();

        squidTeam = _squidTeam;
        squidDefaultFee = _squidDefaultFee;
    }

    /// @param integratorFee Value expected with 2 decimals
    /// eg. 825 is 8.25%
    function collectFee(address token, uint256 amountToTax, address integratorAddress, uint256 integratorFee) external {
        if (integratorFee > 1000) revert ExcessiveIntegratorFee();

        uint256 specificFee = getSpecificFee(integratorAddress);
        uint256 squidFee = specificFee == 0 ? squidDefaultFee : specificFee;

        uint256 baseFeeAmount = (amountToTax * integratorFee) / 10000;
        uint256 squidFeeAmount = (baseFeeAmount * squidFee) / 10000;
        uint256 integratorFeeAmount = baseFeeAmount - squidFeeAmount;

        _safeTransferFrom(token, msg.sender, baseFeeAmount);
        _setBalance(token, squidTeam, getBalance(token, squidTeam) + squidFeeAmount);
        _setBalance(token, integratorAddress, getBalance(token, integratorAddress) + integratorFeeAmount);

        emit FeeCollected(token, integratorAddress, squidFeeAmount, integratorFeeAmount);
    }

    function withdrawFee(address token) external {
        uint256 balance = getBalance(token, msg.sender);
        _setBalance(token, msg.sender, 0);
        _safeTransfer(token, msg.sender, balance);

        emit FeeWithdrawn(token, msg.sender, balance);
    }

    function setSpecificFee(address integrator, uint256 fee) external onlyOwner {
        bytes32 slot = _computeSpecificFeeSlot(integrator);
        assembly {
            sstore(slot, fee)
        }
    }

    function getBalance(address token, address account) public view returns (uint256 value) {
        bytes32 slot = _computeBalanceSlot(token, account);
        assembly {
            value := sload(slot)
        }
    }

    function getSpecificFee(address integrator) public view returns (uint256 value) {
        bytes32 slot = _computeSpecificFeeSlot(integrator);
        assembly {
            value := sload(slot)
        }
    }

    function contractId() external pure returns (bytes32 id) {
        id = keccak256("squid-fee-collector");
    }

    function _setBalance(address token, address account, uint256 amount) private {
        bytes32 slot = _computeBalanceSlot(token, account);
        assembly {
            sstore(slot, amount)
        }
    }

    function _computeBalanceSlot(address token, address account) private pure returns (bytes32 slot) {
        slot = keccak256(abi.encodePacked(BALANCES_PREFIX, token, account));
    }

    function _computeSpecificFeeSlot(address integrator) private pure returns (bytes32 slot) {
        slot = keccak256(abi.encodePacked(SPECIFIC_FEES_PREFIX, integrator));
    }

    function _safeTransferFrom(address token, address from, uint256 amount) internal {
        (bool success, bytes memory returnData) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), amount)
        );
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));
        if (!transferred || token.code.length == 0) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory returnData) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));
        if (!transferred || token.code.length == 0) revert TransferFailed();
    }
}