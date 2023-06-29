// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

enum VaultType {
    LEGACY,
    DEFAULT,
    AUTOMATED
}

interface IDetails {
    // get details from velo pool
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);
}

interface IRegistry {
    function newVault(
        address _token,
        address _governance,
        address _guardian,
        address _rewards,
        string calldata _name,
        string calldata _symbol,
        uint256 _releaseDelta,
        uint256 _type
    ) external returns (address);

    function latestVaultOfType(
        address token,
        uint256 _type
    ) external view returns (address);
}

interface IVelodromeGauge {
    function stakingToken() external view returns (address);
}

interface IVelodromeVoter {
    function isGauge(address) external view returns (bool);
}

interface IVelodromeRouter {
    struct Routes {
        address from;
        address to;
        bool stable;
        address factory;
    }
}

interface IStrategy {
    function cloneStrategyVelodrome(
        address _vault,
        address _strategist,
        address _rewards,
        address _keeper,
        address _gauge,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken0,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken1
    ) external returns (address newStrategy);

    function setLocalKeepVelo(uint256 _keepVelo) external;

    function setHealthCheck(address) external;

    function setBaseFeeOracle(address) external;

    function setVoter(address) external;
}

interface Vault {
    function setGovernance(address) external;

    function setManagement(address) external;

    function managementFee() external view returns (uint256);

    function setManagementFee(uint256) external;

    function performanceFee() external view returns (uint256);

    function setPerformanceFee(uint256) external;

    function setDepositLimit(uint256) external;

    function addStrategy(address, uint256, uint256, uint256, uint256) external;
}

contract VelodromeGlobal {
    event NewAutomatedVault(
        uint256 indexed category,
        address indexed lpToken,
        address gauge,
        address indexed vault,
        address velodromeStrategy
    );

    /* ========== STATE VARIABLES ========== */

    /// @notice This is a list of all vaults deployed by this factory.
    address[] public deployedVaults;

    /// @notice This is specific to the protocol we are deploying automated vaults for.
    /// @dev 0 for curve, 1 for balancer/beethoven, 2 for velodrome (on optimism). This is a subcategory within our vault type AUTOMATED on the registry.
    uint256 public constant CATEGORY = 2;

    /// @notice Owner of the factory.
    address public owner;

    // @notice Pending owner of the factory.
    /// @dev Must accept before becoming owner.
    address public pendingOwner;

    /// @notice Yearn's vault registry address.
    IRegistry public registry;

    /// @notice Address to use for vault governance.
    address public governance = 0xF5d9D6133b698cE29567a90Ab35CfB874204B3A7;

    /// @notice Address to use for vault management.
    address public management = 0xea3a15df68fCdBE44Fdb0DB675B2b3A14a148b26;

    /// @notice Address to use for vault guardian.
    address public guardian = 0xea3a15df68fCdBE44Fdb0DB675B2b3A14a148b26;

    /// @notice Address to use for vault and strategy rewards.
    address public treasury = 0x84654e35E504452769757AAe5a8C7C6599cBf954;

    /// @notice Address to use for strategy keepers.
    address public keeper = 0xC6387E937Bcef8De3334f80EDC623275d42457ff;

    /// @notice Address to use for strategy health check.
    address public healthCheck = 0x3d8F58774611676fd196D26149C71a9142C45296;

    /// @notice Address to use for our network's base fee oracle.
    address public baseFeeOracle = 0xbf4A735F123A9666574Ff32158ce2F7b7027De9A;

    /// @notice Address of our Velodrome strategy implementation.
    address public velodromeStratImplementation;

    /// @notice The percentage of VELO we re-lock to vote for pools factories LP. Default is 0%.
    uint256 public keepVELO;

    /// @notice The address of our Velodrome voter. This is where we send any keepVELO.
    address public veloVoter = 0xF5d9D6133b698cE29567a90Ab35CfB874204B3A7;

    /// @notice Minimum profit size in USDC that we want to harvest.
    uint256 public harvestProfitMinInUsdc = 1_000 * 1e6;

    /// @notice Maximum profit size in USDC that we want to harvest (ignore gas price once we get here).
    uint256 public harvestProfitMaxInUsdc = 100_000 * 1e6;

    /// @notice Default performance fee for our factory vaults (in basis points).
    uint256 public performanceFee = 1_000;

    /// @notice Default management fee for our factory vaults (in basis points).
    uint256 public managementFee = 0;

    /// @notice Default deposit limit on our factory vaults. Set to a large number.
    uint256 public depositLimit = 10_000_000_000_000 * 1e18;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _registry,
        address _velodromeStratImplementation,
        address _owner
    ) {
        registry = IRegistry(_registry);
        velodromeStratImplementation = _velodromeStratImplementation;
        owner = _owner;
        pendingOwner = _owner;
    }

    /* ========== STATE VARIABLE SETTERS ========== */

    /// @notice Set the new owner of the factory.
    /// @dev Must be called by current owner.
    ///  New owner will have to accept before transition is complete.
    /// @param newOwner Address of new owner.
    function setOwner(address newOwner) external {
        if (msg.sender != owner) {
            revert();
        }
        pendingOwner = newOwner;
    }

    /// @notice Accept ownership of the factory.
    /// @dev Must be called by pending owner.
    function acceptOwner() external {
        if (msg.sender != pendingOwner) {
            revert();
        }
        owner = pendingOwner;
    }

    /// @notice Set the yearn vault registry address for the factory.
    /// @dev Must be called by owner.
    /// @param _registry Address of yearn vault registry.
    function setRegistry(address _registry) external {
        if (msg.sender != owner) {
            revert();
        }
        registry = IRegistry(_registry);
    }

    /// @notice Set the vault governance address for the factory.
    /// @dev Must be called by owner.
    /// @param _governance Address of default vault governance.
    function setGovernance(address _governance) external {
        if (msg.sender != owner) {
            revert();
        }
        governance = _governance;
    }

    /// @notice Set the vault management address for the factory.
    /// @dev Must be called by owner.
    /// @param _management Address of default vault management.
    function setManagement(address _management) external {
        if (msg.sender != owner) {
            revert();
        }
        management = _management;
    }

    /// @notice Set the vault guardian address for the factory.
    /// @dev Must be called by owner.
    /// @param _guardian Address of default vault guardian.
    function setGuardian(address _guardian) external {
        if (msg.sender != owner) {
            revert();
        }
        guardian = _guardian;
    }

    /// @notice Set the vault treasury/rewards address for the factory.
    /// @dev Must be called by owner. Vault rewards will flow here.
    /// @param _treasury Address of default vault rewards.
    function setTreasury(address _treasury) external {
        if (msg.sender != owner) {
            revert();
        }
        treasury = _treasury;
    }

    /// @notice Set the vault keeper address for the factory.
    /// @dev Must be called by owner or management.
    /// @param _keeper Address of default vault keeper.
    function setKeeper(address _keeper) external {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }
        keeper = _keeper;
    }

    /// @notice Set the vault health check address for the factory.
    /// @dev Must be called by owner or management. Health check contracts
    ///  ensure that harvest profits are within expected limits before executing.
    /// @param _health Address of default health check contract.
    function setHealthcheck(address _health) external {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }
        healthCheck = _health;
    }

    /// @notice Set the strategy base fee oracle address for the factory.
    /// @dev Must be called by owner or management. Oracle passes current network base
    ///  fee so strategy can avoid harvesting during periods of network congestion.
    /// @param _baseFeeOracle Address of default base fee oracle for strategies.
    function setBaseFeeOracle(address _baseFeeOracle) external {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }
        baseFeeOracle = _baseFeeOracle;
    }

    /// @notice Set the vault deposit limit for the factory.
    /// @dev Must be called by owner or management.
    /// @param _depositLimit Default deposit limit for vaults created by factory.
    function setDepositLimit(uint256 _depositLimit) external {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }
        depositLimit = _depositLimit;
    }

    /// @notice Set the Velodrome strategy implementation address.
    /// @dev Must be called by owner.
    /// @param _velodrometratImplementation Address of latest Velodrome strategy implementation.
    function setVelodromeStratImplementation(
        address _velodrometratImplementation
    ) external {
        if (msg.sender != owner) {
            revert();
        }
        velodromeStratImplementation = _velodrometratImplementation;
    }

    /// @notice Direct a specified percentage of CRV from every harvest to Yearn's CRV voter.
    /// @dev Must be called by owner.
    /// @param _keepVELO The percentage of CRV from each harvest that we send to our voter (out of 10,000).
    /// @param _veloVoter The address of our Velo voter. This is where we send any keepVELO.
    function setKeepVELO(uint256 _keepVELO, address _veloVoter) external {
        if (msg.sender != owner) {
            revert();
        }
        if (_keepVELO > 10_000) {
            revert();
        }

        // since we use the voter to pull our strategyProxy, can't be zero address
        if (_veloVoter == address(0)) {
            revert();
        }

        keepVELO = _keepVELO;
        veloVoter = _veloVoter;
    }

    /// @notice Set the minimum amount of USDC profit required to harvest.
    /// @dev harvestTrigger will show true once we reach this amount of profit and gas price is acceptable.
    ///  Must be called by owner or management.
    /// @param _harvestProfitMinInUsdc Amount of USDC needed (6 decimals).
    function setHarvestProfitMinInUsdc(
        uint256 _harvestProfitMinInUsdc
    ) external {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }
        harvestProfitMinInUsdc = _harvestProfitMinInUsdc;
    }

    /// @notice Set the amount of USDC profit that will force a harvest.
    /// @dev harvestTrigger will show true once we reach this amount of profit no matter the gas price.
    ///  Must be called by owner or management.
    /// @param _harvestProfitMaxInUsdc Amount of USDC needed (6 decimals).
    function setHarvestProfitMaxInUsdc(
        uint256 _harvestProfitMaxInUsdc
    ) external {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }
        harvestProfitMaxInUsdc = _harvestProfitMaxInUsdc;
    }

    /// @notice Set the performance fee (percentage of profit) deducted from each harvest.
    /// @dev Must be called by owner. Fees are collected as minted vault shares.
    ///  Default amount is 10%.
    /// @param _performanceFee The percentage of profit from each harvest that is sent to treasury (out of 10,000).
    function setPerformanceFee(uint256 _performanceFee) external {
        if (msg.sender != owner) {
            revert();
        }
        if (_performanceFee > 5_000) {
            revert();
        }
        performanceFee = _performanceFee;
    }

    /// @notice Set the management fee (as a percentage of TVL) assessed on factory vaults.
    /// @dev Must be called by owner. Fees are collected as minted vault shares on each harvest.
    ///  Default amount is 0%.
    /// @param _managementFee The percentage fee assessed on TVL (out of 10,000).
    function setManagementFee(uint256 _managementFee) external {
        if (msg.sender != owner) {
            revert();
        }
        if (_managementFee > 1_000) {
            revert();
        }
        managementFee = _managementFee;
    }

    /* ========== VIEWS ========== */

    /// @notice View all vault addresses deployed by this factory.
    /// @return Array of all deployed factory vault addresses.
    function allDeployedVaults() external view returns (address[] memory) {
        return deployedVaults;
    }

    /// @notice Number of vaults deployed by this factory.
    /// @return Number of vaults deployed by this factory.
    function numVaults() external view returns (uint256) {
        return deployedVaults.length;
    }

    /// @notice Check whether, for a given gauge address, it is possible to permissionlessly
    ///  create a vault for corresponding LP token.
    /// @param _gauge The gauge address to check.
    /// @return Whether or not vault can be created permissionlessly.
    function canCreateVaultPermissionlessly(
        address _gauge
    ) public view returns (bool) {
        return latestStandardVaultFromGauge(_gauge) == address(0);
    }

    /// @notice Check for the latest vault address for any LEGACY/DEFAULT/AUTOMATED type vaults.
    ///  If no vault of either LEGACY, DEFAULT, or AUTOMATED types exists for this gauge, 0x0 is returned from registry.
    /// @param _gauge The gauge to use to check for any existing vaults.
    /// @return The latest standard vault address for the specified gauge.
    function latestStandardVaultFromGauge(
        address _gauge
    ) public view returns (address) {
        // make sure that our address is a gauge attached to the correct voter
        IVelodromeVoter voter = IVelodromeVoter(
            0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C
        );
        if (!voter.isGauge(_gauge)) {
            revert("not a v2 gauge");
        }

        // grab our lp token from our gauge
        address lptoken = IVelodromeGauge(_gauge).stakingToken();
        address latest;

        // we only care about types 0-2 here, so enforce that
        for (uint256 i; i < 3; ++i) {
            latest = registry.latestVaultOfType(lptoken, i);
            if (latest != address(0)) {
                break;
            }
        }
        return latest;
    }

    /* ========== CORE FUNCTIONS ========== */

    /// @notice Deploy a factory Curve vault for a given Curve gauge.
    /// @dev Permissioned users may set custom name and symbol or deploy if a legacy version already exists.
    ///  Must be called by owner or management.
    /// @param _gauge Address of the Curve gauge to deploy a new vault for.
    /// @param _name Name of the new vault.
    /// @param _symbol Symbol of the new vault token.
    /// @return vault Address of the new vault.
    /// @return velodromeStrategy Address of the vault's Curve boosted strategy.
    function createNewVaultsAndStrategiesPermissioned(
        address _gauge,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken0,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken1,
        string memory _name,
        string memory _symbol
    ) external returns (address vault, address velodromeStrategy) {
        if (!(msg.sender == owner || msg.sender == management)) {
            revert();
        }

        return
            _createNewVaultsAndStrategies(
                _gauge,
                _velodromeSwapRouteForToken0,
                _velodromeSwapRouteForToken1,
                true,
                _name,
                _symbol
            );
    }

    /// @notice Deploy a factory Curve vault for a given Curve gauge permissionlessly.
    /// @dev This may be called by anyone. Note that if a vault already exists for the given gauge,
    ///  then this call will revert.
    /// @param _gauge Address of the Curve gauge to deploy a new vault for.
    /// @return vault Address of the new vault.
    /// @return velodromeStrategy Address of the vault's Curve boosted strategy.
    function createNewVaultsAndStrategies(
        address _gauge,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken0,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken1
    ) external returns (address vault, address velodromeStrategy) {
        return
            _createNewVaultsAndStrategies(
                _gauge,
                _velodromeSwapRouteForToken0,
                _velodromeSwapRouteForToken1,
                false,
                "default",
                "default"
            );
    }

    // create a new vault along with strategies to match
    function _createNewVaultsAndStrategies(
        address _gauge,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken0,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken1,
        bool _permissionedUser,
        string memory _name,
        string memory _symbol
    ) internal returns (address vault, address velodromeStrategy) {
        // if a legacy vault already exists, only permissioned users can deploy another
        if (!_permissionedUser) {
            require(
                canCreateVaultPermissionlessly(_gauge),
                "Vault already exists"
            );
        }

        // get our lpToken from our gauge
        address lptoken = IVelodromeGauge(_gauge).stakingToken();

        if (_permissionedUser) {
            // allow trusted users to input the name and symbol or deploy a factory version of a legacy vault
            vault = _createCustomVault(lptoken, _name, _symbol);
        } else {
            // anyone can create a vault, but it will have an auto-generated name and symbol
            vault = _createStandardVault(lptoken);
        }

        // setup our fees, deposit limit, gov, etc
        _setupVaultParams(vault);

        // setup our strategies as needed
        velodromeStrategy = _setupStrategies(
            vault,
            _gauge,
            _velodromeSwapRouteForToken0,
            _velodromeSwapRouteForToken1
        );

        emit NewAutomatedVault(
            CATEGORY,
            lptoken,
            _gauge,
            vault,
            velodromeStrategy
        );
    }

    // permissioned users may pass custom name and symbol inputs
    function _createCustomVault(
        address lptoken,
        string memory _name,
        string memory _symbol
    ) internal returns (address vault) {
        vault = registry.newVault(
            lptoken,
            address(this),
            guardian,
            treasury,
            _name,
            _symbol,
            0,
            uint256(VaultType.AUTOMATED)
        );
    }

    // standard vaults create default name and symbols using on-chain data
    function _createStandardVault(
        address lptoken
    ) internal returns (address vault) {
        vault = registry.newVault(
            lptoken,
            address(this),
            guardian,
            treasury,
            string(
                abi.encodePacked(
                    "Velodrome ",
                    IDetails(address(lptoken)).symbol(),
                    " Factory yVault"
                )
            ),
            string(
                abi.encodePacked(
                    "yvVelo-",
                    IDetails(address(lptoken)).symbol(),
                    "-f"
                )
            ),
            0,
            uint256(VaultType.AUTOMATED)
        );
    }

    // set vault management, gov, deposit limit, and fees
    function _setupVaultParams(address _vault) internal {
        // record our new vault for posterity
        deployedVaults.push(_vault);

        Vault v = Vault(_vault);
        v.setManagement(management);

        // set governance to ychad who needs to accept before it is finalised. until then governance is this factory
        v.setGovernance(governance);
        v.setDepositLimit(depositLimit);

        if (v.managementFee() != managementFee) {
            v.setManagementFee(managementFee);
        }
        if (v.performanceFee() != performanceFee) {
            v.setPerformanceFee(performanceFee);
        }
    }

    // time to attach our strategies to the vault
    function _setupStrategies(
        address _vault,
        address _gauge,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken0,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken1
    ) internal returns (address velodromeStrategy) {
        // velodrome only has one strategy
        velodromeStrategy = _addVelodromeStrategy(
            _vault,
            _gauge,
            _velodromeSwapRouteForToken0,
            _velodromeSwapRouteForToken1
        );
    }

    // deploy and attach a new curve boosted strategy using our factory's existing implementation
    function _addVelodromeStrategy(
        address _vault,
        address _gauge,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken0,
        IVelodromeRouter.Routes[] memory _velodromeSwapRouteForToken1
    ) internal returns (address velodromeStrategy) {
        // create the velodrome  strategy
        velodromeStrategy = IStrategy(velodromeStratImplementation)
            .cloneStrategyVelodrome(
                _vault,
                management,
                treasury,
                keeper,
                _gauge,
                _velodromeSwapRouteForToken0,
                _velodromeSwapRouteForToken1
            );

        // set up health check and the base fee oracle for our new strategy
        IStrategy(velodromeStrategy).setHealthCheck(healthCheck);
        IStrategy(velodromeStrategy).setBaseFeeOracle(baseFeeOracle);

        // must set our voter, this is used to deposit
        IStrategy(velodromeStrategy).setVoter(veloVoter);

        // if we're keeping any tokens, then setup our keepVELO
        if (keepVELO > 0) {
            IStrategy(velodromeStrategy).setLocalKeepVelo(keepVELO);
        }

        // give it 100%
        uint256 veloDebtRatio = 10_000;

        Vault(_vault).addStrategy(
            velodromeStrategy,
            veloDebtRatio,
            0,
            type(uint256).max,
            0
        );
    }
}