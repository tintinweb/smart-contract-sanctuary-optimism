// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AutomationBase {
  error OnlySimulatedBackend();

  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AutomationBase.sol";
import "./interfaces/AutomationCompatibleInterface.sol";

abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {AutomationCompatible} from "chainlink/AutomationCompatible.sol";
import {Owned} from "solmate/auth/Owned.sol";

import {ISmartYield} from "./external/ISmartYield.sol";

/// @title Smart Yield V2 Term Liquidation
contract SYTermLiquidation is AutomationCompatible, Owned {
  ISmartYield public smartYield;
  address[] providers;

  constructor(ISmartYield _smartYield, address _owner) Owned(_owner) {
    smartYield = _smartYield;
  }

  function checkUpkeep(bytes calldata) external cannotExecute returns (
    bool upkeepNeeded,
    bytes memory performData
  ) {
    address[] memory termsToLiquidate;

    /// iterate through providers and check for terms that can be liquidated
    uint256 totalProviders = providers.length;
    for (uint256 i; i < totalProviders; i++) {
      address provider = providers[i];
      (,,,address activeTerm,,) = smartYield.poolByProvider(provider);
      (,uint256 end,,,,,bool liquidated) = smartYield.getTermInfo(activeTerm);

      /// add term to perfromData if it can be liquidated
      if (block.timestamp > end && !liquidated) {
        termsToLiquidate[termsToLiquidate.length - 1] = activeTerm;
      }
    }

    return (
      termsToLiquidate.length > 0,
      abi.encode(termsToLiquidate)
    );
  }

  function performUpkeep(bytes calldata performData) external {
    address[] memory termsToLiquidate = abi.decode(performData, (address[]));

    /// iterate through each term in performData and liquidate
    uint256 totalTermsToLiquidate = termsToLiquidate.length;
    for (uint256 i; i < totalTermsToLiquidate; i++) {
      address term = termsToLiquidate[i];
      smartYield.liquidateTerm(term);
    }
  }

  function addProvider(address _provider) external onlyOwner {
    providers.push(_provider);
  }

  function removeProvider(address _provider) external onlyOwner {
    uint256 totalProviders = providers.length;
    for (uint256 i; i < totalProviders; i++) {

      if (providers[i] == _provider) {

        /// replace provider with provider at end of list to delete
        address lastProvider = providers[totalProviders - 1];
        providers[i] = lastProvider;
        providers.pop();
      }
    }
  }

  function setSmartYield(ISmartYield _smartYield) external onlyOwner {
    smartYield = _smartYield;
  }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.10;

interface ISmartYield {
  function poolByProvider(address _provider) external returns (
    address underlying,
    uint256 liquidityProviderBalance,
    uint256 withdrawWindow,
    address activeTerm,
    uint256 healthFactorGuard,
    uint256 nextDebtId
  );
  function getTermInfo(address _bond) external view returns (
    uint256 start,
    uint256 end,
    uint256 feeRate,
    address nextTerm,
    address bond,
    uint256 realizedYield,
    bool liquidated
  );
  function liquidateTerm(address _term) external;
}