// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.9.0;

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

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../interfaces/IMessageExecutor.sol";
import "../libraries/MessageLib.sol";

/**
 * @title MessageExecutorOptimism contract
 * @notice The MessageExecutorOptimism contract executes messages from the Ethereum chain.
 *         These messages are sent by the `MessageDispatcherOptimism` contract which lives on the Ethereum chain.
 */
contract MessageExecutorOptimism is IMessageExecutor {
  /* ============ Variables ============ */

  /// @notice Address of the Optimism cross domain messenger on the Optimism chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the dispatcher contract on the Ethereum chain.
  IMessageDispatcher public dispatcher;

  /**
   * @notice Mapping to uniquely identify the messages that were executed
   *         messageId => boolean
   * @dev Ensure that messages cannot be replayed once they have been executed.
   */
  mapping(bytes32 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice MessageExecutorOptimism constructor.
   * @param _crossDomainMessenger Address of the Optimism cross domain messenger on the Optimism chain
   */
  constructor(ICrossDomainMessenger _crossDomainMessenger) {
    require(address(_crossDomainMessenger) != address(0), "Executor/CDM-not-zero-address");
    crossDomainMessenger = _crossDomainMessenger;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc IMessageExecutor
  function executeMessage(
    address _to,
    bytes calldata _data,
    bytes32 _messageId,
    uint256 _fromChainId,
    address _from
  ) external {
    IMessageDispatcher _dispatcher = dispatcher;
    _isAuthorized(_dispatcher);

    bool _executedMessageId = executed[_messageId];
    executed[_messageId] = true;

    MessageLib.executeMessage(_to, _data, _messageId, _fromChainId, _from, _executedMessageId);

    emit MessageIdExecuted(_fromChainId, _messageId);
  }

  /// @inheritdoc IMessageExecutor
  function executeMessageBatch(
    MessageLib.Message[] calldata _messages,
    bytes32 _messageId,
    uint256 _fromChainId,
    address _from
  ) external {
    IMessageDispatcher _dispatcher = dispatcher;
    _isAuthorized(_dispatcher);

    bool _executedMessageId = executed[_messageId];
    executed[_messageId] = true;

    MessageLib.executeMessageBatch(_messages, _messageId, _fromChainId, _from, _executedMessageId);

    emit MessageIdExecuted(_fromChainId, _messageId);
  }

  /**
   * @notice Set dispatcher contract address.
   * @dev Will revert if it has already been set.
   * @param _dispatcher Address of the dispatcher contract on the Ethereum chain
   */
  function setDispatcher(IMessageDispatcher _dispatcher) external {
    require(address(dispatcher) == address(0), "Executor/dispatcher-already-set");
    dispatcher = _dispatcher;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Check if sender is authorized to message `executeMessageBatch`.
   * @param _dispatcher Address of the dispatcher on the Ethereum chain
   */
  function _isAuthorized(IMessageDispatcher _dispatcher) internal view {
    ICrossDomainMessenger _crossDomainMessenger = crossDomainMessenger;

    require(
      msg.sender == address(_crossDomainMessenger) &&
        _crossDomainMessenger.xDomainMessageSender() == address(_dispatcher),
      "Executor/sender-unauthorized"
    );
  }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "../libraries/MessageLib.sol";

/**
 * @title ERC-5164: Cross-Chain Execution Standard
 * @dev See https://eips.ethereum.org/EIPS/eip-5164
 */
interface IMessageDispatcher {
  /**
   * @notice Emitted when a message has successfully been dispatched to the executor chain.
   * @param messageId ID uniquely identifying the message
   * @param from Address that dispatched the message
   * @param toChainId ID of the chain receiving the message
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   */
  event MessageDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    address to,
    bytes data
  );

  /**
   * @notice Emitted when a batch of messages has successfully been dispatched to the executor chain.
   * @param messageId ID uniquely identifying the messages
   * @param from Address that dispatched the messages
   * @param toChainId ID of the chain receiving the messages
   * @param messages Array of Message that was dispatched
   */
  event MessageBatchDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    MessageLib.Message[] messages
  );

  /**
   * @notice Retrieves address of the MessageExecutor contract on the receiving chain.
   * @dev Must revert if `toChainId` is not supported.
   * @param toChainId ID of the chain with which MessageDispatcher is communicating
   * @return address MessageExecutor contract address
   */
  function getMessageExecutorAddress(uint256 toChainId) external returns (address);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./IMessageDispatcher.sol";

import "../libraries/MessageLib.sol";

/**
 * @title MessageExecutor interface
 * @notice MessageExecutor interface of the ERC-5164 standard as defined in the EIP.
 */
interface IMessageExecutor {
  /**
   * @notice Emitted when a message has successfully been executed.
   * @param fromChainId ID of the chain that dispatched the message
   * @param messageId ID uniquely identifying the message that was executed
   */
  event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);

  /**
   * @notice Execute message from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must revert if the message fails.
   * @dev Must emit the `MessageIdExecuted` event once the message has been executed.
   * @param to Address that will receive `data`
   * @param data Data forwarded to address `to`
   * @param messageId ID uniquely identifying the message
   * @param fromChainId ID of the chain that dispatched the message
   * @param from Address of the sender on the origin chain
   */
  function executeMessage(
    address to,
    bytes calldata data,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) external;

  /**
   * @notice Execute a batch messages from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must revert if one of the messages fails.
   * @dev Must emit the `MessageIdExecuted` event once messages have been executed.
   * @param messages Array of messages being executed
   * @param messageId ID uniquely identifying the messages
   * @param fromChainId ID of the chain that dispatched the messages
   * @param from Address of the sender on the origin chain
   */
  function executeMessageBatch(
    MessageLib.Message[] calldata messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) external;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { IMessageExecutor } from "../interfaces/IMessageExecutor.sol";

/**
 * @title MessageLib
 * @notice Library to declare and manipulate Message(s).
 */
library MessageLib {
  /* ============ Structs ============ */

  /**
   * @notice Message data structure
   * @param to Address that will be dispatched on the receiving chain
   * @param data Data that will be sent to the `to` address
   */
  struct Message {
    address to;
    bytes data;
  }

  /* ============ Events ============ */

  /* ============ Custom Errors ============ */

  /**
   * @notice Emitted when a messageId has already been executed.
   * @param messageId ID uniquely identifying the message or message batch that were re-executed
   */
  error MessageIdAlreadyExecuted(bytes32 messageId);

  /**
   * @notice Emitted if a call to a contract fails.
   * @param messageId ID uniquely identifying the message
   * @param errorData Error data returned by the call
   */
  error MessageFailure(bytes32 messageId, bytes errorData);

  /**
   * @notice Emitted if a call to a contract fails inside a batch of messages.
   * @param messageId ID uniquely identifying the batch of messages
   * @param messageIndex Index of the message
   * @param errorData Error data returned by the call
   */
  error MessageBatchFailure(bytes32 messageId, uint256 messageIndex, bytes errorData);

  /* ============ Internal Functions ============ */

  /**
   * @notice Helper to compute messageId.
   * @param nonce Monotonically increased nonce to ensure uniqueness
   * @param from Address that dispatched the message
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   * @return bytes32 ID uniquely identifying the message that was dispatched
   */
  function computeMessageId(
    uint256 nonce,
    address from,
    address to,
    bytes memory data
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(nonce, from, to, data));
  }

  /**
   * @notice Helper to compute messageId for a batch of messages.
   * @param nonce Monotonically increased nonce to ensure uniqueness
   * @param from Address that dispatched the messages
   * @param messages Array of Message dispatched
   * @return bytes32 ID uniquely identifying the message that was dispatched
   */
  function computeMessageBatchId(
    uint256 nonce,
    address from,
    Message[] memory messages
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(nonce, from, messages));
  }

  /**
   * @notice Helper to encode message for execution by the MessageExecutor.
   * @param to Address that will receive the message
   * @param data Data that will be dispatched
   * @param messageId ID uniquely identifying the message being dispatched
   * @param fromChainId ID of the chain that dispatched the message
   * @param from Address that dispatched the message
   */
  function encodeMessage(
    address to,
    bytes memory data,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) internal pure returns (bytes memory) {
    return
      abi.encodeCall(IMessageExecutor.executeMessage, (to, data, messageId, fromChainId, from));
  }

  /**
   * @notice Helper to encode a batch of messages for execution by the MessageExecutor.
   * @param messages Array of Message that will be dispatched
   * @param messageId ID uniquely identifying the batch of messages being dispatched
   * @param fromChainId ID of the chain that dispatched the batch of messages
   * @param from Address that dispatched the batch of messages
   */
  function encodeMessageBatch(
    Message[] memory messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) internal pure returns (bytes memory) {
    return
      abi.encodeCall(
        IMessageExecutor.executeMessageBatch,
        (messages, messageId, fromChainId, from)
      );
  }

  /**
   * @notice Execute message from the origin chain.
   * @dev Will revert if `message` has already been executed.
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   * @param messageId ID uniquely identifying message
   * @param fromChainId ID of the chain that dispatched the `message`
   * @param from Address of the sender on the origin chain
   * @param executedMessageId Whether `message` has already been executed or not
   */
  function executeMessage(
    address to,
    bytes memory data,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    bool executedMessageId
  ) internal {
    if (executedMessageId) {
      revert MessageIdAlreadyExecuted(messageId);
    }

    _requireContract(to);

    (bool _success, bytes memory _returnData) = to.call(
      abi.encodePacked(data, messageId, fromChainId, from)
    );

    if (!_success) {
      revert MessageFailure(messageId, _returnData);
    }
  }

  /**
   * @notice Execute messages from the origin chain.
   * @dev Will revert if `messages` have already been executed.
   * @param messages Array of messages being executed
   * @param messageId Nonce to uniquely identify the messages
   * @param from Address of the sender on the origin chain
   * @param fromChainId ID of the chain that dispatched the `messages`
   * @param executedMessageId Whether `messages` have already been executed or not
   */
  function executeMessageBatch(
    Message[] memory messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    bool executedMessageId
  ) internal {
    if (executedMessageId) {
      revert MessageIdAlreadyExecuted(messageId);
    }

    uint256 _messagesLength = messages.length;

    for (uint256 _messageIndex; _messageIndex < _messagesLength; ) {
      Message memory _message = messages[_messageIndex];
      _requireContract(_message.to);

      (bool _success, bytes memory _returnData) = _message.to.call(
        abi.encodePacked(_message.data, messageId, fromChainId, from)
      );

      if (!_success) {
        revert MessageBatchFailure(messageId, _messageIndex, _returnData);
      }

      unchecked {
        _messageIndex++;
      }
    }
  }

  /**
   * @notice Check that the call is being made to a contract.
   * @param to Address to check
   */
  function _requireContract(address to) internal view {
    require(to.code.length > 0, "MessageLib/no-contract-at-to");
  }
}