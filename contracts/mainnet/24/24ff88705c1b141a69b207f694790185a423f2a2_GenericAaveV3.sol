/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-09
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// Global Enums and Structs



struct StrategyParams {
    uint256 performanceFee;
    uint256 activation;
    uint256 debtRatio;
    uint256 minDebtPerHarvest;
    uint256 maxDebtPerHarvest;
    uint256 lastReport;
    uint256 totalDebt;
    uint256 totalGain;
    uint256 totalLoss;
}

// Part: DataTypesV3

library DataTypesV3 {
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    //timestamp of last update
    uint40 lastUpdateTimestamp;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    //aToken address
    address aTokenAddress;
    //stableDebtToken address
    address stableDebtTokenAddress;
    //variableDebtToken address
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the current treasury balance, scaled
    uint128 accruedToTreasury;
    //the outstanding unbacked aTokens minted through the bridging feature
    uint128 unbacked;
    //the outstanding debt borrowed against this asset in isolation mode
    uint128 isolationModeTotalDebt;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60: asset is paused
    //bit 61: borrowing in isolation mode is enabled
    //bit 62-63: reserved
    //bit 64-79: reserve factor
    //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
    //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
    //bit 152-167 liquidation protocol fee
    //bit 168-175 eMode category
    //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
    //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
    //bit 252-255 unused

    uint256 data;
  }

  struct UserConfigurationMap {
    /**
     * @dev Bitmap of the users collaterals and borrows. It is divided in pairs of bits, one pair per asset.
     * The first bit indicates if an asset is used as collateral by the user, the second whether an
     * asset is borrowed by the user.
     */
    uint256 data;
  }

  struct EModeCategory {
    // each eMode category has a custom ltv and liquidation threshold
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    // each eMode category may or may not have a custom oracle to override the individual assets price oracles
    address priceSource;
    string label;
  }

  enum InterestRateMode {
    NONE,
    STABLE,
    VARIABLE
  }

  struct ReserveCache {
    uint256 currScaledVariableDebt;
    uint256 nextScaledVariableDebt;
    uint256 currPrincipalStableDebt;
    uint256 currAvgStableBorrowRate;
    uint256 currTotalStableDebt;
    uint256 nextAvgStableBorrowRate;
    uint256 nextTotalStableDebt;
    uint256 currLiquidityIndex;
    uint256 nextLiquidityIndex;
    uint256 currVariableBorrowIndex;
    uint256 nextVariableBorrowIndex;
    uint256 currLiquidityRate;
    uint256 currVariableBorrowRate;
    uint256 reserveFactor;
    ReserveConfigurationMap reserveConfiguration;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    uint40 reserveLastUpdateTimestamp;
    uint40 stableDebtLastUpdateTimestamp;
  }

  struct ExecuteLiquidationCallParams {
    uint256 reservesCount;
    uint256 debtToCover;
    address collateralAsset;
    address debtAsset;
    address user;
    bool receiveAToken;
    address priceOracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
  }

  struct ExecuteSupplyParams {
    address asset;
    uint256 amount;
    address onBehalfOf;
    uint16 referralCode;
  }

  struct ExecuteBorrowParams {
    address asset;
    address user;
    address onBehalfOf;
    uint256 amount;
    InterestRateMode interestRateMode;
    uint16 referralCode;
    bool releaseUnderlying;
    uint256 maxStableRateBorrowSizePercent;
    uint256 reservesCount;
    address oracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
  }

  struct ExecuteRepayParams {
    address asset;
    uint256 amount;
    InterestRateMode interestRateMode;
    address onBehalfOf;
    bool useATokens;
  }

  struct ExecuteWithdrawParams {
    address asset;
    uint256 amount;
    address to;
    uint256 reservesCount;
    address oracle;
    uint8 userEModeCategory;
  }

  struct ExecuteSetUserEModeParams {
    uint256 reservesCount;
    address oracle;
    uint8 categoryId;
  }

  struct FinalizeTransferParams {
    address asset;
    address from;
    address to;
    uint256 amount;
    uint256 balanceFromBefore;
    uint256 balanceToBefore;
    uint256 reservesCount;
    address oracle;
    uint8 fromEModeCategory;
  }

  struct FlashloanParams {
    address receiverAddress;
    address[] assets;
    uint256[] amounts;
    uint256[] interestRateModes;
    address onBehalfOf;
    bytes params;
    uint16 referralCode;
    uint256 flashLoanPremiumToProtocol;
    uint256 flashLoanPremiumTotal;
    uint256 maxStableRateBorrowSizePercent;
    uint256 reservesCount;
    address addressesProvider;
    uint8 userEModeCategory;
    bool isAuthorizedFlashBorrower;
  }

  struct FlashloanSimpleParams {
    address receiverAddress;
    address asset;
    uint256 amount;
    bytes params;
    uint16 referralCode;
    uint256 flashLoanPremiumToProtocol;
    uint256 flashLoanPremiumTotal;
  }

  struct FlashLoanRepaymentParams {
    uint256 amount;
    uint256 totalPremium;
    uint256 flashLoanPremiumToProtocol;
    address asset;
    address receiverAddress;
    uint16 referralCode;
  }

  struct CalculateUserAccountDataParams {
    UserConfigurationMap userConfig;
    uint256 reservesCount;
    address user;
    address oracle;
    uint8 userEModeCategory;
  }

  struct ValidateBorrowParams {
    ReserveCache reserveCache;
    UserConfigurationMap userConfig;
    address asset;
    address userAddress;
    uint256 amount;
    InterestRateMode interestRateMode;
    uint256 maxStableLoanPercent;
    uint256 reservesCount;
    address oracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
    bool isolationModeActive;
    address isolationModeCollateralAddress;
    uint256 isolationModeDebtCeiling;
  }

  struct ValidateLiquidationCallParams {
    ReserveCache debtReserveCache;
    uint256 totalDebt;
    uint256 healthFactor;
    address priceOracleSentinel;
  }

  struct CalculateInterestRatesParams {
    uint256 unbacked;
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalStableDebt;
    uint256 totalVariableDebt;
    uint256 averageStableBorrowRate;
    uint256 reserveFactor;
    address reserve;
    address aToken;
  }

  struct InitReserveParams {
    address asset;
    address aTokenAddress;
    address stableDebtAddress;
    address variableDebtAddress;
    address interestRateStrategyAddress;
    uint16 reservesCount;
    uint16 maxNumberReserves;
  }
}

// Part: IBaseStrategy

interface IBaseStrategy {
    function apiVersion() external pure returns (string memory);

    function name() external pure returns (string memory);

    function vault() external view returns (address);

    function keeper() external view returns (address);

    function tendTrigger(uint256 callCost) external view returns (bool);

    function tend() external;

    function harvestTrigger(uint256 callCost) external view returns (bool);

    function harvest() external;

    function management() external view returns (address);
}

// Part: IGenericLender

interface IGenericLender {
    function lenderName() external view returns (string memory);

    function nav() external view returns (uint256);

    function strategy() external view returns (address);

    function apr() external view returns (uint256);

    function weightedApr() external view returns (uint256);

    function withdraw(uint256 amount) external returns (uint256);

    function emergencyWithdraw(uint256 amount) external;

    function deposit() external;

    function withdrawAll() external returns (bool);

    function hasAssets() external view returns (bool);

    function aprAfterDeposit(uint256 amount) external view returns (uint256);

    function setDust(uint256 _dust) external;

    function sweep(address _token) external;
}

// Part: IPoolAddressesProvider

/**
 * @title IPoolAddressesProvider
 * @author Aave
 * @notice Defines the basic interface for a Pool Addresses Provider.
 **/
interface IPoolAddressesProvider {
  /**
   * @dev Emitted when the market identifier is updated.
   * @param oldMarketId The old id of the market
   * @param newMarketId The new id of the market
   */
  event MarketIdSet(string indexed oldMarketId, string indexed newMarketId);

  /**
   * @dev Emitted when the pool is updated.
   * @param oldAddress The old address of the Pool
   * @param newAddress The new address of the Pool
   */
  event PoolUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the pool configurator is updated.
   * @param oldAddress The old address of the PoolConfigurator
   * @param newAddress The new address of the PoolConfigurator
   */
  event PoolConfiguratorUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the price oracle is updated.
   * @param oldAddress The old address of the PriceOracle
   * @param newAddress The new address of the PriceOracle
   */
  event PriceOracleUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the ACL manager is updated.
   * @param oldAddress The old address of the ACLManager
   * @param newAddress The new address of the ACLManager
   */
  event ACLManagerUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the ACL admin is updated.
   * @param oldAddress The old address of the ACLAdmin
   * @param newAddress The new address of the ACLAdmin
   */
  event ACLAdminUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the price oracle sentinel is updated.
   * @param oldAddress The old address of the PriceOracleSentinel
   * @param newAddress The new address of the PriceOracleSentinel
   */
  event PriceOracleSentinelUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the pool data provider is updated.
   * @param oldAddress The old address of the PoolDataProvider
   * @param newAddress The new address of the PoolDataProvider
   */
  event PoolDataProviderUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when a new proxy is created.
   * @param id The identifier of the proxy
   * @param proxyAddress The address of the created proxy contract
   * @param implementationAddress The address of the implementation contract
   */
  event ProxyCreated(
    bytes32 indexed id,
    address indexed proxyAddress,
    address indexed implementationAddress
  );

  /**
   * @dev Emitted when a new non-proxied contract address is registered.
   * @param id The identifier of the contract
   * @param oldAddress The address of the old contract
   * @param newAddress The address of the new contract
   */
  event AddressSet(bytes32 indexed id, address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the implementation of the proxy registered with id is updated
   * @param id The identifier of the contract
   * @param proxyAddress The address of the proxy contract
   * @param oldImplementationAddress The address of the old implementation contract
   * @param newImplementationAddress The address of the new implementation contract
   */
  event AddressSetAsProxy(
    bytes32 indexed id,
    address indexed proxyAddress,
    address oldImplementationAddress,
    address indexed newImplementationAddress
  );

  /**
   * @notice Returns the id of the Aave market to which this contract points to.
   * @return The market id
   **/
  function getMarketId() external view returns (string memory);

  /**
   * @notice Associates an id with a specific PoolAddressesProvider.
   * @dev This can be used to create an onchain registry of PoolAddressesProviders to
   * identify and validate multiple Aave markets.
   * @param newMarketId The market id
   */
  function setMarketId(string calldata newMarketId) external;

  /**
   * @notice Returns an address by its identifier.
   * @dev The returned address might be an EOA or a contract, potentially proxied
   * @dev It returns ZERO if there is no registered address with the given id
   * @param id The id
   * @return The address of the registered for the specified id
   */
  function getAddress(bytes32 id) external view returns (address);

  /**
   * @notice General function to update the implementation of a proxy registered with
   * certain `id`. If there is no proxy registered, it will instantiate one and
   * set as implementation the `newImplementationAddress`.
   * @dev IMPORTANT Use this function carefully, only for ids that don't have an explicit
   * setter function, in order to avoid unexpected consequences
   * @param id The id
   * @param newImplementationAddress The address of the new implementation
   */
  function setAddressAsProxy(bytes32 id, address newImplementationAddress) external;

  /**
   * @notice Sets an address for an id replacing the address saved in the addresses map.
   * @dev IMPORTANT Use this function carefully, as it will do a hard replacement
   * @param id The id
   * @param newAddress The address to set
   */
  function setAddress(bytes32 id, address newAddress) external;

  /**
   * @notice Returns the address of the Pool proxy.
   * @return The Pool proxy address
   **/
  function getPool() external view returns (address);

  /**
   * @notice Updates the implementation of the Pool, or creates a proxy
   * setting the new `pool` implementation when the function is called for the first time.
   * @param newPoolImpl The new Pool implementation
   **/
  function setPoolImpl(address newPoolImpl) external;

  /**
   * @notice Returns the address of the PoolConfigurator proxy.
   * @return The PoolConfigurator proxy address
   **/
  function getPoolConfigurator() external view returns (address);

  /**
   * @notice Updates the implementation of the PoolConfigurator, or creates a proxy
   * setting the new `PoolConfigurator` implementation when the function is called for the first time.
   * @param newPoolConfiguratorImpl The new PoolConfigurator implementation
   **/
  function setPoolConfiguratorImpl(address newPoolConfiguratorImpl) external;

  /**
   * @notice Returns the address of the price oracle.
   * @return The address of the PriceOracle
   */
  function getPriceOracle() external view returns (address);

  /**
   * @notice Updates the address of the price oracle.
   * @param newPriceOracle The address of the new PriceOracle
   */
  function setPriceOracle(address newPriceOracle) external;

  /**
   * @notice Returns the address of the ACL manager.
   * @return The address of the ACLManager
   */
  function getACLManager() external view returns (address);

  /**
   * @notice Updates the address of the ACL manager.
   * @param newAclManager The address of the new ACLManager
   **/
  function setACLManager(address newAclManager) external;

  /**
   * @notice Returns the address of the ACL admin.
   * @return The address of the ACL admin
   */
  function getACLAdmin() external view returns (address);

  /**
   * @notice Updates the address of the ACL admin.
   * @param newAclAdmin The address of the new ACL admin
   */
  function setACLAdmin(address newAclAdmin) external;

  /**
   * @notice Returns the address of the price oracle sentinel.
   * @return The address of the PriceOracleSentinel
   */
  function getPriceOracleSentinel() external view returns (address);

  /**
   * @notice Updates the address of the price oracle sentinel.
   * @param newPriceOracleSentinel The address of the new PriceOracleSentinel
   **/
  function setPriceOracleSentinel(address newPriceOracleSentinel) external;

  /**
   * @notice Returns the address of the data provider.
   * @return The address of the DataProvider
   */
  function getPoolDataProvider() external view returns (address);

  /**
   * @notice Updates the address of the data provider.
   * @param newDataProvider The address of the new DataProvider
   **/
  function setPoolDataProvider(address newDataProvider) external;
}

// Part: IReserveInterestRateStrategy

//-- IReserveInterestRateStrategy implemented manually to avoid compiler errors for aprAfterDeposit function --//
/**
 * @title IReserveInterestRateStrategy
 * @author Aave
 * @notice Interface for the calculation of the interest rates
 */
interface IReserveInterestRateStrategy {
  /**
   * @notice Calculates the interest rates depending on the reserve's state and configurations
   * @param params The parameters needed to calculate interest rates
   * @return liquidityRate The liquidity rate expressed in rays
   * @return stableBorrowRate The stable borrow rate expressed in rays
   * @return variableBorrowRate The variable borrow rate expressed in rays
   **/
  function calculateInterestRates(DataTypesV3.CalculateInterestRatesParams calldata params)
    external
    view
    returns (
      uint256,
      uint256,
      uint256
    );
}

// Part: IRewardsDistributor

/**
 * @title IRewardsDistributor
 * @author Aave
 * @notice Defines the basic interface for a Rewards Distributor.
 */
interface IRewardsDistributor {
  /**
   * @dev Emitted when the configuration of the rewards of an asset is updated.
   * @param asset The address of the incentivized asset
   * @param reward The address of the reward token
   * @param oldEmission The old emissions per second value of the reward distribution
   * @param newEmission The new emissions per second value of the reward distribution
   * @param oldDistributionEnd The old end timestamp of the reward distribution
   * @param newDistributionEnd The new end timestamp of the reward distribution
   * @param assetIndex The index of the asset distribution
   */
  event AssetConfigUpdated(
    address indexed asset,
    address indexed reward,
    uint256 oldEmission,
    uint256 newEmission,
    uint256 oldDistributionEnd,
    uint256 newDistributionEnd,
    uint256 assetIndex
  );

  /**
   * @dev Emitted when rewards of an asset are accrued on behalf of a user.
   * @param asset The address of the incentivized asset
   * @param reward The address of the reward token
   * @param user The address of the user that rewards are accrued on behalf of
   * @param assetIndex The index of the asset distribution
   * @param userIndex The index of the asset distribution on behalf of the user
   * @param rewardsAccrued The amount of rewards accrued
   */
  event Accrued(
    address indexed asset,
    address indexed reward,
    address indexed user,
    uint256 assetIndex,
    uint256 userIndex,
    uint256 rewardsAccrued
  );

  /**
   * @dev Emitted when the emission manager address is updated.
   * @param oldEmissionManager The address of the old emission manager
   * @param newEmissionManager The address of the new emission manager
   */
  event EmissionManagerUpdated(
    address indexed oldEmissionManager,
    address indexed newEmissionManager
  );

  /**
   * @dev Sets the end date for the distribution
   * @param asset The asset to incentivize
   * @param reward The reward token that incentives the asset
   * @param newDistributionEnd The end date of the incentivization, in unix time format
   **/
  function setDistributionEnd(
    address asset,
    address reward,
    uint32 newDistributionEnd
  ) external;

  /**
   * @dev Sets the emission per second of a set of reward distributions
   * @param asset The asset is being incentivized
   * @param rewards List of reward addresses are being distributed
   * @param newEmissionsPerSecond List of new reward emissions per second
   */
  function setEmissionPerSecond(
    address asset,
    address[] calldata rewards,
    uint88[] calldata newEmissionsPerSecond
  ) external;

  /**
   * @dev Gets the end date for the distribution
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The timestamp with the end of the distribution, in unix time format
   **/
  function getDistributionEnd(address asset, address reward) external view returns (uint256);

  /**
   * @dev Returns the index of a user on a reward distribution
   * @param user Address of the user
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The current user asset index, not including new distributions
   **/
  function getUserAssetIndex(
    address user,
    address asset,
    address reward
  ) external view returns (uint256);

  /**
   * @dev Returns the configuration of the distribution reward for a certain asset
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The index of the asset distribution
   * @return The emission per second of the reward distribution
   * @return The timestamp of the last update of the index
   * @return The timestamp of the distribution end
   **/
  function getRewardsData(address asset, address reward)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  /**
   * @dev Returns the list of available reward token addresses of an incentivized asset
   * @param asset The incentivized asset
   * @return List of rewards addresses of the input asset
   **/
  function getRewardsByAsset(address asset) external view returns (address[] memory);

  /**
   * @dev Returns the list of available reward addresses
   * @return List of rewards supported in this contract
   **/
  function getRewardsList() external view returns (address[] memory);

  /**
   * @dev Returns the accrued rewards balance of a user, not including virtually accrued rewards since last distribution.
   * @param user The address of the user
   * @param reward The address of the reward token
   * @return Unclaimed rewards, not including new distributions
   **/
  function getUserAccruedRewards(address user, address reward) external view returns (uint256);

  /**
   * @dev Returns a single rewards balance of a user, including virtually accrued and unrealized claimable rewards.
   * @param assets List of incentivized assets to check eligible distributions
   * @param user The address of the user
   * @param reward The address of the reward token
   * @return The rewards amount
   **/
  function getUserRewards(
    address[] calldata assets,
    address user,
    address reward
  ) external view returns (uint256);

  /**
   * @dev Returns a list all rewards of a user, including already accrued and unrealized claimable rewards
   * @param assets List of incentivized assets to check eligible distributions
   * @param user The address of the user
   * @return The list of reward addresses
   * @return The list of unclaimed amount of rewards
   **/
  function getAllUserRewards(address[] calldata assets, address user)
    external
    view
    returns (address[] memory, uint256[] memory);

  /**
   * @dev Returns the decimals of an asset to calculate the distribution delta
   * @param asset The address to retrieve decimals
   * @return The decimals of an underlying asset
   */
  function getAssetDecimals(address asset) external view returns (uint8);

  /**
   * @dev Returns the address of the emission manager
   * @return The address of the EmissionManager
   */
  function getEmissionManager() external view returns (address);

  /**
   * @dev Updates the address of the emission manager
   * @param emissionManager The address of the new EmissionManager
   */
  function setEmissionManager(address emissionManager) external;
}

// Part: IScaledBalanceToken

interface IScaledBalanceToken {
  /**
   * @dev Emitted after the mint action
   * @param caller The address performing the mint
   * @param onBehalfOf The address of the user that will receive the minted scaled balance tokens
   * @param value The amount being minted (user entered amount + balance increase from interest)
   * @param balanceIncrease The increase in balance since the last action of the user
   * @param index The next liquidity index of the reserve
   **/
  event Mint(
    address indexed caller,
    address indexed onBehalfOf,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );

  /**
   * @dev Emitted after scaled balance tokens are burned
   * @param from The address from which the scaled tokens will be burned
   * @param target The address that will receive the underlying, if any
   * @param value The amount being burned (user entered amount - balance increase from interest)
   * @param balanceIncrease The increase in balance since the last action of the user
   * @param index The next liquidity index of the reserve
   **/
  event Burn(
    address indexed from,
    address indexed target,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );

  /**
   * @notice Returns the scaled balance of the user.
   * @dev The scaled balance is the sum of all the updated stored balance divided by the reserve's liquidity index
   * at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   **/
  function scaledBalanceOf(address user) external view returns (uint256);

  /**
   * @notice Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled total supply
   **/
  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);

  /**
   * @notice Returns the scaled total supply of the scaled balance token. Represents sum(debt/index)
   * @return The scaled total supply
   **/
  function scaledTotalSupply() external view returns (uint256);

  /**
   * @notice Returns last index interest was accrued to the user's balance
   * @param user The address of the user
   * @return The last index interest was accrued to the user's balance, expressed in ray
   **/
  function getPreviousIndex(address user) external view returns (uint256);
}

// Part: IStakedAave

interface IStakedAave {

    function stake(address to, uint256 amount) external;

    function redeem(address to, uint256 amount) external;

    function cooldown() external;

    function claimRewards(address to, uint256 amount) external;

    function getTotalRewardsBalance(address) external view returns (uint256);

    function COOLDOWN_SECONDS() external view returns (uint256);

    function stakersCooldowns(address) external view returns (uint256);

    function UNSTAKE_WINDOW() external view returns (uint256);
}

// Part: ITradeFactory

interface ITradeFactory {
    function enable(address, address) external;

    function grantRole(bytes32 role, address account) external;

    function STRATEGY() external view returns (bytes32);
}

// Part: IVeledrome

interface IVeledrome {
    struct route {
        address from;
        address to;
        bool stable;
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint amountIn, route[] memory routes) external view returns (uint256[] memory amounts);
}

// Part: OpenZeppelin/[email protected]/Address

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// Part: OpenZeppelin/[email protected]/IERC20

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// Part: OpenZeppelin/[email protected]/SafeMath

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// Part: IPool

/**
 * @title IPool
 * @author Aave
 * @notice Defines the basic interface for an Aave Pool.
 **/
interface IPool {
  /**
   * @dev Emitted on mintUnbacked()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address initiating the supply
   * @param onBehalfOf The beneficiary of the supplied assets, receiving the aTokens
   * @param amount The amount of supplied assets
   * @param referralCode The referral code used
   **/
  event MintUnbacked(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted on backUnbacked()
   * @param reserve The address of the underlying asset of the reserve
   * @param backer The address paying for the backing
   * @param amount The amount added as backing
   * @param fee The amount paid in fees
   **/
  event BackUnbacked(address indexed reserve, address indexed backer, uint256 amount, uint256 fee);

  /**
   * @dev Emitted on supply()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address initiating the supply
   * @param onBehalfOf The beneficiary of the supply, receiving the aTokens
   * @param amount The amount supplied
   * @param referralCode The referral code used
   **/
  event Supply(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted on withdraw()
   * @param reserve The address of the underlying asset being withdrawn
   * @param user The address initiating the withdrawal, owner of aTokens
   * @param to The address that will receive the underlying
   * @param amount The amount to be withdrawn
   **/
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  /**
   * @dev Emitted on borrow() and flashLoan() when debt needs to be opened
   * @param reserve The address of the underlying asset being borrowed
   * @param user The address of the user initiating the borrow(), receiving the funds on borrow() or just
   * initiator of the transaction on flashLoan()
   * @param onBehalfOf The address that will be getting the debt
   * @param amount The amount borrowed out
   * @param interestRateMode The rate mode: 1 for Stable, 2 for Variable
   * @param borrowRate The numeric rate at which the user has borrowed, expressed in ray
   * @param referralCode The referral code used
   **/
  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    DataTypesV3.InterestRateMode interestRateMode,
    uint256 borrowRate,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted on repay()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The beneficiary of the repayment, getting his debt reduced
   * @param repayer The address of the user initiating the repay(), providing the funds
   * @param amount The amount repaid
   * @param useATokens True if the repayment is done using aTokens, `false` if done with underlying asset directly
   **/
  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount,
    bool useATokens
  );

  /**
   * @dev Emitted on swapBorrowRateMode()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user swapping his rate mode
   * @param interestRateMode The current interest rate mode of the position being swapped: 1 for Stable, 2 for Variable
   **/
  event SwapBorrowRateMode(
    address indexed reserve,
    address indexed user,
    DataTypesV3.InterestRateMode interestRateMode
  );

  /**
   * @dev Emitted on borrow(), repay() and liquidationCall() when using isolated assets
   * @param asset The address of the underlying asset of the reserve
   * @param totalDebt The total isolation mode debt for the reserve
   */
  event IsolationModeTotalDebtUpdated(address indexed asset, uint256 totalDebt);

  /**
   * @dev Emitted when the user selects a certain asset category for eMode
   * @param user The address of the user
   * @param categoryId The category id
   **/
  event UserEModeSet(address indexed user, uint8 categoryId);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   **/
  event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   **/
  event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on rebalanceStableBorrowRate()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user for which the rebalance has been executed
   **/
  event RebalanceStableBorrowRate(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on flashLoan()
   * @param target The address of the flash loan receiver contract
   * @param initiator The address initiating the flash loan
   * @param asset The address of the asset being flash borrowed
   * @param amount The amount flash borrowed
   * @param interestRateMode The flashloan mode: 0 for regular flashloan, 1 for Stable debt, 2 for Variable debt
   * @param premium The fee flash borrowed
   * @param referralCode The referral code used
   **/
  event FlashLoan(
    address indexed target,
    address initiator,
    address indexed asset,
    uint256 amount,
    DataTypesV3.InterestRateMode interestRateMode,
    uint256 premium,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted when a borrower is liquidated.
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param liquidatedCollateralAmount The amount of collateral received by the liquidator
   * @param liquidator The address of the liquidator
   * @param receiveAToken True if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   **/
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  );

  /**
   * @dev Emitted when the state of a reserve is updated.
   * @param reserve The address of the underlying asset of the reserve
   * @param liquidityRate The next liquidity rate
   * @param stableBorrowRate The next stable borrow rate
   * @param variableBorrowRate The next variable borrow rate
   * @param liquidityIndex The next liquidity index
   * @param variableBorrowIndex The next variable borrow index
   **/
  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 stableBorrowRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @dev Emitted when the protocol treasury receives minted aTokens from the accrued interest.
   * @param reserve The address of the reserve
   * @param amountMinted The amount minted to the treasury
   **/
  event MintedToTreasury(address indexed reserve, uint256 amountMinted);

  /**
   * @dev Mints an `amount` of aTokens to the `onBehalfOf`
   * @param asset The address of the underlying asset to mint
   * @param amount The amount to mint
   * @param onBehalfOf The address that will receive the aTokens
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function mintUnbacked(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @dev Back the current unbacked underlying with `amount` and pay `fee`.
   * @param asset The address of the underlying asset to back
   * @param amount The amount to back
   * @param fee The amount paid in fees
   **/
  function backUnbacked(
    address asset,
    uint256 amount,
    uint256 fee
  ) external;

  /**
   * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @notice Supply with transfer approval of asset to be supplied done via permit function
   * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param deadline The deadline timestamp that the permit is valid
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param permitV The V parameter of ERC712 permit sig
   * @param permitR The R parameter of ERC712 permit sig
   * @param permitS The S parameter of ERC712 permit sig
   **/
  function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  /**
   * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to The address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   **/
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @notice Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
   * already supplied enough collateral, or he was given enough allowance by a credit delegator on the
   * corresponding debt token (StableDebtToken or VariableDebtToken)
   * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
   *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
   * @param asset The address of the underlying asset to borrow
   * @param amount The amount to be borrowed
   * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param onBehalfOf The address of the user who will receive the debt. Should be the address of the borrower itself
   * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
   * if he has been given credit delegation allowance
   **/
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  /**
   * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
   * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @param onBehalfOf The address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @return The final amount repaid
   **/
  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external returns (uint256);

  /**
   * @notice Repay with transfer approval of asset to be repaid done via permit function
   * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @param deadline The deadline timestamp that the permit is valid
   * @param permitV The V parameter of ERC712 permit sig
   * @param permitR The R parameter of ERC712 permit sig
   * @param permitS The S parameter of ERC712 permit sig
   * @return The final amount repaid
   **/
  function repayWithPermit(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256);

  /**
   * @notice Repays a borrowed `amount` on a specific reserve using the reserve aTokens, burning the
   * equivalent debt tokens
   * - E.g. User repays 100 USDC using 100 aUSDC, burning 100 variable/stable debt tokens
   * @dev  Passing uint256.max as amount will clean up any residual aToken dust balance, if the user aToken
   * balance is not enough to cover the whole debt
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @return The final amount repaid
   **/
  function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) external returns (uint256);

  /**
   * @notice Allows a borrower to swap his debt between stable and variable mode, or vice versa
   * @param asset The address of the underlying asset borrowed
   * @param interestRateMode The current interest rate mode of the position being swapped: 1 for Stable, 2 for Variable
   **/
  function swapBorrowRateMode(address asset, uint256 interestRateMode) external;

  /**
   * @notice Rebalances the stable interest rate of a user to the current stable rate defined on the reserve.
   * - Users can be rebalanced if the following conditions are satisfied:
   *     1. Usage ratio is above 95%
   *     2. the current supply APY is below REBALANCE_UP_THRESHOLD * maxVariableBorrowRate, which means that too
   *        much has been borrowed at a stable rate and suppliers are not earning enough
   * @param asset The address of the underlying asset borrowed
   * @param user The address of the user to be rebalanced
   **/
  function rebalanceStableBorrowRate(address asset, address user) external;

  /**
   * @notice Allows suppliers to enable/disable a specific supplied asset as collateral
   * @param asset The address of the underlying asset supplied
   * @param useAsCollateral True if the user wants to use the supply as collateral, false otherwise
   **/
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  /**
   * @notice Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
   * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
   *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param receiveAToken True if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   **/
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external;

  /**
   * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
   * as long as the amount taken plus a fee is returned.
   * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
   * into consideration. For further details please visit https://developers.aave.com
   * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanReceiver interface
   * @param assets The addresses of the assets being flash-borrowed
   * @param amounts The amounts of the assets being flash-borrowed
   * @param interestRateModes Types of the debt to open if the flash loan is not returned:
   *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
   *   1 -> Open debt at stable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   * @param onBehalfOf The address  that will receive the debt in the case of using on `modes` 1 or 2
   * @param params Variadic packed params to pass to the receiver as extra information
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata interestRateModes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;

  /**
   * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
   * as long as the amount taken plus a fee is returned.
   * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
   * into consideration. For further details please visit https://developers.aave.com
   * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanSimpleReceiver interface
   * @param asset The address of the asset being flash-borrowed
   * @param amount The amount of the asset being flash-borrowed
   * @param params Variadic packed params to pass to the receiver as extra information
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode
  ) external;

  /**
   * @notice Returns the user account data across all the reserves
   * @param user The address of the user
   * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
   * @return totalDebtBase The total debt of the user in the base currency used by the price feed
   * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
   * @return currentLiquidationThreshold The liquidation threshold of the user
   * @return ltv The loan to value of The user
   * @return healthFactor The current health factor of the user
   **/
  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );

  /**
   * @notice Initializes a reserve, activating it, assigning an aToken and debt tokens and an
   * interest rate strategy
   * @dev Only callable by the PoolConfigurator contract
   * @param asset The address of the underlying asset of the reserve
   * @param aTokenAddress The address of the aToken that will be assigned to the reserve
   * @param stableDebtAddress The address of the StableDebtToken that will be assigned to the reserve
   * @param variableDebtAddress The address of the VariableDebtToken that will be assigned to the reserve
   * @param interestRateStrategyAddress The address of the interest rate strategy contract
   **/
  function initReserve(
    address asset,
    address aTokenAddress,
    address stableDebtAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) external;

  /**
   * @notice Drop a reserve
   * @dev Only callable by the PoolConfigurator contract
   * @param asset The address of the underlying asset of the reserve
   **/
  function dropReserve(address asset) external;

  /**
   * @notice Updates the address of the interest rate strategy contract
   * @dev Only callable by the PoolConfigurator contract
   * @param asset The address of the underlying asset of the reserve
   * @param rateStrategyAddress The address of the interest rate strategy contract
   **/
  function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress)
    external;

  /**
   * @notice Sets the configuration bitmap of the reserve as a whole
   * @dev Only callable by the PoolConfigurator contract
   * @param asset The address of the underlying asset of the reserve
   * @param configuration The new configuration bitmap
   **/
  function setConfiguration(address asset, DataTypesV3.ReserveConfigurationMap calldata configuration)
    external;

  /**
   * @notice Returns the configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The configuration of the reserve
   **/
  function getConfiguration(address asset)
    external
    view
    returns (DataTypesV3.ReserveConfigurationMap memory);

  /**
   * @notice Returns the configuration of the user across all the reserves
   * @param user The user address
   * @return The configuration of the user
   **/
  function getUserConfiguration(address user)
    external
    view
    returns (DataTypesV3.UserConfigurationMap memory);

  /**
   * @notice Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  /**
   * @notice Returns the normalized variable debt per unit of asset
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  /**
   * @notice Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state and configuration data of the reserve
   **/
  function getReserveData(address asset) external view returns (DataTypesV3.ReserveData memory);

  /**
   * @notice Validates and finalizes an aToken transfer
   * @dev Only callable by the overlying aToken of the `asset`
   * @param asset The address of the underlying asset of the aToken
   * @param from The user from which the aTokens are transferred
   * @param to The user receiving the aTokens
   * @param amount The amount being transferred/withdrawn
   * @param balanceFromBefore The aToken balance of the `from` user before the transfer
   * @param balanceToBefore The aToken balance of the `to` user before the transfer
   */
  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromBefore,
    uint256 balanceToBefore
  ) external;

  /**
   * @notice Returns the list of the underlying assets of all the initialized reserves
   * @dev It does not include dropped reserves
   * @return The addresses of the underlying assets of the initialized reserves
   **/
  function getReservesList() external view returns (address[] memory);

  /**
   * @notice Returns the address of the underlying asset of a reserve by the reserve id as stored in the DataTypesV3.ReserveData struct
   * @param id The id of the reserve as stored in the DataTypesV3.ReserveData struct
   * @return The address of the reserve associated with id
   **/
  function getReserveAddressById(uint16 id) external view returns (address);

  /**
   * @notice Returns the PoolAddressesProvider connected to this contract
   * @return The address of the PoolAddressesProvider
   **/
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Updates the protocol fee on the bridging
   * @param bridgeProtocolFee The part of the premium sent to the protocol treasury
   */
  function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external;

  /**
   * @notice Updates flash loan premiums. Flash loan premium consists of two parts:
   * - A part is sent to aToken holders as extra, one time accumulated interest
   * - A part is collected by the protocol treasury
   * @dev The total premium is calculated on the total borrowed amount
   * @dev The premium to protocol is calculated on the total premium, being a percentage of `flashLoanPremiumTotal`
   * @dev Only callable by the PoolConfigurator contract
   * @param flashLoanPremiumTotal The total premium, expressed in bps
   * @param flashLoanPremiumToProtocol The part of the premium sent to the protocol treasury, expressed in bps
   */
  function updateFlashloanPremiums(
    uint128 flashLoanPremiumTotal,
    uint128 flashLoanPremiumToProtocol
  ) external;

  /**
   * @notice Configures a new category for the eMode.
   * @dev In eMode, the protocol allows very high borrowing power to borrow assets of the same category.
   * The category 0 is reserved as it's the default for volatile assets
   * @param id The id of the category
   * @param config The configuration of the category
   */
  function configureEModeCategory(uint8 id, DataTypesV3.EModeCategory memory config) external;

  /**
   * @notice Returns the data of an eMode category
   * @param id The id of the category
   * @return The configuration data of the category
   */
  function getEModeCategoryData(uint8 id) external view returns (DataTypesV3.EModeCategory memory);

  /**
   * @notice Allows a user to use the protocol in eMode
   * @param categoryId The id of the category
   */
  function setUserEMode(uint8 categoryId) external;

  /**
   * @notice Returns the eMode the user is using
   * @param user The address of the user
   * @return The eMode id
   */
  function getUserEMode(address user) external view returns (uint256);

  /**
   * @notice Resets the isolation mode total debt of the given asset to zero
   * @dev It requires the given asset has zero debt ceiling
   * @param asset The address of the underlying asset to reset the isolationModeTotalDebt
   */
  function resetIsolationModeTotalDebt(address asset) external;

  /**
   * @notice Returns the percentage of available liquidity that can be borrowed at once at stable rate
   * @return The percentage of available liquidity to borrow, expressed in bps
   */
  function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view returns (uint256);

  /**
   * @notice Returns the total fee on flash loans
   * @return The total fee on flashloans
   */
  function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

  /**
   * @notice Returns the part of the bridge fees sent to protocol
   * @return The bridge fee sent to the protocol treasury
   */
  function BRIDGE_PROTOCOL_FEE() external view returns (uint256);

  /**
   * @notice Returns the part of the flashloan fees sent to protocol
   * @return The flashloan fee sent to the protocol treasury
   */
  function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);

  /**
   * @notice Returns the maximum number of reserves supported to be listed in this Pool
   * @return The maximum number of reserves supported
   */
  function MAX_NUMBER_RESERVES() external view returns (uint16);

  /**
   * @notice Mints the assets accrued through the reserve factor to the treasury in the form of aTokens
   * @param assets The list of reserves for which the minting needs to be executed
   **/
  function mintToTreasury(address[] calldata assets) external;

  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   */
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external;

  /**
   * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
   * @dev Deprecated: Use the `supply` function instead
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;
}

// Part: IProtocolDataProvider

interface IProtocolDataProvider {
    struct TokenData {
        string symbol;
        address tokenAddress;
    }

    function ADDRESSES_PROVIDER()
        external
        view
        returns (IPoolAddressesProvider);

    function getAllReservesTokens() external view returns (TokenData[] memory);

    function getAllATokens() external view returns (TokenData[] memory);

    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );
    
    /**
    * Returns the efficiency mode category of the reserve
    * @param asset The address of the underlying asset of the reserve
    * @return The eMode id of the reserve
    */
    function getReserveEModeCategory(address asset) external view returns (uint256);

    function getReserveData(address asset)
        external
        view
        returns (
            uint256 unbacked,
            uint256 accruedToTreasuryScaled,
            uint256 totalAToken,
            uint256 totalStableDebt,
            uint256 totalVariableDebt,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,   
            uint256 averageStableBorrowRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            uint40 lastUpdateTimestamp
        );

    function getUserReserveData(address asset, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );

    function getReserveTokensAddresses(address asset)
        external
        view
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        );
}

// Part: IRewardsController

/**
 * @title IRewardsController
 * @author Aave
 * @notice Defines the basic interface for a Rewards Controller.
 */
interface IRewardsController is IRewardsDistributor {
  /**
   * @dev Emitted when a new address is whitelisted as claimer of rewards on behalf of a user
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  event ClaimerSet(address indexed user, address indexed claimer);

  /**
   * @dev Emitted when rewards are claimed
   * @param user The address of the user rewards has been claimed on behalf of
   * @param reward The address of the token reward is claimed
   * @param to The address of the receiver of the rewards
   * @param claimer The address of the claimer
   * @param amount The amount of rewards claimed
   */
  event RewardsClaimed(
    address indexed user,
    address indexed reward,
    address indexed to,
    address claimer,
    uint256 amount
  );

  /**
   * @dev Emitted when a transfer strategy is installed for the reward distribution
   * @param reward The address of the token reward
   * @param transferStrategy The address of TransferStrategy contract
   */
  event TransferStrategyInstalled(address indexed reward, address indexed transferStrategy);

  /**
   * @dev Emitted when the reward oracle is updated
   * @param reward The address of the token reward
   * @param rewardOracle The address of oracle
   */
  event RewardOracleUpdated(address indexed reward, address indexed rewardOracle);

  /**
   * @dev Whitelists an address to claim the rewards on behalf of another address
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  function setClaimer(address user, address claimer) external;

  /**
   * @dev Get the price aggregator oracle address
   * @param reward The address of the reward
   * @return The price oracle of the reward
   */
  function getRewardOracle(address reward) external view returns (address);

  /**
   * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
   * @param user The address of the user
   * @return The claimer address
   */
  function getClaimer(address user) external view returns (address);

  /**
   * @dev Returns the Transfer Strategy implementation contract address being used for a reward address
   * @param reward The address of the reward
   * @return The address of the TransferStrategy contract
   */
  function getTransferStrategy(address reward) external view returns (address);

  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param user The address of the user
   * @param userBalance The user balance of the asset
   * @param totalSupply The total supply of the asset
   **/
  function handleAction(
    address user,
    uint256 userBalance,
    uint256 totalSupply
  ) external;

  /**
   * @dev Claims reward for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
   * @param assets List of assets to check eligible distributions before claiming rewards
   * @param amount The amount of rewards to claim
   * @param to The address that will be receiving the rewards
   * @param reward The address of the reward token
   * @return The amount of rewards claimed
   **/
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to,
    address reward
  ) external returns (uint256);

  /**
   * @dev Claims reward for a user on behalf, on all the assets of the pool, accumulating the pending rewards. The
   * caller must be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param amount The amount of rewards to claim
   * @param user The address to check and claim rewards
   * @param to The address that will be receiving the rewards
   * @param reward The address of the reward token
   * @return The amount of rewards claimed
   **/
  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to,
    address reward
  ) external returns (uint256);

  /**
   * @dev Claims reward for msg.sender, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param amount The amount of rewards to claim
   * @param reward The address of the reward token
   * @return The amount of rewards claimed
   **/
  function claimRewardsToSelf(
    address[] calldata assets,
    uint256 amount,
    address reward
  ) external returns (uint256);

  /**
   * @dev Claims all rewards for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param to The address that will be receiving the rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardList"
   **/
  function claimAllRewards(address[] calldata assets, address to)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

  /**
   * @dev Claims all rewards for a user on behalf, on all the assets of the pool, accumulating the pending rewards. The caller must
   * be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param user The address to check and claim rewards
   * @param to The address that will be receiving the rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardsList"
   **/
  function claimAllRewardsOnBehalf(
    address[] calldata assets,
    address user,
    address to
  ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

  /**
   * @dev Claims all reward for msg.sender, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardsList"
   **/
  function claimAllRewardsToSelf(address[] calldata assets)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

 
}

// Part: OpenZeppelin/[email protected]/SafeERC20

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// Part: iearn-finance/[email protected]/VaultAPI

interface VaultAPI is IERC20 {
    function name() external view returns (string calldata);

    function symbol() external view returns (string calldata);

    function decimals() external view returns (uint256);

    function apiVersion() external pure returns (string memory);

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 expiry,
        bytes calldata signature
    ) external returns (bool);

    // NOTE: Vyper produces multiple signatures for a given function with "default" args
    function deposit() external returns (uint256);

    function deposit(uint256 amount) external returns (uint256);

    function deposit(uint256 amount, address recipient) external returns (uint256);

    // NOTE: Vyper produces multiple signatures for a given function with "default" args
    function withdraw() external returns (uint256);

    function withdraw(uint256 maxShares) external returns (uint256);

    function withdraw(uint256 maxShares, address recipient) external returns (uint256);

    function token() external view returns (address);

    function strategies(address _strategy) external view returns (StrategyParams memory);

    function pricePerShare() external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function depositLimit() external view returns (uint256);

    function maxAvailableShares() external view returns (uint256);

    /**
     * View how much the Vault would increase this Strategy's borrow limit,
     * based on its present performance (since its last report). Can be used to
     * determine expectedReturn in your Strategy.
     */
    function creditAvailable() external view returns (uint256);

    /**
     * View how much the Vault would like to pull back from the Strategy,
     * based on its present performance (since its last report). Can be used to
     * determine expectedReturn in your Strategy.
     */
    function debtOutstanding() external view returns (uint256);

    /**
     * View how much the Vault expect this Strategy to return at the current
     * block, based on its present performance (since its last report). Can be
     * used to determine expectedReturn in your Strategy.
     */
    function expectedReturn() external view returns (uint256);

    /**
     * This is the main contact point where the Strategy interacts with the
     * Vault. It is critical that this call is handled as intended by the
     * Strategy. Therefore, this function will be called by BaseStrategy to
     * make sure the integration is correct.
     */
    function report(
        uint256 _gain,
        uint256 _loss,
        uint256 _debtPayment
    ) external returns (uint256);

    /**
     * This function should only be used in the scenario where the Strategy is
     * being retired but no migration of the positions are possible, or in the
     * extreme scenario that the Strategy needs to be put into "Emergency Exit"
     * mode in order for it to exit as quickly as possible. The latter scenario
     * could be for any reason that is considered "critical" that the Strategy
     * exits its position as fast as possible, such as a sudden change in
     * market conditions leading to losses, or an imminent failure in an
     * external dependency.
     */
    function revokeStrategy() external;

    /**
     * View the governance address of the Vault to assert privileged functions
     * can only be called by governance. The Strategy serves the Vault, so it
     * is subject to governance defined by the Vault.
     */
    function governance() external view returns (address);

    /**
     * View the management address of the Vault to assert privileged functions
     * can only be called by management. The Strategy serves the Vault, so it
     * is subject to management defined by the Vault.
     */
    function management() external view returns (address);

    /**
     * View the guardian address of the Vault to assert privileged functions
     * can only be called by guardian. The Strategy serves the Vault, so it
     * is subject to guardian defined by the Vault.
     */
    function guardian() external view returns (address);
}

// Part: GenericLenderBase

abstract contract GenericLenderBase is IGenericLender {
    using SafeERC20 for IERC20;
    VaultAPI public vault;
    address public override strategy;
    IERC20 public want;
    string public override lenderName;
    uint256 public dust;

    event Cloned(address indexed clone);

    constructor(address _strategy, string memory _name) public {
        _initialize(_strategy, _name);
    }

    function _initialize(address _strategy, string memory _name) internal {
        require(address(strategy) == address(0), "Lender already initialized");

        strategy = _strategy;
        vault = VaultAPI(IBaseStrategy(strategy).vault());
        want = IERC20(vault.token());
        lenderName = _name;
        dust = 10000;

        want.safeApprove(_strategy, uint256(-1));
    }

    function initialize(address _strategy, string memory _name) external virtual {
        _initialize(_strategy, _name);
    }

    function _clone(address _strategy, string memory _name) internal returns (address newLender) {
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(address(this));

        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(clone_code, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(add(clone_code, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            newLender := create(0, clone_code, 0x37)
        }

        GenericLenderBase(newLender).initialize(_strategy, _name);
        emit Cloned(newLender);
    }

    function setDust(uint256 _dust) external virtual override management {
        dust = _dust;
    }

    function sweep(address _token) external virtual override management {
        address[] memory _protectedTokens = protectedTokens();
        for (uint256 i; i < _protectedTokens.length; i++) require(_token != _protectedTokens[i], "!protected");

        IERC20(_token).safeTransfer(vault.governance(), IERC20(_token).balanceOf(address(this)));
    }

    function protectedTokens() internal view virtual returns (address[] memory);

    modifier management() {
        require(
            msg.sender == address(strategy) || msg.sender == vault.governance() || msg.sender == IBaseStrategy(strategy).management(),
            "!management"
        );
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == vault.governance(), "!gov");
        _;
    }
}


/**
 * @title IInitializableAToken
 * @author Aave
 * @notice Interface for the initialize function on AToken
 **/
interface IInitializableAToken {
  /**
   * @dev Emitted when an aToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated pool
   * @param treasury The address of the treasury
   * @param incentivesController The address of the incentives controller for this aToken
   * @param aTokenDecimals The decimals of the underlying
   * @param aTokenName The name of the aToken
   * @param aTokenSymbol The symbol of the aToken
   * @param params A set of encoded parameters for additional initialization
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    address incentivesController,
    uint8 aTokenDecimals,
    string aTokenName,
    string aTokenSymbol,
    bytes params
  );

  /**
   * @notice Initializes the aToken
   * @param pool The pool contract that is initializing this contract
   * @param treasury The address of the Aave treasury, receiving the fees on this aToken
   * @param underlyingAsset The address of the underlying asset of this aToken (E.g. WETH for aWETH)
   * @param incentivesController The smart contract managing potential incentives distribution
   * @param aTokenDecimals The decimals of the aToken, same as the underlying asset's
   * @param aTokenName The name of the aToken
   * @param aTokenSymbol The symbol of the aToken
   * @param params A set of encoded parameters for additional initialization
   */
  function initialize(
    IPool pool,
    address treasury,
    address underlyingAsset,
    IRewardsController incentivesController,
    uint8 aTokenDecimals,
    string calldata aTokenName,
    string calldata aTokenSymbol,
    bytes calldata params
  ) external;
}
/**
 * @title IAToken
 * @author Aave
 * @notice Defines the basic interface for an AToken.
 **/
interface IAToken is IERC20, IScaledBalanceToken, IInitializableAToken {
  /**
   * @dev Emitted during the transfer action
   * @param from The user whose tokens are being transferred
   * @param to The recipient
   * @param value The amount being transferred
   * @param index The next liquidity index of the reserve
   **/
  event BalanceTransfer(address indexed from, address indexed to, uint256 value, uint256 index);

  /**
   * @notice Mints `amount` aTokens to `user`
   * @param caller The address performing the mint
   * @param onBehalfOf The address of the user that will receive the minted aTokens
   * @param amount The amount of tokens getting minted
   * @param index The next liquidity index of the reserve
   * @return `true` if the the previous balance of the user was 0
   */
  function mint(
    address caller,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external returns (bool);

  /**
   * @notice Burns aTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
   * @dev In some instances, the mint event could be emitted from a burn transaction
   * if the amount to burn is less than the interest that the user accrued
   * @param from The address from which the aTokens will be burned
   * @param receiverOfUnderlying The address that will receive the underlying
   * @param amount The amount being burned
   * @param index The next liquidity index of the reserve
   **/
  function burn(
    address from,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external;

  /**
   * @notice Mints aTokens to the reserve treasury
   * @param amount The amount of tokens getting minted
   * @param index The next liquidity index of the reserve
   */
  function mintToTreasury(uint256 amount, uint256 index) external;

  /**
   * @notice Transfers aTokens in the event of a borrow being liquidated, in case the liquidators reclaims the aToken
   * @param from The address getting liquidated, current owner of the aTokens
   * @param to The recipient
   * @param value The amount of tokens getting transferred
   **/
  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) external;

  /**
   * @notice Transfers the underlying asset to `target`.
   * @dev Used by the Pool to transfer assets in borrow(), withdraw() and flashLoan()
   * @param user The recipient of the underlying
   * @param amount The amount getting transferred
   **/
  function transferUnderlyingTo(address user, uint256 amount) external;

  /**
   * @notice Handles the underlying received by the aToken after the transfer has been completed.
   * @dev The default implementation is empty as with standard ERC20 tokens, nothing needs to be done after the
   * transfer is concluded. However in the future there may be aTokens that allow for example to stake the underlying
   * to receive LM rewards. In that case, `handleRepayment()` would perform the staking of the underlying asset.
   * @param user The user executing the repayment
   * @param amount The amount getting repaid
   **/
  function handleRepayment(address user, uint256 amount) external;

  /**
   * @notice Allow passing a signed message to approve spending
   * @dev implements the permit function as for
   * https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner The owner of the funds
   * @param spender The spender
   * @param value The amount
   * @param deadline The deadline timestamp, type(uint256).max for max deadline
   * @param v Signature param
   * @param s Signature param
   * @param r Signature param
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @dev Returns the address of the incentives controller contract
   **/
  function getIncentivesController() external view returns (IRewardsController);

  /**
   * @notice Returns the address of the underlying asset of this aToken (E.g. WETH for aWETH)
   * @return The address of the underlying asset
   **/
  function UNDERLYING_ASSET_ADDRESS() external view returns (address);

  /**
   * @notice Returns the address of the Aave treasury, receiving the fees on this aToken.
   * @return Address of the Aave treasury
   **/
  function RESERVE_TREASURY_ADDRESS() external view returns (address);

  /**
   * @notice Get the domain separator for the token
   * @dev Return cached value if chainId matches cache, otherwise recomputes separator
   * @return The domain separator of the token at current chain
   */
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @notice Returns the nonce for owner.
   * @param owner The address of the owner
   * @return The nonce of the owner
   **/
  function nonces(address owner) external view returns (uint256);

  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   */
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external;
}

// File: GenericAaveV3.sol

/********************
 *   A lender plugin for LenderYieldOptimiser for any erc20 asset on AaveV3
 *   Made by SamPriestley.com & jmonteer. Updated for V3 by Schlagatron
 *   https://github.com/Grandthrax/yearnV2-generic-lender-strat/blob/master/contracts/GenericLender/GenericAave.sol
 *
 ********************* */

contract GenericAaveV3 is GenericLenderBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    //Should be the same for all EVM chains
    IProtocolDataProvider public constant protocolDataProvider = IProtocolDataProvider(address(0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654));
    IAToken public aToken;
    
    //Only Applicable for Mainnet, We leave then since they wont be called on any other chain
    IStakedAave private constant stkAave = IStakedAave(0x4da27a545c0c5B758a6BA100e3a049001de870f5);
    address private constant AAVE = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);

    address public keep3r;

    bool public isIncentivised;
    //Amount to multiply callcost by in harvestTrigger
    uint256 profitFactor;

    // Used to assure we stop infinite while loops
    //Should never be more reward tokens than 5
    uint256 public maxLoops = 5;

    uint16 internal constant DEFAULT_REFERRAL = 7; 
    uint16 internal customReferral;

    /*** 
    Chain specific addresses that will be set on Constructor
    ***/
    //Wrapped native token for chain i.e. WETH
    address public WNATIVE;
    ///For Optimism we will only be using the Veledrome router \\\\
    address public baseRouter;
    address public secondRouter;
    //Uni v2 router to be used
    IVeledrome public router;

    address public tradeFactory;

    uint256 constant internal SECONDS_IN_YEAR = 365 days;

    /// @param _strategy The strategy that will connect the lender to
    /// @param _wNative The wrapped native token for chain. i.e. WETH/WFTM
    /// @param _baseRouter Address of a UniV2 Router to be used
    /// @param _secondRouter Address of the second router to be used as a backup
    /// @param name The name of the Strategy
    /// @param _isIncentivised Bool repersenting wether or not the pool has reward tokens currently
    constructor(
        address _strategy,
        address _wNative,
        address _baseRouter,
        address _secondRouter,
        string memory name,
        bool _isIncentivised
    ) public GenericLenderBase(_strategy, name) {
        _initialize(_wNative, _baseRouter, _secondRouter, _isIncentivised);
    }

    function initialize(
        address _wNative,
        address _baseRouter,
        address _secondRouter,
        bool _isIncentivised
    ) external {
        _initialize(_wNative, _baseRouter, _secondRouter, _isIncentivised);
    }

    function cloneAaveLender(
        address _strategy,
        address _baseRouter,
        address _secondRouter,
        string memory _name,
        bool _isIncentivised
    ) external returns (address newLender) {
        newLender = _clone(_strategy, _name);
        GenericAaveV3(newLender).initialize(WNATIVE, _baseRouter, _secondRouter, _isIncentivised);
    }

    function _initialize(
        address _wNative, 
        address _baseRouter, 
        address _secondRouter, 
        bool _isIncentivised
    ) internal {
        require(address(aToken) == address(0), "GenericAave already initialized");

        aToken = IAToken(_lendingPool().getReserveData(address(want)).aTokenAddress);

        if(_isIncentivised) {
            address rewardController = address(aToken.getIncentivesController());
            require(rewardController != address(0), "!aToken does not have incentives controller set up");
        }
        isIncentivised = _isIncentivised;

        IERC20(address(want)).safeApprove(address(_lendingPool()), type(uint256).max);

        //Set Chain Specific Addresses
        WNATIVE = _wNative;
        baseRouter = _baseRouter;
        secondRouter = _secondRouter;
        profitFactor = 100;
        router = IVeledrome(_baseRouter);
    }

    // for the management to activate / deactivate incentives functionality
    function setIsIncentivised(bool _isIncentivised) external management {
        // NOTE: if the aToken is not incentivised, getIncentivesController() might revert (aToken won't implement it)
        // to avoid calling it, we use the if else statement to check for valid address
        if(_isIncentivised) {
            address rewardController = address(aToken.getIncentivesController());
            require(rewardController != address(0), "!aToken does not have incentives controller set up");
        } 
        isIncentivised = _isIncentivised;
    }

    //On optimism there is only one router that complies with the Teledrome interfaces so this will not apply
    function changeRouter() external management {
        address currentRouter = address(router);

        router = currentRouter == baseRouter ? IVeledrome(secondRouter) : IVeledrome(baseRouter);
    }

    function setReferralCode(uint16 _customReferral) external management {
        require(_customReferral != 0, "!invalid referral code");
        customReferral = _customReferral;
    }

    function setProfitFactor(uint256 _profitFactor) external management {
        profitFactor = _profitFactor;
    }

    function setKeep3r(address _keep3r) external management {
        keep3r = _keep3r;
    }

    function deposit() external override management {
        uint256 balance = want.balanceOf(address(this));
        _deposit(balance);
    }

    function withdraw(uint256 amount) external override management returns (uint256) {
        return _withdraw(amount);
    }

    //emergency withdraw. sends balance plus amount to governance
    function emergencyWithdraw(uint256 amount) external override onlyGovernance {
        _lendingPool().withdraw(address(want), amount, address(this));

        want.safeTransfer(vault.governance(), want.balanceOf(address(this)));
    }

    function withdrawAll() external override management returns (bool) {
        uint256 invested = _nav();
        uint256 returned = _withdraw(invested);
        return returned >= invested;
    }

    function startCooldown() external management {
        // for emergency cases
        IStakedAave(stkAave).cooldown(); // it will revert if balance of stkAave == 0
    }

    function nav() external view override returns (uint256) {
        return _nav();
    }

    function underlyingBalanceStored() public view returns (uint256 balance) {
        balance = aToken.balanceOf(address(this));
    }

    function apr() external view override returns (uint256) {
        return _apr();
    }

    function weightedApr() external view override returns (uint256) {
        uint256 a = _apr();
        return a.mul(_nav());
    }

    // calculates APR from Liquidity Mining Program
    function _incentivesRate(uint256 totalLiquidity, address rewardToken) public view returns (uint256) {
        // only returns != 0 if the incentives are in place at the moment.
        // Return 0 incase an improper address is sent so the whole tx doesnt fail
        if(rewardToken == address(0)) return 0;

        if(isIncentivised && block.timestamp < _incentivesController().getDistributionEnd(address(aToken), rewardToken)) {
            uint256 _emissionsPerSecond;
            (, _emissionsPerSecond, , ) = _incentivesController().getRewardsData(address(aToken), rewardToken);
            if(_emissionsPerSecond > 0) {
                uint256 emissionsInWant;
                if(rewardToken == address(want)) {
                    emissionsInWant = _emissionsPerSecond;
                } else if(rewardToken == address(stkAave)){
                    emissionsInWant = _checkPrice(AAVE, address(want), _emissionsPerSecond);
                } else {
                    emissionsInWant = _checkPrice(rewardToken, address(want), _emissionsPerSecond); // amount of emissions in want
                }

                uint256 incentivesRate = emissionsInWant.mul(SECONDS_IN_YEAR).mul(1e18).div(totalLiquidity); // APRs are in 1e18

                return incentivesRate.mul(9_500).div(10_000); // 95% of estimated APR to avoid overestimations
            }
        }
        return 0;
    }

    function aprAfterDeposit(uint256 extraAmount) external view override returns (uint256) {
        //need to calculate new supplyRate after Deposit (when deposit has not been done yet)
        DataTypesV3.ReserveData memory reserveData = _lendingPool().getReserveData(address(want));

        (uint256 unbacked, , , uint256 totalStableDebt, uint256 totalVariableDebt, , , , uint256 averageStableBorrowRate, , , ) =
            protocolDataProvider.getReserveData(address(want));

        uint256 availableLiquidity = want.balanceOf(address(aToken));

        uint256 newLiquidity = availableLiquidity.add(extraAmount);

        uint256 totalLiquidity = newLiquidity.add(unbacked).add(totalStableDebt).add(totalVariableDebt);

        (, , , , uint256 reserveFactor, , , , , ) = protocolDataProvider.getReserveConfigurationData(address(want));

        DataTypesV3.CalculateInterestRatesParams memory params = DataTypesV3.CalculateInterestRatesParams(
            unbacked,
            extraAmount,
            0,
            totalStableDebt,
            totalVariableDebt,
            averageStableBorrowRate,
            reserveFactor,
            address(want),
            address(aToken)
        );

        (uint256 newLiquidityRate, , ) = IReserveInterestRateStrategy(reserveData.interestRateStrategyAddress).calculateInterestRates(params);

        uint256 incentivesRate = 0;
        if(isIncentivised) {

            address[] memory rewardTokens = _incentivesController().getRewardsByAsset(address(aToken));
            uint256 i = 0;
            uint256 _maxLoops = maxLoops;
            uint256 tokenIncentivesRate;
            //Passes the total Supply and the corresponding reward token address for each reward token the want has
            while(i < rewardTokens.length && i < _maxLoops) {
                tokenIncentivesRate = _incentivesRate(totalLiquidity, rewardTokens[i]); 

                incentivesRate += tokenIncentivesRate;

                i ++;
            }
        }

        return newLiquidityRate.div(1e9).add(incentivesRate); // divided by 1e9 to go from Ray to Wad
    }

    function hasAssets() external view override returns (bool) {
        return aToken.balanceOf(address(this)) > dust || want.balanceOf(address(this)) > dust;
    }

    // Only for incentivised aTokens
    // this is a manual trigger to claim rewards
    // only callable if the token is incentivised by Aave Governance
    function harvest() external keepers{
        require(isIncentivised, "Not incevtivised, Nothing to harvest");

        //Need to redeem and aave from StkAave if applicable before claiming rewards and staring cool down over
        redeemAave();

        //claim all rewards
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        (address[] memory rewardsList, uint256[] memory claimedAmounts) = 
            _incentivesController().claimAllRewardsToSelf(assets);
        
        //swap as much as possible back to want
        address token;
        for(uint256 i = 0; i < rewardsList.length; i ++) {
            token = rewardsList[i];

            if(token == address(stkAave)) {
                harvestStkAave();
            } else if(token == address(want)) {
                continue;   
            } else {
                _swapFrom(token, address(want), IERC20(token).balanceOf(address(this)));
            }
        }

        // deposit want in lending protocol
        uint256 balance = want.balanceOf(address(this));
        if(balance > 0) {
            _deposit(balance);
        }
    }

    function redeemAave() internal {
        if(!_checkCooldown()) {
            return;
        }

        uint256 stkAaveBalance = IERC20(address(stkAave)).balanceOf(address(this));
        if(stkAaveBalance > 0) {
            stkAave.redeem(address(this), stkAaveBalance);
        }

        // sell AAVE for want
        _swapFrom(AAVE, address(want), IERC20(AAVE).balanceOf(address(this)));

    }

    function harvestStkAave() internal {
        // request start of cooldown period
        if(IERC20(address(stkAave)).balanceOf(address(this)) > 0) {
            stkAave.cooldown();
        }
    }

    function harvestTrigger(uint256 callcost) external view returns (bool) {
        if(!isIncentivised) {
            return false;
        }

        address[] memory assets = new address[](1);
        assets[0] = address(aToken);

        //check the total rewards available
        (address[] memory tokens, uint256[] memory rewards) = 
            _incentivesController().getAllUserRewards(assets, address(this));

        uint256 expectedRewards = 0;
        // If we have a positive amount of any rewards return true
        for(uint256 i = 0; i < rewards.length; i ++) {

            address token = tokens[i];
            if(token == WNATIVE){
                expectedRewards += rewards[i];
            } else if(token == address(stkAave)) {
                expectedRewards += _checkPrice(AAVE, WNATIVE, rewards[i]);
            } else {
                expectedRewards += _checkPrice(tokens[i], WNATIVE, rewards[i]);
            }
        }
        
        return expectedRewards >= callcost.mul(profitFactor);
    }

    function _nav() internal view returns (uint256) {
        return want.balanceOf(address(this)).add(underlyingBalanceStored());
    }

    function _apr() internal view returns (uint256) {
        uint256 liquidityRate = uint256(_lendingPool().getReserveData(address(want)).currentLiquidityRate).div(1e9);// dividing by 1e9 to pass from ray to wad

        (uint256 unbacked, , , uint256 totalStableDebt, uint256 totalVariableDebt, , , , , , , ) =
            protocolDataProvider.getReserveData(address(want));

        uint256 availableLiquidity = want.balanceOf(address(aToken));

        uint256 totalLiquidity = availableLiquidity.add(unbacked).add(totalStableDebt).add(totalVariableDebt);

        uint256 incentivesRate = 0;
        if(isIncentivised) {

            address[] memory rewardTokens = _incentivesController().getRewardsByAsset(address(aToken));
            uint256 i = 0;
            uint256 _maxLoops = maxLoops;
            uint256 tokenIncentivesRate;
            //Passes the total Supply and the corresponding reward token address for each reward token the want has
            while(i < rewardTokens.length && i < _maxLoops) {
                tokenIncentivesRate = _incentivesRate(totalLiquidity, rewardTokens[i]); 

                incentivesRate += tokenIncentivesRate;

                i ++;
            }
        }
        return liquidityRate.add(incentivesRate);
    }

    //withdraw an amount including any want balance
    function _withdraw(uint256 amount) internal returns (uint256) {
        uint256 balanceUnderlying = underlyingBalanceStored();
        uint256 looseBalance = want.balanceOf(address(this));
        uint256 total = balanceUnderlying.add(looseBalance);

        if (amount > total) {
            //cant withdraw more than we own
            amount = total;
        }

        if (looseBalance >= amount) {
            want.safeTransfer(address(strategy), amount);
            return amount;
        }

        //not state changing but OK because of previous call
        uint256 liquidity = want.balanceOf(address(aToken));

        if (liquidity > dust) {
            uint256 toWithdraw = amount.sub(looseBalance);

            if (toWithdraw <= liquidity) {
                //we can take all
                _lendingPool().withdraw(address(want), toWithdraw, address(this));
            } else {
                //take all we can
                _lendingPool().withdraw(address(want), liquidity, address(this));
            }
        }
        looseBalance = want.balanceOf(address(this));
        want.safeTransfer(address(strategy), looseBalance);
        return looseBalance;
    }

    function _deposit(uint256 amount) internal {
        IPool lp = _lendingPool();
        // NOTE: check if allowance is enough and acts accordingly
        // allowance might not be enough if
        //     i) initial allowance has been used (should take years)
        //     ii) lendingPool contract address has changed (Aave updated the contract address)
        if(want.allowance(address(this), address(lp)) < amount){
            IERC20(address(want)).safeApprove(address(lp), 0);
            IERC20(address(want)).safeApprove(address(lp), type(uint256).max);
        }

        uint16 referral;
        uint16 _customReferral = customReferral;
        if(_customReferral != 0) {
            referral = _customReferral;
        } else {
            referral = DEFAULT_REFERRAL;
        }

        lp.supply(address(want), amount, address(this), referral);
    }

    function _checkCooldown() internal view returns (bool) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if(id != 1) {
            return false;
        }

        uint256 cooldownStartTimestamp = IStakedAave(stkAave).stakersCooldowns(address(this));
        uint256 COOLDOWN_SECONDS = IStakedAave(stkAave).COOLDOWN_SECONDS();
        uint256 UNSTAKE_WINDOW = IStakedAave(stkAave).UNSTAKE_WINDOW();
        if(block.timestamp >= cooldownStartTimestamp.add(COOLDOWN_SECONDS)) {
            return block.timestamp.sub(cooldownStartTimestamp.add(COOLDOWN_SECONDS)) <= UNSTAKE_WINDOW || cooldownStartTimestamp == 0;
        } else {
            return false;
        }
    }

    function _checkPrice(
        address start,
        address end,
        uint256 _amount
    ) internal view returns (uint256) {
        if (_amount == 0) {
            return 0;
        }

        uint256[] memory amounts = router.getAmountsOut(_amount, getTokenOutPath(start, end));

        return amounts[amounts.length - 1];
    }

    function _swapFrom(address _from, address _to, uint256 _amountIn) internal{
        if (_amountIn == 0 || tradeFactory != address(0)) {
            return;
        }

        if(IERC20(_from).allowance(address(this), address(router)) < _amountIn) {
            IERC20(_from).safeApprove(address(router), 0);
            IERC20(_from).safeApprove(address(router), type(uint256).max);
        }

        router.swapExactTokensForTokens(
            _amountIn, 
            0, 
            getTokenOutPath(_from, _to), 
            address(this), 
            block.timestamp
        );
    }

    function getTokenOutPath(address _tokenIn, address _tokenOut) internal view returns (IVeledrome.route[] memory _path) {
        bool isNative = _tokenIn == WNATIVE || _tokenOut == WNATIVE;
        _path = new IVeledrome.route[](isNative ? 1 : 2);
        //_path[0] = _tokenIn;

        if (isNative) {
            _path[0] = IVeledrome.route(
                _tokenIn,
                _tokenOut,
                false
            );
        } else {
            _path[0] = IVeledrome.route(
                _tokenIn,
                WNATIVE,
                false
            );
            _path[1] = IVeledrome.route(
                WNATIVE,
                _tokenOut,
                false
            );
        }
    }

    function _lendingPool() internal view returns (IPool lendingPool) {
        lendingPool = IPool(protocolDataProvider.ADDRESSES_PROVIDER().getPool());
    }

    function _incentivesController() internal view returns (IRewardsController) {
        if(isIncentivised) {
            return aToken.getIncentivesController();
        } else {
            return IRewardsController(0);
        }
    }

    function protectedTokens() internal view override returns (address[] memory) {
        address[] memory protected = new address[](2);
        protected[0] = address(want);
        protected[1] = address(aToken);
        return protected;
    }

    modifier keepers() {
        require(
            msg.sender == address(keep3r) || msg.sender == address(strategy) || msg.sender == vault.governance() || msg.sender == IBaseStrategy(strategy).management(),
            "!keepers"
        );
        _;
    }

    // ---------------------- YSWAPS FUNCTIONS ----------------------
    function setTradeFactory(address _tradeFactory) external onlyGovernance {
        if (tradeFactory != address(0)) {
            _removeTradeFactoryPermissions();
        }

        if(isIncentivised) {
            address[] memory rewardTokens = _incentivesController().getRewardsByAsset(address(aToken));
            ITradeFactory tf = ITradeFactory(_tradeFactory);
            for(uint256 i; i < rewardTokens.length; i ++) {
                address token = rewardTokens[i];
                if(token == address(stkAave)) {
                    IERC20(AAVE).safeApprove(_tradeFactory, type(uint256).max);

                    tf.enable(AAVE, address(want));
                } else if (token == address(want)) {
                    continue;
                } else {
                    IERC20(token).safeApprove(_tradeFactory, type(uint256).max);

                    tf.enable(token, address(want));
                }
            }
        }
        tradeFactory = _tradeFactory;
    }

    function removeTradeFactoryPermissions() external management {
        _removeTradeFactoryPermissions();
    }

    function _removeTradeFactoryPermissions() internal {
        if(isIncentivised) {
            address[] memory rewardTokens = _incentivesController().getRewardsByAsset(address(aToken));
            for(uint256 i; i < rewardTokens.length; i ++) {
                address token = rewardTokens[i];
                if(token == address(stkAave)) {
                    IERC20(AAVE).safeApprove(tradeFactory, 0);
                } else {
                    IERC20(token).safeApprove(tradeFactory, 0);
                }
            }
        }
        tradeFactory = address(0);
    }
}