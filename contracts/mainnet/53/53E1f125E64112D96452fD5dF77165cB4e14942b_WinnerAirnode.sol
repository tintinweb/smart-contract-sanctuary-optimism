// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAuthorizationUtilsV0.sol";
import "./ITemplateUtilsV0.sol";
import "./IWithdrawalUtilsV0.sol";

interface IAirnodeRrpV0 is
    IAuthorizationUtilsV0,
    ITemplateUtilsV0,
    IWithdrawalUtilsV0
{
    event SetSponsorshipStatus(
        address indexed sponsor,
        address indexed requester,
        bool sponsorshipStatus
    );

    event MadeTemplateRequest(
        address indexed airnode,
        bytes32 indexed requestId,
        uint256 requesterRequestCount,
        uint256 chainId,
        address requester,
        bytes32 templateId,
        address sponsor,
        address sponsorWallet,
        address fulfillAddress,
        bytes4 fulfillFunctionId,
        bytes parameters
    );

    event MadeFullRequest(
        address indexed airnode,
        bytes32 indexed requestId,
        uint256 requesterRequestCount,
        uint256 chainId,
        address requester,
        bytes32 endpointId,
        address sponsor,
        address sponsorWallet,
        address fulfillAddress,
        bytes4 fulfillFunctionId,
        bytes parameters
    );

    event FulfilledRequest(
        address indexed airnode,
        bytes32 indexed requestId,
        bytes data
    );

    event FailedRequest(
        address indexed airnode,
        bytes32 indexed requestId,
        string errorMessage
    );

    function setSponsorshipStatus(address requester, bool sponsorshipStatus)
        external;

    function makeTemplateRequest(
        bytes32 templateId,
        address sponsor,
        address sponsorWallet,
        address fulfillAddress,
        bytes4 fulfillFunctionId,
        bytes calldata parameters
    ) external returns (bytes32 requestId);

    function makeFullRequest(
        address airnode,
        bytes32 endpointId,
        address sponsor,
        address sponsorWallet,
        address fulfillAddress,
        bytes4 fulfillFunctionId,
        bytes calldata parameters
    ) external returns (bytes32 requestId);

    function fulfill(
        bytes32 requestId,
        address airnode,
        address fulfillAddress,
        bytes4 fulfillFunctionId,
        bytes calldata data,
        bytes calldata signature
    ) external returns (bool callSuccess, bytes memory callData);

    function fail(
        bytes32 requestId,
        address airnode,
        address fulfillAddress,
        bytes4 fulfillFunctionId,
        string calldata errorMessage
    ) external;

    function sponsorToRequesterToSponsorshipStatus(
        address sponsor,
        address requester
    ) external view returns (bool sponsorshipStatus);

    function requesterToRequestCountPlusOne(address requester)
        external
        view
        returns (uint256 requestCountPlusOne);

    function requestIsAwaitingFulfillment(bytes32 requestId)
        external
        view
        returns (bool isAwaitingFulfillment);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAuthorizationUtilsV0 {
    function checkAuthorizationStatus(
        address[] calldata authorizers,
        address airnode,
        bytes32 requestId,
        bytes32 endpointId,
        address sponsor,
        address requester
    ) external view returns (bool status);

    function checkAuthorizationStatuses(
        address[] calldata authorizers,
        address airnode,
        bytes32[] calldata requestIds,
        bytes32[] calldata endpointIds,
        address[] calldata sponsors,
        address[] calldata requesters
    ) external view returns (bool[] memory statuses);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITemplateUtilsV0 {
    event CreatedTemplate(
        bytes32 indexed templateId,
        address airnode,
        bytes32 endpointId,
        bytes parameters
    );

    function createTemplate(
        address airnode,
        bytes32 endpointId,
        bytes calldata parameters
    ) external returns (bytes32 templateId);

    function getTemplates(bytes32[] calldata templateIds)
        external
        view
        returns (
            address[] memory airnodes,
            bytes32[] memory endpointIds,
            bytes[] memory parameters
        );

    function templates(bytes32 templateId)
        external
        view
        returns (
            address airnode,
            bytes32 endpointId,
            bytes memory parameters
        );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWithdrawalUtilsV0 {
    event RequestedWithdrawal(
        address indexed airnode,
        address indexed sponsor,
        bytes32 indexed withdrawalRequestId,
        address sponsorWallet
    );

    event FulfilledWithdrawal(
        address indexed airnode,
        address indexed sponsor,
        bytes32 indexed withdrawalRequestId,
        address sponsorWallet,
        uint256 amount
    );

    function requestWithdrawal(address airnode, address sponsorWallet) external;

    function fulfillWithdrawal(
        bytes32 withdrawalRequestId,
        address airnode,
        address sponsor
    ) external payable;

    function sponsorToWithdrawalRequestCount(address sponsor)
        external
        view
        returns (uint256 withdrawalRequestCount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAirnodeRrpV0.sol";

/// @title The contract to be inherited to make Airnode RRP requests
contract RrpRequesterV0 {
    IAirnodeRrpV0 public immutable airnodeRrp;

    /// @dev Reverts if the caller is not the Airnode RRP contract.
    /// Use it as a modifier for fulfill and error callback methods, but also
    /// check `requestId`.
    modifier onlyAirnodeRrp() {
        require(msg.sender == address(airnodeRrp), "Caller not Airnode RRP");
        _;
    }

    /// @dev Airnode RRP address is set at deployment and is immutable.
    /// RrpRequester is made its own sponsor by default. RrpRequester can also
    /// be sponsored by others and use these sponsorships while making
    /// requests, i.e., using this default sponsorship is optional.
    /// @param _airnodeRrp Airnode RRP contract address
    constructor(address _airnodeRrp) {
        airnodeRrp = IAirnodeRrpV0(_airnodeRrp);
        IAirnodeRrpV0(_airnodeRrp).setSponsorshipStatus(address(this), true);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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

pragma solidity ^0.8.15;

// Package imports
import { DataTypes } from "../../libraries/DataTypes.sol";
import { Events } from "../../libraries/Events.sol";
import { Errors } from "../../libraries/Errors.sol";
// Third party imports
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AirnodeLogic
 * @author API3 Latam
 *
 * @notice This is an abstract contract to be inherited by the modules
 * which are going to make use of an Airnode.
 */
abstract contract AirnodeLogic is 
    RrpRequesterV0,
    Ownable
{
    // ========== Storage ==========
    address public airnode;           // The address of the airnode being use.
    address internal derivedAddress;  // The derived address to be sponsored.
    address internal sponsorAddress;  // The sponsored wallet address that will pay for fulfillments.
    
    DataTypes.Endpoint[] public endpointsIds; // The storage for endpoints data.
    
    // ========== Mappings ==========
    // The mapping of functions to their index in the array.
    mapping(bytes4 => uint256) public callbackToIndex;
    // The list of ongoing fulfillments.
    mapping(bytes32 => bool) internal incomingFulfillments;
    
    // ========== Modifiers ==========
    /**
     * @notice Validates if the given requestId exists.
     * @dev Is up to each requester how to deal with edge cases
     * of missing requests.
     *
     * @param _requestId The requestId being used.
     */
    modifier validRequest (
        bytes32 _requestId
    ) {
        if (
            incomingFulfillments[_requestId] == false
        ) revert Errors.RequestIdNotKnown();
        _;
    }

    /**
     * @notice Validates whether the given requestId has been fulfilled.
     *
     * @param _requestId The requestId being used.
     */
    modifier requestFulfilled (
        bytes32 _requestId
    ) {
        if (
            incomingFulfillments[_requestId] == true
        ) revert Errors.RequestNotFulfilled();
        _;
    }

    // ========== Constructor ==========
    /**
     * @notice Constructor function for AirnodeLogic contract.
     *
     * @param _airnodeRrp The RRP contract address for the network being deploy. 
     */
    constructor (
        address _airnodeRrp
    ) RrpRequesterV0 (
        _airnodeRrp
    ) {}

    // ========== Get/Set Functions ==========
    /** 
     * @notice Sets parameters used in requesting the Airnode protocol.
     *
     * @param _airnode - The address for the airnode.
     * @param _derivedAddress - The derived address to sponsor.
     * @param _sponsorAddress - The actual sponsorer address.
     */
    function setRequestParameters (
        address _airnode,
        address _derivedAddress,
        address _sponsorAddress
    ) external onlyOwner {
        // Check if the given addresses are valid.
        if (
            _airnode == address(0) ||
            _derivedAddress == address(0) ||
            _sponsorAddress == address(0)
        ) revert Errors.ZeroAddress();

        // Set the airnode parameters.
        airnode = _airnode;
        derivedAddress = _derivedAddress;
        sponsorAddress = _sponsorAddress;
        
        // Emit the event.
        emit Events.SetRequestParameters(
            _airnode,
            _derivedAddress,
            _sponsorAddress,
            block.timestamp
        );
    }

    /**
     * @notice Function to add new endpoints to the `endpointsIds` array.
     *
     * @param _endpointId - The identifier for the airnode endpoint.
     * @param _endpointFunction - The function selector to point the callback to.
     */
    function addNewEndpoint (
        bytes32 _endpointId,
        string memory _endpointFunction
    ) external onlyOwner {
        // Calculate the function selector from the given string.
        bytes4 _endpointSelector =  bytes4(
            keccak256(
                bytes(
                    _endpointFunction
                )
            )
        );

        // Check if the endpoint already exists.
        if (callbackToIndex[_endpointSelector] != 0) {
            revert Errors.EndpointAlreadyExists();
        }

        // Push the new endpoint to the array.
        endpointsIds.push(DataTypes.Endpoint(
            _endpointId,
            _endpointSelector
        ));
        callbackToIndex[_endpointSelector] = endpointsIds.length - 1;

        // Emit the event.
        emit Events.SetAirnodeEndpoint(
            endpointsIds.length - 1,
            _endpointId,
            _endpointFunction,
            _endpointSelector
        );
    }

    /**
     * @notice Function to get the fulfillment status from a request.
     *
     * @param _requestId The id of the desired request.
     *
     * @return _notFulfilled Boolean True if is yet to be fulfilled 
     *  or False if does not exists or is already fulfilled.
     */
    function getIncomingFulfillments (
        bytes32 _requestId
    ) external view onlyOwner returns (
        bool _notFulfilled
    ) {
        return incomingFulfillments[_requestId];
    }

    // ========== Utilities Functions ==========
    /**
     * @notice Function to request the balance from requester.
     * @dev In case the requester contract is set as a sponsor.
     */
    function withdraw()
     external onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);

        emit Events.Withdraw(
            address(this),
            msg.sender,
            balance
        );
    }

    /**
     * @notice Checks wether and endpoint exists and
     * if it corresponds with the registered index.
     * @dev This function should be called before any callback.
     * You should manually add them to the specific airnode defined callbacks.
     *
     * @param _selector The function selector to look for.
     */
    function _beforeFullfilment (
        bytes4 _selector
    ) internal virtual returns (
        DataTypes.Endpoint memory
    ) {
        uint256 endpointIdIndex = callbackToIndex[_selector];
        
        // Validate if endpoint exists.
        if (
            endpointIdIndex == 0
            && endpointsIds.length == 0
        ) {
            revert Errors.NoEndpointAdded();
        }

        DataTypes.Endpoint memory _currentEndpoint = endpointsIds[endpointIdIndex];

        // Validate endpoint data.
        if (
            _currentEndpoint.endpointId == bytes32(0)
        ) revert Errors.InvalidEndpointId();

        if (
            _currentEndpoint.functionSelector != _selector
        ) revert Errors.IncorrectCallback();

        return _currentEndpoint;
    }

    /**
     * @notice - Updates request status and emit successful request event.
     * @dev This function should be called after any callback.
     * You should manually add them to the specific airnode defined callbacks.
     *
     * @param _requestId - The id of the request for this fulfillment.
     * @param _airnodeAddress - The address from the airnode of this fulfillment.
     */
    function _afterFulfillment (
        bytes32 _requestId,
        address _airnodeAddress
    ) internal virtual {
        // Set the request as fulfilled.
        incomingFulfillments[_requestId] = false;

        // Emit the event.
        emit Events.SuccessfulRequest(
            _requestId,
            _airnodeAddress
        );
    }

    // ========== Core Functions ==========
    /**
     * @notice Boilerplate to implement airnode calls.
     * @dev This function should be overwritten for each specific
     * requester implementation.
     *
     * @param _functionSelector - The target endpoint to use as callback.
     * @param parameters - The data for the API endpoint.
     */
    function callAirnode (
        bytes4 _functionSelector,
        bytes memory parameters
    ) internal virtual returns (
        bytes32
    ) {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { AirnodeLogic } from "../../base/AirnodeLogic.sol";
import { IWinnerAirnode } from "../../../interfaces/IWinnerAirnode.sol";
import { DataTypes } from "../../../libraries/DataTypes.sol";
import { Events } from "../../../libraries/Events.sol";
import { Errors } from "../../../libraries/Errors.sol";

/**
 * @title WinnerAirnode
 * @author API3 Latam
 *
 * @notice This is the contract implementation to pick winners for raffles
 * using the QRNG airnode.
 */
contract WinnerAirnode is 
    AirnodeLogic,
    IWinnerAirnode
{
    // ========== Storage ==========
    // Raffle airnode metadata for each request.
    mapping(bytes32 => DataTypes.WinnerReponse) internal requestToRaffle;

    // ========== Constructor ==========
    constructor (
        address _airnodeRrpAddress
    ) AirnodeLogic (
        _airnodeRrpAddress
    ) {}

    // ========== Get/Set Functions ==========
    /**
     * @dev See { IWinnerAirnode-getRequestToRaffle }.
     */
    function getRequestToRaffle (
        bytes32 requestId
    ) external view override onlyOwner returns (
        DataTypes.WinnerReponse memory _winnerReponse
    ) {
        return requestToRaffle[requestId];
    }

    // ========== Callback Functions ==========
    /**
     * @dev See { IWinnerAirnode-getIndividualWinner }.
     */
    function getIndividualWinner (
        bytes32 requestId,
        bytes calldata data
    ) external virtual override onlyAirnodeRrp validRequest(
        requestId
    ) {
        // Decode airnode results
        uint256 qrngUint256 = abi.decode(data, (uint256));
        // Get winner index
        uint256 winnerIndex = qrngUint256 % requestToRaffle[requestId].totalEntries;

        // Update raffle metadata
        requestToRaffle[requestId].winnerIndexes.push(winnerIndex);

        // Executes after fulfillment hook.
        _afterFulfillment(
            requestId,
            airnode
        );
    }

    /**
     * @dev See { IWinnerAirnode-getMultipleWinners }.
     */
    function getMultipleWinners (
        bytes32 requestId,
        bytes calldata data
    ) external virtual override onlyAirnodeRrp validRequest(
        requestId
    ) {
        DataTypes.WinnerReponse memory raffleData = requestToRaffle[requestId];

        // Decode airnode results.
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));

        // Get winner indexes.
        for (uint256 i; i < raffleData.totalWinners; i++) {
            requestToRaffle[requestId].winnerIndexes.push(
                qrngUint256Array[i] % raffleData.totalEntries
            );
        }

        // Executes after fulfillment hook.
        _afterFulfillment(
            requestId,
            airnode
        );
    }

    // ========== Core Functions ==========
    /**
     * @dev See { AirnodeLogic-callAirnode }.
     */
    function callAirnode (
        bytes4 _functionSelector,
        bytes memory _parameters
    ) internal override returns (
        bytes32
    ) {
        // Executes before fulfillment hook.
        DataTypes.Endpoint memory currentEndpoint = _beforeFullfilment(
            _functionSelector
        );

        // Make request to Airnode RRP.
        bytes32 _requestId = airnodeRrp.makeFullRequest(
            airnode,
            currentEndpoint.endpointId,
            sponsorAddress,
            derivedAddress,
            address(this),
            currentEndpoint.functionSelector,
            _parameters
        );

        // Update mappings.
        incomingFulfillments[_requestId] = true;

        return _requestId;
    }

    /**
     * @dev See { IWinnerAirnode-requestWinners }.
     */
    function requestWinners (
        bytes4 callbackSelector,
        uint256 winnerNumbers,
        uint256 participantNumbers
    ) external override returns (
        bytes32
    ) {
        bytes32 requestId;

        // Validate parameters.
        if (
            participantNumbers == 0 || winnerNumbers == 0
        ) revert Errors.InvalidParameter();
        if (
            winnerNumbers > participantNumbers
        ) revert Errors.InvalidWinnerNumber();

        // Make request to Airnode RRP.
        if (
            winnerNumbers == 1
        ) {
            requestId = callAirnode(
                callbackSelector,
                ""
            );
        } else {
            requestId = callAirnode(
                callbackSelector,
                abi.encode(
                    bytes32("1u"),
                    bytes32("size"),
                    winnerNumbers
                )
            );
        }

        // Update request metadata.
        requestToRaffle[requestId].totalEntries = participantNumbers;
        requestToRaffle[requestId].totalWinners = winnerNumbers;

        // Emit event.
        emit Events.NewWinnerRequest(
            requestId,
            airnode
        );

        return requestId;
    }

    /**
     * @dev See { IWinnerAirnode-requestResults }
     */
    function requestResults (
        bytes32 requestId
    ) external override requestFulfilled(
        requestId
    ) returns (
        DataTypes.WinnerReponse memory
    ) {
        DataTypes.WinnerReponse memory result = requestToRaffle[requestId];

        // Validate results.
        if (
            result.isFinished
        ) revert Errors.ResultRetrieved();

        // Update metadata.
        requestToRaffle[requestId].isFinished = true;
        
        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import { DataTypes } from "../libraries/DataTypes.sol";

/**
 * @title IWinnerAirnode
 * @author API3 Latam
 *
 * @notice This is the interface for the Winner Airnode,
 * which is initialized utilized when closing up a raffle.
 */
interface IWinnerAirnode {
    // ========== Get/Set Functions ==========
    /**
     * @notice Function to get the output of a raffle request.
     *
     * @param requestId The request ID of the raffle request.
     *
     * @return _winnerReponse The metadata for the request result.
     */
    function getRequestToRaffle (
        bytes32 requestId
    ) external view returns (
        DataTypes.WinnerReponse memory _winnerReponse
    );

    // ========== Callback Functions ==========
    /**
     * @notice - Callback function when requesting one winner only.
     * @dev - We suggest to set this as endpointId index `1`.
     *
     * @param requestId - The id for this request.
     * @param data - The response from the API send by the airnode.
     */
    function getIndividualWinner (
        bytes32 requestId,
        bytes calldata data
    ) external;

    /**
     * @notice - Callback function when requesting multiple winners.
     * @dev - We suggest to set this as endpointId index `2`.
     *
     * @param requestId - The id for this request.
     * @param data - The response from the API send by the airnode. 
     */
    function getMultipleWinners (
        bytes32 requestId,
        bytes calldata data
    ) external;

    // ========== Core Functions ==========
    /**
     * @notice - The function to call this airnode implementation.
     *
     * @param callbackSelector - The target endpoint to use as callback.
     * @param winnerNumbers - The number of winners to return.
     * @param participantNumbers - The number of participants from the raffle.
     */
    function requestWinners (
        bytes4 callbackSelector,
        uint256 winnerNumbers,
        uint256 participantNumbers
    ) external returns (
        bytes32
    );

    /**
     * @notice Return the results from a given request.
     *
     * @param requestId The request to get results from.
     */
    function requestResults (
        bytes32 requestId
    ) external returns (
        DataTypes.WinnerReponse memory
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title DataTypes
 * @author API3 Latam
 * 
 * @notice A standard library of data types used across the API3 LATAM
 * Quantum Fair Platform.
 */
library DataTypes {
    
    // ========== Enums ==========
    /**
     * @notice An enum containing the different states a raffle can use.
     *
     * @param Unintialized - A raffle is created but yet to be open.
     * @param Canceled - A raffle that is invalidated.
     * @param Open - A raffle where participants can enter.
     * @param Close - A raffle which cannot recieve more participants.
     * @param Finish - A raffle that has been wrapped up.
     */
    enum RaffleStatus {
        Unintialized,
        Canceled,
        Open,
        Close,
        Finish
    }

    /**
     * @notice An enum containing the different tokens that a Vault can hold.
     *
     * @param Native - The native token of the network, eg. ETH or MATIC.
     * @param ERC20 - An ERC20 token.
     * @param ERC721 - An NFT.
     * @param ERC1155 - An ERC1155 token.
     */
    enum TokenType {
        Native,
        ERC20,
        ERC721,
        ERC1155
    }

    // ========== Structs ==========
    /**
     * @notice Structure to efficiently save IPFS hashes.
     * @dev To reconstruct full hash insert `hash_function` and `size` before the
     * the `hash` value. So you have `hash_function` + `size` + `hash`.
     * This gives you a hexadecimal representation of the CIDs. You need to parse
     * it to base58 from hex if you want to use it on a traditional IPFS gateway.
     *
     * @param hash - The hexadecimal representation of the CID payload from the hash.
     * @param hash_function - The hexadecimal representation of multihash identifier.
     * IPFS currently defaults to use `sha2` which equals to `0x12`.
     * @param size - The hexadecimal representation of `hash` bytes size.
     * Expecting value of `32` as default which equals to `0x20`. 
     */
    struct Multihash {
        bytes32 hash;
        uint8 hash_function;
        uint8 size;
    }

    /**
     * @notice Information for Airnode endpoints.
     *
     * @param endpointId - The unique identifier for the endpoint this
     * callbacks points to.
     * @param functionSelector - The function selector for this endpoint
     * callback.
     */
    struct Endpoint {
        bytes32 endpointId;
        bytes4 functionSelector;
    }

    /**
     * @notice Metadata information for WinnerAirnode request flow.
     * @dev This should be consume by used in addition to IndividualRaffle struct
     * to return actual winner addresses.
     *
     * @param totalEntries - The number of participants for this raffle.
     * @param totalWinners - The number of winners finally set for this raffle.
     * @param winnerIndexes - The indexes for the winners from raffle entries.
     * @param isFinished - Indicates wether the result has been retrieved or not.
     */
    struct WinnerReponse {
        uint256 totalEntries;
        uint256 totalWinners;
        uint256[] winnerIndexes;
        bool isFinished;
    }

    /**
     * @notice Structure to keep track of tokens kept in vaults.
     * @dev Some fields could be ignored depending on the type of token.
     * Eg. tokenId is of no use for ERC20 tokens.
     */
    struct TokenInventory {
        address tokenAddress;
        uint256 tokenId;
        uint256 tokenAmount;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title Errors
 * @author API3 Latam
 * 
 * @notice A standard library of error types used across the API3 LATAM
 * Quantum Fair Platform.
 */
library Errors {

    // ========== Core Errors ==========
    error SameValueProvided ();
    error AlreadyInitialized ();
    error InvalidProxyAddress (
        address _proxy
    );
    error ZeroAddress ();
    error WrongInitializationParams (
        string errorMessage
    );
    error InvalidParameter ();
    error InvalidAddress ();
    error InvalidAmount ();
    error ParameterNotSet ();
    error InvalidArrayLength ();
    error InsufficientBalance();
    error ParameterAlreadySet ();
    error RaffleDue ();                 // Raffle
    error RaffleNotOpen ();             // Raffle
    error RaffleNotAvailable ();        // Raffle
    error RaffleNotClose ();            // Raffle
    error RaffleAlreadyOpen ();         // Raffle
    error TicketPaymentFailed ();       // Raffle
    error EarlyClosing ();              // Raffle

    // ========== Base Errors ==========
    error CallerNotOwner (               // Ownable ERC721
        address caller
    );
    error RequestIdNotKnown ();          // AirnodeLogic
    error NoEndpointAdded ();            // AirnodeLogic
    error InvalidEndpointId ();          // AirnodeLogic
    error IncorrectCallback ();          // AirnodeLogic
    error RequestNotFulfilled ();        // AirnodeLogic
    error EndpointAlreadyExists ();    // AirnodeLogic
    error InvalidInterface ();           // ERC1820Registry
    error InvalidKey ();                 // EternalStorage
    error ValueAlreadyExists ();         // EternalStorage

    // ========== Airnode Module Errors ==========
    error InvalidWinnerNumber ();        // WinnerAirnode
    error ResultRetrieved ();            // WinnerAirnode

    // ========== Vault Module Errors ==========
    error VaultWithdrawsDisabled ();     // AssetVault
    error VaultWithdrawsEnabled ();      // AssetVault
    error TokenIdOutOfBounds (           // VaultFactory
        uint256 tokenId
    );
    error NoTransferWithdrawEnabled (    // VaultFactory
        uint256 tokenId
    );
    error BatchLengthMismatch();         // VaultDepositRouter
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { DataTypes } from "./DataTypes.sol";

/**
 * @title Events
 * @author API3 Latam
 * 
 * @notice A standard library of Events used across the API3 LATAM
 * Quantum Fair Platform.
 */
library Events {
    // ========== Core Events ==========
    /**
     * @dev Emitted when a beneficiaries are added to a Raffle.
     *
     * @param beneficiaries_ The addresses of the beneficiaries.
     * @param shares_ The shares of the beneficiaries.
     * @param raffleId_ The identifier for this specific raffle.
     * @param timestamp_ The timestamp when the beneficiaries were set.
     */
    event SetRaffleBeneficiaries (
        address[] beneficiaries_,
        uint256[] shares_,
        uint256 indexed raffleId_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when a beneficiary is updated.
     *
     * @param beneficiary_ The address of the beneficiary.
     * @param oldShare_ The old share of the beneficiary.
     * @param newShare_ The new share of the beneficiary.
     * @param raffleId_ The identifier for this specific raffle.
     * @param timestamp_ The timestamp when the beneficiary was updated.
     */
    event UpdateRaffleBeneficiary (
        address indexed beneficiary_,
        uint256 oldShare_,
        uint256 newShare_,
        uint256 indexed raffleId_,
        uint256 timestamp_
    );

    /**
     * @dev Emitted when a Raffle is created.
     * 
     * @param _raffleId - The identifier for this specific raffle.
     */
    event RaffleCreated (
        uint256 indexed _raffleId
    );

    /**
     * @dev Emitted when a Raffle is opened.
     *
     * @param raffleId_ - The identifier for this specific raffle.
     * @param prizeVaultId_ - The id of the prize vault associated with this raffle.
     * @param ticketVaultId_ - The id of the ticket vault associated with this raffle.
     * @param nftAmount_ - The amount of NFTs to be raffled.
     * @param timestamp_ - The timestamp when the raffle was opened.
     */
    event RaffleOpened (
        uint256 indexed raffleId_,
        uint256 prizeVaultId_,
        uint256 ticketVaultId_,
        uint256 nftAmount_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when someone buys a ticket for a raffle.
     * 
     * @param raffleId_ - The identifier for this specific raffle.
     * @param participant_ - The address of the participant.
     * @param amount_ - The amount of tickets bought.
     * @param timestamp_ - The timestamp when the participant entered the raffle.
     */
    event RaffleEntered (
        uint256 indexed raffleId_,
        address indexed participant_,
        uint256 indexed amount_,
        uint256 timestamp_
    );

    /**
     * @dev Emitted when a Raffle is closed.
     *
     * @param raffleId_ - The identifier for this specific raffle.
     * @param requestId_ - The id for this raffle airnode request.
     * @param timestamp_ - The timestamp when the raffle was closed.
     */
    event RaffleClosed (
        uint256 indexed raffleId_,
        bytes32 requestId_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when the winners are set from the QRNG provided data.
     *
     * @param raffleId_ - The identifier for this specific raffle.
     * @param raffleWinners_ - The winner address list for this raffle.
     * @param ownerCut_ - The amount of tokens to be sent to the owner.
     * @param treasuryCut_ - The amount of tokens to be sent to the treasury.
     * @param timestamp_ - The timestamp when the raffle was finished.
     */
    event RaffleFinished (
        uint256 indexed raffleId_,
        address[] raffleWinners_,
        uint256 ownerCut_,
        uint256 treasuryCut_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when Distributor send native tokens.
     *
     * @param sender_ - The address of the sender.
     * @param total_ - The total amount of tokens sent.
     * @param timestamp_ - The timestamp when the distribution was done.
     */
    event NativeDistributed (
        address indexed sender_,
        uint256 indexed total_,
        uint256 timestamp_
    );

    /**
     * @dev Emitted when Distributor send ERC20 tokens.
     *
     * @param sender_ - The address of the sender.
     * @param token_ - The address of the token being distributed.
     * @param total_ - The total amount of tokens sent.
     * @param timestamp_ - The timestamp when the distribution was done.
     */
    event TokensDistributed (
        address indexed sender_,
        address indexed token_,
        uint256 indexed total_,
        uint256 timestamp_
    );

        // ========== Base Events ==========
    /**
     * @dev Emitted when we set the parameters for the airnode.
     *
     * @param airnodeAddress - The Airnode address being use.
     * @param derivedAddress - The derived address for the airnode-sponsor.
     * @param sponsorAddress - The actual sponsor wallet address.
     * @param timestamp - The timestamp when the parameters were set.
     */
    event SetRequestParameters (
        address airnodeAddress,
        address derivedAddress,
        address sponsorAddress,
        uint256 indexed timestamp
    );

    /**
     * @dev Emitted when a new Endpoint is added to an AirnodeLogic instance.
     *
     * @param _index - The current index for the recently added endpoint in the array.
     * @param _newEndpointId - The given endpointId for the addition.
     * @param _newEndpointSelector - The selector for the given endpoint of this addition.
     */
    event SetAirnodeEndpoint (
        uint256 indexed _index,
        bytes32 indexed _newEndpointId,
        string _endpointFunction,
        bytes4 _newEndpointSelector
    );

    /**
     * @dev Emitted when balance is withdraw from requester.
     *
     * @param _requester - The address of the requester contract.
     * @param _recipient - The address of the recipient.
     * @param _amount - The amount of tokens being transfered.
     */
    event Withdraw (
        address indexed _requester,
        address indexed _recipient,
        uint256 indexed _amount
    );

    // ========== Airnode Module Events ==========
    /**
     * @dev Should be emitted when a request to WinnerAirnode is done.
     *
     * @param requestId - The request id which this event is related to.
     * @param airnodeAddress - The airnode address from which this request was originated.
     */
    event NewWinnerRequest (
        bytes32 indexed requestId,
        address indexed airnodeAddress
    );

    /**
     * @dev Same as `NewRequest` but, emitted at the callback time when
     * a request is successful for flow control.
     *
     * @param requestId - The request id from which this event was emitted.
     * @param airnodeAddress - The airnode address from which this request was originated.
     */
    event SuccessfulRequest (
        bytes32 indexed requestId,
        address indexed airnodeAddress
    );

    // ========== Vault Module Events ==========
    /**
     * @dev Should be emitted when withdrawals are enabled on a vault.
     *
     * @param emitter The address of the vault owner.
     */
    event WithdrawEnabled (
        address emitter
    );
    
    /**
     * @dev Should be emitted when the balance of ERC721s is withdraw
     * from a vault.
     *
     * @param emitter The address of the vault owner.
     * @param recipient The end user to recieve the assets.
     * @param tokenContract The addresses of the assets being transfered.
     * @param tokenId The id of the token being transfered.
     */
    event WithdrawERC721 (
        address indexed emitter,
        address indexed recipient,
        address indexed tokenContract,
        uint256 tokenId
    );

    /**
     * @dev Should be emitted when the balance of ERC20s is withdraw.
     *
     * @param emitter The address of the vault.
     * @param recipient The end user to recieve the assets.
     * @param amount The amount of the token being transfered.
     */
    event WithdrawNative (
        address indexed emitter,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @dev Should be emitted when router deposits native tokens to a vault.
     *
     * @param emitter The address of the sender.
     * @param recipient The address of the vault to recieve the funds.
     * @param amount The amount of the token being transfered.
     */
    event DepositNative (
        address indexed emitter,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @dev Should be emitted when router deposits NFTs to a vault.
     *
     * @param emitter The address of the sender.
     * @param recipient The address of the vault to recieve the funds.
     * @param tokenAddresses The addresses of the ERC721 token(s).
     * @param tokenIds The id of the token(s) being transfered.
     */
    event DepositERC721 (
        address indexed emitter,
        address indexed recipient,
        address[] tokenAddresses,
        uint256[] tokenIds
    );

    /**
     * @dev Should be emitted when factory creates a new vault clone.
     *
     * @param vault The address of the new vault.
     * @param to The new owner of the vault.
     */
    event VaultCreated (
        address vault,
        address to
    );
}