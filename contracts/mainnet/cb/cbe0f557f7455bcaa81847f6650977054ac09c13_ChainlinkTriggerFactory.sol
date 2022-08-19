// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "src/interfaces/IChainlinkTriggerFactoryEvents.sol";
import "src/interfaces/IManager.sol";
import "src/ChainlinkTrigger.sol";
import "src/FixedPriceAggregator.sol";

/**
 * @notice Deploys Chainlink triggers that ensure two oracles stay within the given price
 * tolerance. It also supports creating a fixed price oracle to use as the truth oracle, useful
 * for e.g. ensuring stablecoins maintain their peg.
 */
contract ChainlinkTriggerFactory is IChainlinkTriggerFactoryEvents {
  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @notice Maps the triggerConfigId to the number of triggers created with those configs.
  mapping(bytes32 => uint256) public triggerCount;

  // We use a fixed salt because:
  //   (a) FixedPriceAggregators are just static, owner-less contracts,
  //   (b) there are no risks of bad actors taking them over on other chains,
  //   (c) it would be nice to have these aggregators deployed to the same
  //       address on each chain, and
  //   (d) it saves gas.
  // This is just the 32 bytes you get when you keccak256(abi.encode(42)).
  bytes32 internal constant FIXED_PRICE_ORACLE_SALT = 0xbeced09521047d05b8960b7e7bcc1d1292cf3e4b2a6b63f48335cbde5f7545d2;

  /// @param _manager Address of the Cozy protocol manager.
  constructor(IManager _manager) {
    manager = _manager;
  }

  /// @dev Thrown when the truthOracle and trackingOracle prices cannot be directly compared.
  error InvalidOraclePair();

  /// @notice Call this function to deploy a ChainlinkTrigger.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function deployTrigger(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public returns (ChainlinkTrigger _trigger) {
    if (_truthOracle.decimals() != _trackingOracle.decimals()) revert InvalidOraclePair();

    bytes32 _configId = triggerConfigId(
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    uint256 _triggerCount = triggerCount[_configId];
    bytes32 _salt = keccak256(abi.encode(_triggerCount, block.chainid));

    _trigger = new ChainlinkTrigger{salt: _salt}(
      manager,
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    triggerCount[_configId] += 1;

    emit TriggerDeployed(
      address(_trigger),
      _configId,
      address(_truthOracle),
      address(_trackingOracle),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
  }

  /// @notice Call this function to deploy a ChainlinkTrigger with a
  /// FixedPriceAggregator as its truthOracle. This is useful if you were
  /// building a market in which you wanted to track whether or not a stablecoin
  /// asset had become depegged.
  /// @param _price The fixed price, or peg, with which to compare the trackingOracle price.
  /// @param _decimals The number of decimals of the fixed price. This should
  /// match the number of decimals used by the desired _trackingOracle.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _frequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function deployTrigger(
    int256 _price,
    uint8 _decimals,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _frequencyTolerance
  ) public returns (ChainlinkTrigger _trigger) {
    AggregatorV3Interface _truthOracle = deployFixedPriceAggregator(_price, _decimals);

    // For the truth FixedPriceAggregator peg oracle, we use a frequency tolerance of 0 since it should always return
    // block.timestamp as the updatedAt timestamp.
    return deployTrigger(_truthOracle, _trackingOracle, _priceTolerance, 0, _frequencyTolerance);
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger would
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger would
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger would
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  /// @param _triggerCount The zero-indexed ordinal of the trigger with respect to its
  /// configuration, e.g. if this were to be the fifth trigger deployed with
  /// these configs, then _triggerCount should be 4.
  function computeTriggerAddress(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    uint256 _triggerCount
  ) public view returns(address _address) {
    bytes memory _triggerConstructorArgs = abi.encode(
      manager,
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(
      bytes.concat(
        type(ChainlinkTrigger).creationCode,
        _triggerConstructorArgs
      )
    );
    bytes32 _salt = keccak256(abi.encode(_triggerCount, block.chainid));
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for new markets in Sets.
  /// @dev If this function returns the zero address, that means that an
  /// available trigger was not found with the supplied configuration. Use
  /// `deployTrigger` to deploy a new one.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function findAvailableTrigger(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public view returns(address) {

    bytes32 _counterId = triggerConfigId(
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
    uint256 _triggerCount = triggerCount[_counterId];

    for (uint256 i = 0; i < _triggerCount; i++) {
      address _computedAddr = computeTriggerAddress(
        _truthOracle,
        _trackingOracle,
        _priceTolerance,
        _truthFrequencyTolerance,
        _trackingFrequencyTolerance,
        i
      );

      ChainlinkTrigger _trigger = ChainlinkTrigger(_computedAddr);
      if (_trigger.getSetsLength() < _trigger.MAX_SET_LENGTH()) {
        return _computedAddr;
      }
    }

    return address(0); // If none is found, return zero address.
  }

  /// @notice Call this function to determine the identifier of the supplied trigger
  /// configuration. This identifier is used both to track the number of
  /// triggers deployed with this configuration (see `triggerCount`) and is
  /// emitted at the time triggers with that configuration are deployed.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function triggerConfigId(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public view returns (bytes32) {
    bytes memory _triggerConstructorArgs = abi.encode(
      manager,
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
    return keccak256(_triggerConstructorArgs);
  }

  /// @notice Call this function to deploy a FixedPriceAggregator contract,
  /// which behaves like a Chainlink oracle except that it always returns the
  /// same price.
  /// @dev If the specified contract is already deployed, we return it's address
  /// instead of reverting to avoid duplicate aggregators
  /// @param _price The fixed price, in the decimals indicated, returned by the deployed oracle.
  /// @param _decimals The number of decimals of the fixed price.
  function deployFixedPriceAggregator(
    int256 _price, // An int (instead of uint256) because that's what's used by Chainlink.
    uint8 _decimals
  ) public returns (AggregatorV3Interface) {
    address _oracleAddress = computeFixedPriceAggregatorAddress(_price, _decimals);
    if (_oracleAddress.code.length > 0) return AggregatorV3Interface(_oracleAddress);
    return new FixedPriceAggregator{salt: FIXED_PRICE_ORACLE_SALT}(_decimals, _price);
  }

  /// @notice Call this function to compute the address that a
  /// FixedPriceAggregator contract would be deployed to with the provided args.
  /// @param _price The fixed price, in the decimals indicated, returned by the deployed oracle.
  /// @param _decimals The number of decimals of the fixed price.
  function computeFixedPriceAggregatorAddress(
    int256 _price, // An int (instead of uint256) because that's what's used by Chainlink.
    uint8 _decimals
  ) public view returns (address) {
    bytes memory _aggregatorConstructorArgs = abi.encode(_decimals, _price);
    bytes32 _bytecodeHash = keccak256(
      bytes.concat(
        type(FixedPriceAggregator).creationCode,
        _aggregatorConstructorArgs
      )
    );
    bytes32 _data = keccak256(
      bytes.concat(
        bytes1(0xff),
        bytes20(address(this)),
        FIXED_PRICE_ORACLE_SALT,
        _bytecodeHash
      )
    );
    return address(uint160(uint256(_data)));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

interface IChainlinkTriggerFactoryEvents {
  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger Address at which the trigger was deployed.
  /// @param triggerConfigId Unique identifier of the trigger based on its configuration.
  /// @param truthOracle The address of the desired truthOracle for the trigger.
  /// @param trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param priceTolerance The priceTolerance that the deployed trigger will have. See
  /// `ChainlinkTrigger.priceTolerance()` for more information.
  /// @param truthFrequencyTolerance The frequencyTolerance that the deployed trigger will have for the truth oracle. See
  /// `ChainlinkTrigger.truthFrequencyTolerance()` for more information.
  /// @param trackingFrequencyTolerance The frequencyTolerance that the deployed trigger will have for the tracking oracle. See
  /// `ChainlinkTrigger.trackingFrequencyTolerance()` for more information.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed truthOracle,
    address indexed trackingOracle,
    uint256 priceTolerance,
    uint256 truthFrequencyTolerance,
    uint256 trackingFrequencyTolerance
  );
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/interfaces/ICState.sol";
import "src/interfaces/ISet.sol";

/**
 * @dev Interface for interacting with the Cozy protocol Manager. This is not a comprehensive
 * interface, and only contains the methods needed by triggers.
 */
interface IManager is ICState {
  // Information on a given set.
  struct SetData {
    // When a set is created, this is updated to true.
    bool exists;
     // If true, this set can use funds from the backstop.
    bool approved;
    // Earliest timestamp at which finalizeUpdateConfigs can be called to apply config updates queued by updateConfigs.
    uint64 configUpdateTime;
    // Maps from set address to the latest timestamp after configUpdateTime at which finalizeUpdateConfigs can be
    // called to apply config updates queued by updateConfigs. After this timestamp, the queued config updates
    // expire and can no longer be applied.
    uint64 configUpdateDeadline;
  }

  function sets(ISet) view external returns (bool exists, bool approved, uint64 configUpdateTime, uint64 configUpdateDeadline);
  function updateMarketState(ISet set, CState newMarketState) external;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "solmate/utils/FixedPointMathLib.sol";

import "src/abstract/BaseTrigger.sol";
import "src/interfaces/IManager.sol";

/**
 * @notice A trigger contract that takes two addresses: a truth oracle and a tracking oracle.
 * This trigger ensures the two oracles always stay within the given price tolerance; the delta
 * in prices can be equal to but not greater than the price tolerance.
 */
contract ChainlinkTrigger is BaseTrigger {
  using FixedPointMathLib for uint256;

  uint256 internal constant ZOC = 1e4;

  /// @notice The canonical oracle, assumed to be correct.
  AggregatorV3Interface public immutable truthOracle;

  /// @notice The oracle we expect to diverge.
  AggregatorV3Interface public immutable trackingOracle;

  /// @notice The maximum percent delta between oracle prices that is allowed, expressed as a zoc.
  /// For example, a 0.2e4 priceTolerance would mean the trackingOracle price is
  /// allowed to deviate from the truthOracle price by up to +/- 20%, but no more.
  /// Note that if the truthOracle returns a price of 0, we treat the priceTolerance
  /// as having been exceeded, no matter what price the trackingOracle returns.
  uint256 public immutable priceTolerance;

  /// @notice The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
  uint256 public immutable truthFrequencyTolerance;

  /// @notice The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
  uint256 public immutable trackingFrequencyTolerance;

  /// @dev Thrown when the `oracle`s price is negative.
  error InvalidPrice();

  /// @dev Thrown when the `oracle`s price timestamp is greater than the block's timestamp.
  error InvalidTimestamp();

  /// @dev Thrown when the `oracle`s last update is more than `frequencyTolerance` seconds ago.
  error StaleOraclePrice();

  /// @param _manager Address of the Cozy protocol manager.
  /// @param _truthOracle The canonical oracle, assumed to be correct.
  /// @param _trackingOracle The oracle we expect to diverge.
  /// @param _priceTolerance The maximum percent delta between oracle prices that is allowed, as a wad.
  /// @param _truthFrequencyTolerance The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
  /// @param _trackingFrequencyTolerance The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
  constructor(
    IManager _manager,
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) BaseTrigger(_manager) {
    truthOracle = _truthOracle;
    trackingOracle = _trackingOracle;
    priceTolerance = _priceTolerance;
    truthFrequencyTolerance = _truthFrequencyTolerance;
    trackingFrequencyTolerance = _trackingFrequencyTolerance;
    runProgrammaticCheck();
  }

  /// @notice Compares the oracle's price to the reference oracle and toggles the trigger if required.
  /// @dev This method executes the `programmaticCheck()` and makes the
  /// required state changes both in the trigger and the sets.
  function runProgrammaticCheck() public returns (CState) {
    // Rather than revert if not active, we simply return the state and exit.
    // Both behaviors are acceptable, but returning is friendlier to the caller
    // as they don't need to handle a revert and can simply parse the
    // transaction's logs to know if the call resulted in a state change.
    if (state != CState.ACTIVE) return state;
    if (programmaticCheck()) return _updateTriggerState(CState.TRIGGERED);
    return state;
  }

  /// @dev Executes logic to programmatically determine if the trigger should be toggled.
  function programmaticCheck() internal view returns (bool) {
    uint256 _truePrice = _oraclePrice(truthOracle, truthFrequencyTolerance);
    uint256 _trackingPrice = _oraclePrice(trackingOracle, trackingFrequencyTolerance);

    uint256 _priceDelta = _truePrice > _trackingPrice ? _truePrice - _trackingPrice : _trackingPrice - _truePrice;

    // We round up when calculating the delta percentage to accommodate for precision loss to
    // ensure that the state becomes triggered when the delta is greater than the price tolerance.
    // When the delta is less than or exactly equal to the price tolerance, the resulting rounded
    // up value will not be greater than the price tolerance, as expected.
    return _truePrice > 0 ? _priceDelta.mulDivUp(ZOC, _truePrice) > priceTolerance : true;
  }

  /// @dev Returns the current price of the specified `_oracle`.
  function _oraclePrice(AggregatorV3Interface _oracle, uint256 _frequencyTolerance) internal view returns (uint256 _price) {
    (,int256 _priceInt,, uint256 _updatedAt,) = _oracle.latestRoundData();
    if (_updatedAt > block.timestamp) revert InvalidTimestamp();
    if (block.timestamp - _updatedAt > _frequencyTolerance) revert StaleOraclePrice();
    if (_priceInt < 0) revert InvalidPrice();
    _price = uint256(_priceInt);
  }
}

pragma solidity 0.8.15;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @notice An aggregator that does one thing: return a fixed price, in fixed decimals, as set
 * in the constructor.
 */
contract FixedPriceAggregator is AggregatorV3Interface {
  /// @notice The number of decimals the fixed price is represented in.
  uint8 public immutable decimals;

  /// @notice The fixed price, in the decimals indicated, returned by this oracle.
  int256 private immutable price;

  /// @param _decimals The number of decimals the fixed price is represented in.
  /// @param _price The fixed price, in the decimals indicated, to be returned by this oracle.
  constructor(uint8 _decimals, int256 _price) {
    price = _price;
    decimals = _decimals;
  }


  /// @notice A description indicating this is a fixed price oracle.
  function description() external pure returns (string memory) {
    return "Fixed price oracle";
  }

   /// @notice A version number of 0.
  function version() external pure returns (uint256) {
    return 0;
  }

  /// @notice Returns data for the specified round.
  /// @param _roundId This parameter is ignored.
  /// @return roundId 0
  /// @return answer The fixed price returned by this oracle, represented in appropriate decimals.
  /// @return startedAt 0
  /// @return updatedAt Since price is fixed, we always return the current block timestamp.
  /// @return answeredInRound 0
  function getRoundData(uint80 _roundId)
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    _roundId; // Silence unused variable compiler warning.
    return (uint80(0), price, uint256(0), block.timestamp, uint80(0));
  }

  /// @notice Returns data for the latest round.
  /// @return roundId 0
  /// @return answer The fixed price returned by this oracle, represented in appropriate decimals.
  /// @return startedAt 0
  /// @return updatedAt Since price is fixed, we always return the current block timestamp.
  /// @return answeredInRound 0
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (uint80(0), price, uint256(0), block.timestamp, uint80(0));
  }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/**
 * @dev Contains the enum used to define valid Cozy states.
 * @dev All states except TRIGGERED are valid for sets, and all states except PAUSED are valid for markets/triggers.
 */
interface ICState {
  // The set of all Cozy states.
  enum CState {
    ACTIVE,
    FROZEN,
    PAUSED,
    TRIGGERED
  }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

/**
 * @dev Interface for interacting with Cozy protocol Sets. This is not a comprehensive
 * interface, and only contains the methods needed by triggers.
 */
interface ISet {
  function setOwner(address set) external view returns (address);
  function owner() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/interfaces/IBaseTrigger.sol";
import "src/interfaces/ICState.sol";
import "src/interfaces/IManager.sol";
import "src/interfaces/ISet.sol";

/**
 * @dev Core trigger interface and implementation. All triggers should inherit from this to ensure they conform
 * to the required trigger interface.
 */
abstract contract BaseTrigger is ICState, IBaseTrigger {
  /// @notice Current trigger state.
  CState public state;

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve a specific Set.
  ISet[] public sets;

  /// @notice Prevent DOS attacks by limiting the number of sets.
  uint256 public constant MAX_SET_LENGTH = 25;

  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @dev Thrown when a state update results in an invalid state transition.
  error InvalidStateTransition();

  /// @dev Thrown when trying to add a set to the `sets` array when it's length is already at `MAX_SET_LENGTH`.
  error SetLimitReached();

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @param _manager The manager of the Cozy protocol.
  constructor(IManager _manager) {
    manager = _manager;
  }

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve all Sets.
  function getSets() public view returns(ISet[] memory) {
    return sets;
  }

  /// @notice The number of Sets that use this trigger in a market.
  function getSetsLength() public view returns(uint256) {
    return sets.length;
  }

  /// @dev Call this method to update Set addresses after deploy.
  function addSet(ISet _set) external {
    if (msg.sender != address(manager)) revert Unauthorized();
    (bool _exists,,,) = manager.sets(_set);
    if (!_exists) revert Unauthorized();

    uint256 setLength = sets.length;
    if (setLength >= MAX_SET_LENGTH) revert SetLimitReached();
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      if (sets[i] == _set) return;
    }
    sets.push(_set);
    emit SetAdded(_set);
  }

  /// @dev Child contracts should use this function to handle Trigger state transitions.
  function _updateTriggerState(CState _newState) internal returns (CState) {
    if (!_isValidTriggerStateTransition(state, _newState)) revert InvalidStateTransition();
    state = _newState;
    uint256 setLength = sets.length;
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      manager.updateMarketState(sets[i], _newState);
    }
    emit TriggerStateUpdated(_newState);
    return _newState;
  }

  /// @dev Reimplement this function if different state transitions are needed.
  function _isValidTriggerStateTransition(CState _oldState, CState _newState) internal virtual returns(bool) {
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true        | false    | true      |
    // | FROZEN    | true        | -           | false    | true      |
    // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot be paused
    // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state

    if (_oldState == CState.TRIGGERED) return false;
    if (_oldState == _newState) return true; // If oldState == newState, return true since the Manager will convert that into a no-op.
    if (_oldState == CState.ACTIVE && _newState == CState.FROZEN) return true;
    if (_oldState == CState.FROZEN && _newState == CState.ACTIVE) return true;
    if (_oldState == CState.ACTIVE && _newState == CState.TRIGGERED) return true;
    if (_oldState == CState.FROZEN && _newState == CState.TRIGGERED) return true;
    return false;
  }

  /// @dev Unchecked increment of the provided value. Realistically it's impossible to overflow a
  /// uint256 so this is always safe.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked { return i + 1; }
  }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/ITrigger.sol";
import "src/interfaces/IManager.sol";

/**
 * @dev Additional functions that are recommended to have in a trigger, but are not required.
 */
interface IBaseTrigger is ITrigger {
  /// @notice Returns the set address at the specified index in the trigger's list of sets.
  function sets(uint256 index) external returns(ISet set);

  /// @notice Returns all sets in the trigger's list of sets.
  function getSets() external returns(ISet[] memory);

  /// @notice Returns the number of Sets that use this trigger in a market.
  function getSetsLength() external returns(uint256 setsLength);

  /// @notice Returns the address of the trigger's manager.
  function manager() external returns(IManager managerAddress);

  /// @notice The maximum amount of sets that can be added to this trigger.
  function MAX_SET_LENGTH() external returns(uint256 maxSetLength);
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/ITriggerEvents.sol";

/**
 * @dev The minimal functions a trigger must implement to work with the Cozy protocol.
 */
interface ITrigger is ITriggerEvents {
  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns(CState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(ISet set) external;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/ICState.sol";
import "src/interfaces/ISet.sol";

/**
 * @dev Events that may be emitted by a trigger. Only `TriggerStateUpdated` is required.
 */
interface ITriggerEvents is ICState {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(CState indexed state);
}