// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ExcessivelySafeCall} from "ExcessivelySafeCall/ExcessivelySafeCall.sol";
import {IOptimismL1ProxyEvents} from "src/interfaces/IOptimismL1ProxyEvents.sol";
import {ICrossDomainMessenger} from "src/interfaces/ICrossDomainMessenger.sol";

/**
 * @notice
 * OptimismL1Proxy acts as a proxy for users/contracts to hold assets on the Optimism network
 * and execute arbitrary transactions using these assets on Optimism.
 *
 * Only the L1Owner (EOA or contract) address can perform write operations using this contract.
 *
 * Ownership is based off of how the the OZ Ownable2Step contract works,
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol
 * however there is no option to renounce ownership (transfer to the zero address).
 *
 */
contract OptimismL1Proxy is IOptimismL1ProxyEvents {
  using ExcessivelySafeCall for address;

  // Maximum bytes to copy from the function call return.
  uint16 public maxCopy = 150;

  // Error indicating that the caller of the function is unauthorized.
  error UnauthorizedCaller();

  /* ---- Storage Variables ---- */

  /// @dev The cross domain messenger for this proxy.
  ICrossDomainMessenger public immutable messenger;

  /// @dev The L1 Address that owns this proxy.
  address public l1OwnerAddress;

  /// @dev The pendinding L1 Address that will own this proxy, if there is one.
  /// Returns address(0) if none exists.
  address public pendingL1OwnerAddress;

  /// @dev Initializes the contract, setting l1OwnerAddress_ as the initial owner.
  constructor(address l1OwnerAddress_, ICrossDomainMessenger messenger_) {
    _transferL1Ownership(l1OwnerAddress_);
    messenger = messenger_;
  }

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /// @notice Authenticates the L1 sending address and executes the function call at the destination.
  ///
  /// @param dst_ The destination address to execute the function call against.
  /// @param msgValue_ The msg.value value. Note If the proxy does not have ETH GTE to this value, the
  /// FunctionCallFailed event is emitted.
  /// @param payload_ The abi encoded payload for the function call.
  function executeFunction(address dst_, uint256 msgValue_, bytes calldata payload_) external onlyAuthenticatedCall {
    // The caller of the function is trusted but we still use excessivelySafeCall to ensure no
    // malicious reverts can happen.
    (bool success, bytes memory ret) = dst_.excessivelySafeCall(gasleft(), msgValue_, maxCopy, payload_);

    if (success) emit FunctionCallSuccess(dst_, ret, payload_);
    else emit FunctionCallFailed(dst_, ret, payload_);
  }

  /// @notice Authenticates the L1 sending address and executes the transfer to the destination.
  ///
  /// @param dst_ The destination address to transfer to.
  /// @param value_ The amount of ETH to transfer. Note If the proxy does not have ETH GTE to this value, the
  /// TransferFailed event is emitted.
  function executeTransferEth(address dst_, uint256 value_) external onlyAuthenticatedCall {
    (bool success,) = dst_.excessivelySafeCall(gasleft(), value_, maxCopy, "");

    if (success) emit TransferSuccess(dst_, value_);
    else emit TransferFailed(dst_, value_, address(this).balance);
  }

  function updateMaxCopy(uint16 newMaxCopy_) external onlyAuthenticatedCall {
    emit MaxCopyUpdated(maxCopy, newMaxCopy_);
    maxCopy = newMaxCopy_;
  }

  /* ---- Access Control ---- */

  /// @dev Starts the transfer of the L1 Owner of the proxy to newL1Owner_.
  function transferL1Ownership(address newL1Owner_) external onlyAuthenticatedCall {
    pendingL1OwnerAddress = newL1Owner_;
    emit L1OwnershipTransferStarted(l1OwnerAddress, newL1Owner_);
  }

  /// @dev Called by the pending L1 Owner of the proxy to accept ownership. When a transfer is started,
  /// until this is called, the L1 Owner of this proxy is the previous owner.
  function acceptL1Ownership() external {
    address sender_ = messenger.xDomainMessageSender();
    if (msg.sender != address(messenger) || sender_ != pendingL1OwnerAddress) revert UnauthorizedCaller();
    _transferL1Ownership(sender_);
  }

  modifier onlyAuthenticatedCall() {
    _authenticateCall();
    _;
  }

  /// @dev Reverts with UnauthorizedCaller if called by any other messenger than the cross domain messenger,
  /// and if the `messenger.xDomainMessageSender()` is not the l1OwnerAddress.
  function _authenticateCall() internal view {
    if (msg.sender != address(messenger) || messenger.xDomainMessageSender() != l1OwnerAddress) {
      revert UnauthorizedCaller();
    }
  }

  function _transferL1Ownership(address newL1Owner_) internal {
    delete pendingL1OwnerAddress;
    address oldL1Owner_ = l1OwnerAddress;
    l1OwnerAddress = newL1Owner_;
    emit L1OwnershipTransferred(oldL1Owner_, newL1Owner_);
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.7.6;

library ExcessivelySafeCall {
    uint256 constant LOW_28_MASK =
        0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @notice Use when you _really_ really _really_ don't trust the called
    /// contract. This prevents the called contract from causing reversion of
    /// the caller in as many ways as we can.
    /// @dev The main difference between this and a solidity low-level call is
    /// that we limit the number of bytes that the callee can cause to be
    /// copied to caller memory. This prevents stupid things like malicious
    /// contracts returning 10,000,000 bytes causing a local OOG when copying
    /// to memory.
    /// @param _target The address to call
    /// @param _gas The amount of gas to forward to the remote contract
    /// @param _value The value in wei to send to the remote contract
    /// @param _maxCopy The maximum number of bytes of returndata to copy
    /// to memory.
    /// @param _calldata The data to send to the remote contract
    /// @return success and returndata, as `.call()`. Returndata is capped to
    /// `_maxCopy` bytes.
    function excessivelySafeCall(
        address _target,
        uint256 _gas,
        uint256 _value,
        uint16 _maxCopy,
        bytes memory _calldata
    ) internal returns (bool, bytes memory) {
        // set up for assembly call
        uint256 _toCopy;
        bool _success;
        bytes memory _returnData = new bytes(_maxCopy);
        // dispatch message to recipient
        // by assembly calling "handle" function
        // we call via assembly to avoid memcopying a very large returndata
        // returned by a malicious contract
        assembly {
            _success := call(
                _gas, // gas
                _target, // recipient
                _value, // ether value
                add(_calldata, 0x20), // inloc
                mload(_calldata), // inlen
                0, // outloc
                0 // outlen
            )
            // limit our copy to 256 bytes
            _toCopy := returndatasize()
            if gt(_toCopy, _maxCopy) {
                _toCopy := _maxCopy
            }
            // Store the length of the copied bytes
            mstore(_returnData, _toCopy)
            // copy the bytes from returndata[0:_toCopy]
            returndatacopy(add(_returnData, 0x20), 0, _toCopy)
        }
        return (_success, _returnData);
    }

    /// @notice Use when you _really_ really _really_ don't trust the called
    /// contract. This prevents the called contract from causing reversion of
    /// the caller in as many ways as we can.
    /// @dev The main difference between this and a solidity low-level call is
    /// that we limit the number of bytes that the callee can cause to be
    /// copied to caller memory. This prevents stupid things like malicious
    /// contracts returning 10,000,000 bytes causing a local OOG when copying
    /// to memory.
    /// @param _target The address to call
    /// @param _gas The amount of gas to forward to the remote contract
    /// @param _maxCopy The maximum number of bytes of returndata to copy
    /// to memory.
    /// @param _calldata The data to send to the remote contract
    /// @return success and returndata, as `.call()`. Returndata is capped to
    /// `_maxCopy` bytes.
    function excessivelySafeStaticCall(
        address _target,
        uint256 _gas,
        uint16 _maxCopy,
        bytes memory _calldata
    ) internal view returns (bool, bytes memory) {
        // set up for assembly call
        uint256 _toCopy;
        bool _success;
        bytes memory _returnData = new bytes(_maxCopy);
        // dispatch message to recipient
        // by assembly calling "handle" function
        // we call via assembly to avoid memcopying a very large returndata
        // returned by a malicious contract
        assembly {
            _success := staticcall(
                _gas, // gas
                _target, // recipient
                add(_calldata, 0x20), // inloc
                mload(_calldata), // inlen
                0, // outloc
                0 // outlen
            )
            // limit our copy to 256 bytes
            _toCopy := returndatasize()
            if gt(_toCopy, _maxCopy) {
                _toCopy := _maxCopy
            }
            // Store the length of the copied bytes
            mstore(_returnData, _toCopy)
            // copy the bytes from returndata[0:_toCopy]
            returndatacopy(add(_returnData, 0x20), 0, _toCopy)
        }
        return (_success, _returnData);
    }

    /**
     * @notice Swaps function selectors in encoded contract calls
     * @dev Allows reuse of encoded calldata for functions with identical
     * argument types but different names. It simply swaps out the first 4 bytes
     * for the new selector. This function modifies memory in place, and should
     * only be used with caution.
     * @param _newSelector The new 4-byte selector
     * @param _buf The encoded contract args
     */
    function swapSelector(bytes4 _newSelector, bytes memory _buf)
        internal
        pure
    {
        require(_buf.length >= 4);
        uint256 _mask = LOW_28_MASK;
        assembly {
            // load the first word of
            let _word := mload(add(_buf, 0x20))
            // mask out the top 4 bytes
            // /x
            _word := and(_word, _mask)
            _word := or(_newSelector, _word)
            mstore(add(_buf, 0x20), _word)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IOptimismL1ProxyEvents {
  // Event indicating that the L1 ownership was transferred.
  event L1OwnershipTransferred(address indexed previousL1Owner, address indexed newL1Owner);
  // Event indicating that the L1 ownership has started to transfer.
  event L1OwnershipTransferStarted(address indexed previousL1Owner, address indexed pendingL1Owner);
  // Event indicating that ETH has been received.
  event Received(address indexed from, uint256 amount);
  // Event indicating that the function call was successful.
  event FunctionCallSuccess(address indexed to, bytes result, bytes payload);
  // Event indicating that the function call failed.
  event FunctionCallFailed(address indexed to, bytes reason, bytes payload);
  // Event indicating that the maxCopy has been updated.
  event MaxCopyUpdated(uint16 previousMaxCopy, uint16 newMaxCopy);
  // Event indicating native currency has been transfered.
  event TransferSuccess(address indexed to, uint256 amount);
  // Event indicating native currency transfer has failed.
  event TransferFailed(address indexed to, uint256 amountTransfered, uint256 contractBalance);
}

// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.9.0;

// Taken from
// https://github.com/ethereum-optimism/optimism/blob/master/packages/contracts/contracts/libraries/bridge/ICrossDomainMessenger.sol

/**
 * @title ICrossDomainMessenger
 */
interface ICrossDomainMessenger {
    /**********
     * Events *
     **********/

    event SentMessage(
        address indexed target,
        address sender,
        bytes message,
        uint256 messageNonce,
        uint256 gasLimit
    );
    event RelayedMessage(bytes32 indexed msgHash);
    event FailedRelayedMessage(bytes32 indexed msgHash);

    /*************
     * Variables *
     *************/

    function xDomainMessageSender() external view returns (address);

    /********************
     * Public Functions *
     ********************/

    /**
     * Sends a cross domain message to the target messenger.
     * @param _target Target contract address.
     * @param _message Message to send to the target.
     * @param _gasLimit Gas limit for the provided message.
     */
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}