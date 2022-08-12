// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "./RocketOvmPriceOracle.sol";
import "./interfaces/balancer/IRateProvider.sol";

/// @author Kane Wallmann (Rocket Pool)
/// @notice Implements Balancer's IRateProvider interface
contract RocketBalancerRateProvider is IRateProvider {
    RocketOvmPriceOracle immutable oracle;

    constructor(RocketOvmPriceOracle _oracle) {
        oracle = _oracle;
    }

    function getRate() external override view returns (uint256) {
        return oracle.rate();
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

interface IRateProvider {
    function getRate() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

/// @author Kane Wallmann (Rocket Pool)
/// @notice Receives updates from L1 on the canonical rETH exchange rate
contract RocketOvmPriceOracle {
    // Events
    event RateUpdated(uint256 rate);

    // Immutables
    ICrossDomainMessenger immutable ovmL2CrossDomainMessenger;

    /// @notice The rETH exchange rate in the form of how much ETH 1 rETH is worth
    uint256 public rate;

    /// @notice The timestamp of the block in which the rate was last updated
    uint256 public lastUpdated;

    /// @notice Set to the contract on L1 that has permission to update the rate
    address public owner;

    constructor(address _l2CrossDomainMessenger) {
        ovmL2CrossDomainMessenger = ICrossDomainMessenger(_l2CrossDomainMessenger);
        owner = msg.sender;
    }

    /// @notice Hands ownership to the L1 price messenger contract
    function setOwner(address _newOwner) external {
        require(msg.sender == owner, "Only owner");
        owner = _newOwner;
    }

    /// @notice Called by the messenger contract on L1 to update the exchange rate
    function updateRate(uint256 _newRate) external {
        // Only calls originating from L1 owner can update the rate
        require(
            msg.sender == address(ovmL2CrossDomainMessenger)
            && ovmL2CrossDomainMessenger.xDomainMessageSender() == owner,
            "Only owner"
        );
        // Set rate and last updated timestamp
        rate = _newRate;
        lastUpdated = block.timestamp;
        // Emit event
        emit RateUpdated(_newRate);
    }
}

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