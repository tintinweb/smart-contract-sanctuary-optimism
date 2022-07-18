/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IPoolConfigurator {
  /**
   * @notice Configures the reserve collateralization parameters.
   * @dev All the values are expressed in bps. A value of 10000, results in 100.00%
   * @dev The `liquidationBonus` is always above 100%. A value of 105% means the liquidator will receive a 5% bonus
   * @param asset The address of the underlying asset of the reserve
   * @param ltv The loan to value of the asset when used as collateral
   * @param liquidationThreshold The threshold at which loans using this asset as collateral will be considered undercollateralized
   * @param liquidationBonus The bonus liquidators receive to liquidate this asset
   **/
  function configureReserveAsCollateral(
    address asset,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus
  ) external;

  /**
   * @notice Sets the interest rate strategy of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newRateStrategyAddress The address of the new interest strategy contract
   **/
  function setReserveInterestRateStrategyAddress(
    address asset,
    address newRateStrategyAddress
  ) external;

  /**
   * @notice Updates the supply cap of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newSupplyCap The new supply cap of the reserve
   **/
  function setSupplyCap(address asset, uint256 newSupplyCap) external;

  /**
   * @notice Updates the liquidation protocol fee of reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newFee The new liquidation protocol fee of the reserve, expressed in bps
   **/
  function setLiquidationProtocolFee(address asset, uint256 newFee) external;
}

library ConfiguratorInputTypes {
  struct InitReserveInput {
    address aTokenImpl;
    address stableDebtTokenImpl;
    address variableDebtTokenImpl;
    uint8 underlyingAssetDecimals;
    address interestRateStrategyAddress;
    address underlyingAsset;
    address treasury;
    address incentivesController;
    string aTokenName;
    string aTokenSymbol;
    string variableDebtTokenName;
    string variableDebtTokenSymbol;
    string stableDebtTokenName;
    string stableDebtTokenSymbol;
    bytes params;
  }

  struct UpdateATokenInput {
    address asset;
    address treasury;
    address incentivesController;
    string name;
    string symbol;
    address implementation;
    bytes params;
  }

  struct UpdateDebtTokenInput {
    address asset;
    address incentivesController;
    string name;
    string symbol;
    address implementation;
    bytes params;
  }
}

/**
 * @title IACLManager
 * @author Aave
 * @notice Defines the basic interface for the ACL Manager
 **/
interface IACLManager {
  /**
   * @dev Revokes `role` from the calling account.
   *
   * Roles are often managed via {grantRole} and {revokeRole}: this function's
   * purpose is to provide a mechanism for accounts to lose their privileges
   * if they are compromised (such as when a trusted device is misplaced).
   *
   * If the calling account had been granted `role`, emits a {RoleRevoked}
   * event.
   *
   * Requirements:
   *
   * - the caller must be `account`.
   */
  function renounceRole(bytes32 role, address account) external;
}

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
  function _msgSender() internal view virtual returns (address payable) {
    return payable(msg.sender);
  }

  function _msgData() internal view virtual returns (bytes memory) {
    this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    return msg.data;
  }
}

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
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _transferOwnership(msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), 'Ownable: caller is not the owner');
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
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            'Ownable: new owner is the zero address'
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
    }
}


abstract contract StewardBase is Ownable {
    modifier withRennounceOfAllAavePermissions(IACLManager aclManager) {
        _;

        bytes32[] memory allRoles = getAllAaveRoles();

        for (uint256 i = 0; i < allRoles.length; i++) {
            aclManager.renounceRole(allRoles[i], address(this));
        }
    }

    modifier withOwnershipBurning() {
        _;
        _transferOwnership(address(0));
    }

    function getAllAaveRoles() public pure returns (bytes32[] memory) {
        bytes32[] memory roles = new bytes32[](6);
        roles[
            0
        ] = 0x19c860a63258efbd0ecb7d55c626237bf5c2044c26c073390b74f0c13c857433; // asset listing
        roles[
            1
        ] = 0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278; // bridge
        roles[
            2
        ] = 0x5c91514091af31f62f596a314af7d5be40146b2f2355969392f055e12e0982fb; // emergency admin
        roles[
            3
        ] = 0x939b8dfb57ecef2aea54a93a15e86768b9d4089f1ba61c245e6ec980695f4ca4; // flash borrower
        roles[
            4
        ] = 0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b; // pool admin
        roles[
            5
        ] = 0x8aa855a911518ecfbe5bc3088c8f3dda7badf130faaf8ace33fdc33828e18167; // risk admin

        return roles;
    }
}

/**
 * @dev One-time-use helper contract to be used by Aave Guardians (Gnosis Safe generally).
 * @dev This Steward enables sUSD as collateral on Aave V3 Optimism, adjusts the supply cap and changes the rate strategy.
 * - The action is approved by the Guardian by just sending the necessary permissions to this contract.
 * - The permissions needed in this case are: risk admin.
 * - The contracts renounces to the permissions after the action.
 * - The contract "burns" the ownership after the action.
 * - Parameter snapshot: https://snapshot.org/#/aave.eth/proposal/Qmem5k8zotXSnV2mm3WJXqb8HmBoT8m2URzZCq3X8igHAm
 */
contract AaveV3OptimismEnableCollateralSteward is StewardBase {
    // **************************
    // Asset to change config from (SUSD)
    // **************************

    address public constant SUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address public constant RATE_STRATEGY =
        0xA9F3C3caE095527061e6d270DBE163693e6fda9D;
    uint256 public constant LTV = 6000; // 60%
    uint256 public constant LIQ_THRESHOLD = 7500; // 75%
    uint256 public constant LIQ_BONUS = 10500; // 5%
    uint256 public constant SUPPLY_CAP = 10_000_000; // 10'000'000 sUSD

    function updateSUSDConfig()
        external
        withRennounceOfAllAavePermissions(IACLManager(0xa72636CbcAa8F5FF95B2cc47F3CDEe83F3294a0B))
        withOwnershipBurning
        onlyOwner
    {
        // ------------------------------------------------
        // 1. Configuration of sUSD
        // ------------------------------------------------

        IPoolConfigurator configurator = IPoolConfigurator(0x8145eddDf43f50276641b55bd3AD95944510021E);

        configurator.setSupplyCap(SUSD, SUPPLY_CAP);

        configurator.configureReserveAsCollateral(
            SUSD,
            LTV,
            LIQ_THRESHOLD,
            LIQ_BONUS
        );

        configurator.setReserveInterestRateStrategyAddress(SUSD, RATE_STRATEGY);
    }
}