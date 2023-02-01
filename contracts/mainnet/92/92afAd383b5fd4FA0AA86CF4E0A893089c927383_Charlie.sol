// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

/// @dev Core dependencies.
import {CharlieHelpers} from "./CharlieHelpers.sol";

/**
 * @title Charlie
 * @dev This is a contract that serves as a call aggregator for Charlie, the governance aggregator.
 *      To do so, this contract does not implement any logic, and simply has authority checks and
 *      forwards calls to the target.
 * @notice To keep everything in one contract, available there is support for reads and writes.
 *         Because reads are free, and could be done anywhere, there is no limit on who can call
 *         a read. However, writes are limited to users that meet the authority requirements.
 */
contract Charlie is CharlieHelpers {
    /// @dev Load the backend of Charlie.
    constructor(address _authority) CharlieHelpers(_authority) {}

    /**
     * @dev Primary controller function of Charlie that allows users to bundle
     *      multiple calls into a single transaction. The caller can choose to
     *      block on a failed call, or continue on.
     * @param _calls The calls to make.
     * @param _blocking Whether or not to block on a failed call.
     * @return responses The responses from the calls.
     */
    function aggregate(
        Call[] calldata _calls,
        bool _blocking
    ) external payable requiresAuth returns (Response[] memory responses) {
        /// @dev The amount of ETH sent must be equal to the value of the calls.
        uint256 sum;
        
        /// @dev Instantiate the array used to store whether it was a success,
        ///      the block number, and the result.
        responses = new Response[](_calls.length);

        /// @dev Load the for loop counter.
        uint256 i;

        /// @dev Loop through the calls and make them.
        for (i; i < _calls.length; i++) {
            /// @dev Add the value of the call to the sum.
            sum += _calls[i].value;

            /// @dev Make the call and store the response.
            (bool success, bytes memory result) = _calls[i].target.call{
                value: _calls[i].value
            }(_calls[i].callData);

            /// @dev If the call was not successful and is blocking, revert.
            require(
                success || !_blocking,
                "Charlie: call failed"
            );

            /// @dev Store the response.
            responses[i] = Response(success, block.number, result);
        }

        /// @dev The amount of ETH sent must be equal to the value of the calls.
        require(msg.value >= sum, "Charlie: invalid ETH sent");

        /// @dev If there is ETH left over, send it back.
        if (msg.value > sum) {
            payable(msg.sender).transfer(msg.value - sum);
        }

        /// @dev Announce the use of Charlie.
        emit CharlieCalled(msg.sender, responses);
    }
}

// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

/// @dev Core dependencies.
import {Auth, Authority} from "solmate/src/auth/Auth.sol";

contract CharlieHelpers is Auth {
    /// @dev The shape of the call.
    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    /// @dev The shape of the response.
    struct Response {
        bool success;
        uint256 blockNumber;
        bytes result;
    }

    /// @dev Event used to track when a user calls a function.
    event CharlieCalled(address indexed caller, Response[] results);

    /// @dev Instantiate the ownership of Charlie.
    constructor(address _authority) Auth(msg.sender, Authority(_authority)) {}

    /**
     * @dev Get the balance of an address.
     * @param addr The address to get the balance of.
     * @return balance The balance of the address.
     */
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    /**
     * @dev Get the block hash of a block.
     * @param blockNumber The block number to get the hash of.
     * @return blockHash The block hash of the block.
     */
    function getBlockHash(uint256 blockNumber)
        public
        view
        returns (bytes32 blockHash)
    {
        blockHash = blockhash(blockNumber);
    }

    /**
     * @dev Get the block hash of the last block.
     * @return blockHash The block hash of the last block.
     */
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        blockHash = blockhash(block.number - 1);
    }

    /**
     * @dev Get the timestamp the chain is running on.
     * @return timestamp The timestamp the chain is running on.
     */
    function getCurrentBlockTimestamp()
        public
        view
        returns (uint256 timestamp)
    {
        timestamp = block.timestamp;
    }

    /**
     * @dev Get the difficulty of the current block.
     * @return difficulty The difficulty of the current block.
     */
    function getCurrentBlockDifficulty()
        public
        view
        returns (uint256 difficulty)
    {
        difficulty = block.difficulty;
    }

    /**
     * @dev Get the gas limit of the current block.
     * @return gaslimit The gas limit of the current block.
     */
    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }

    /**
     * @dev Get the coinbase of the current block.
     * @return coinbase The coinbase of the current block.
     */
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
    event OwnerUpdated(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnerUpdated(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

        // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
        // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));

        authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function setOwner(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool);
}