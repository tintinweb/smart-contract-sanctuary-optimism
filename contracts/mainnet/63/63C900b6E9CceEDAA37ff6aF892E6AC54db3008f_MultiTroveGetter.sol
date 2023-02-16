// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import './Interfaces/IActivePool.sol';
import "./Interfaces/ICollateralConfig.sol";
import './Interfaces/IDefaultPool.sol';
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/ILQTYStaking.sol";
import "./Interfaces/IStabilityPool.sol";
import "./Interfaces/ITroveManager.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/SafeERC20.sol";
import "./Dependencies/IERC4626.sol";

/*
 * The Active Pool holds the collateral and LUSD debt for each collateral (but not LUSD tokens) for all active troves.
 *
 * When a trove is liquidated, it's collateral and LUSD debt are transferred from the Active Pool, to either the
 * Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
 *
 */
contract ActivePool is Ownable, CheckContract, IActivePool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string constant public NAME = "ActivePool";

    bool public addressesSet = false;
    address public collateralConfigAddress;
    address public borrowerOperationsAddress;
    address public troveManagerAddress;
    address public stabilityPoolAddress;
    address public defaultPoolAddress;
    address public collSurplusPoolAddress;
    address public treasuryAddress;
    address public lqtyStakingAddress;
    mapping (address => uint256) internal collAmount;  // collateral => amount tracker
    mapping (address => uint256) internal LUSDDebt;  // collateral => corresponding debt tracker

    mapping (address => uint256) public yieldingPercentage; // collateral => % to use for yield farming (in BPS, <= 10k)
    mapping (address => uint256) public yieldingAmount; // collateral => actual wei amount being used for yield farming
    mapping (address => address) public yieldGenerator; // collateral => corresponding ERC4626 vault
    mapping (address => uint256) public yieldClaimThreshold; // collateral => minimum wei amount of yield to claim and redistribute
    
    uint256 public yieldingPercentageDrift = 100; // rebalance iff % is off by more than 100 BPS

    // Yield distribution params, must add up to 10k
    uint256 public yieldSplitTreasury = 20_00; // amount of yield to direct to treasury in BPS
    uint256 public yieldSplitSP = 40_00; // amount of yield to direct to stability pool in BPS
    uint256 public yieldSplitStaking = 40_00; // amount of yield to direct to OATH Stakers in BPS

    // --- Events ---

    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event ActivePoolLUSDDebtUpdated(address _collateral, uint _LUSDDebt);
    event ActivePoolCollateralBalanceUpdated(address _collateral, uint _amount);
    event YieldingPercentageUpdated(address _collateral, uint256 _bps);
    event YieldingPercentageDriftUpdated(uint256 _driftBps);
    event YieldClaimThresholdUpdated(address _collateral, uint256 _threshold);
    event YieldDistributionParamsUpdated(uint256 _treasurySplit, uint256 _SPSplit, uint256 _stakingSplit);

    // --- Contract setters ---

    function setAddresses(
        address _collateralConfigAddress,
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _defaultPoolAddress,
        address _collSurplusPoolAddress,
        address _treasuryAddress,
        address _lqtyStakingAddress,
        address[] calldata _erc4626vaults
    )
        external
        onlyOwner
    {
        require(!addressesSet, "Can call setAddresses only once");

        checkContract(_collateralConfigAddress);
        checkContract(_borrowerOperationsAddress);
        checkContract(_troveManagerAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_defaultPoolAddress);
        checkContract(_collSurplusPoolAddress);
        require(_treasuryAddress != address(0), "Treasury cannot be 0 address");
        checkContract(_lqtyStakingAddress);

        collateralConfigAddress = _collateralConfigAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;
        troveManagerAddress = _troveManagerAddress;
        stabilityPoolAddress = _stabilityPoolAddress;
        defaultPoolAddress = _defaultPoolAddress;
        collSurplusPoolAddress = _collSurplusPoolAddress;
        treasuryAddress = _treasuryAddress;
        lqtyStakingAddress = _lqtyStakingAddress;

        address[] memory collaterals = ICollateralConfig(collateralConfigAddress).getAllowedCollaterals();
        uint256 numCollaterals = collaterals.length;
        require(numCollaterals == _erc4626vaults.length, "Vaults array length must match number of collaterals");
        for(uint256 i = 0; i < numCollaterals; i++) {
            address collateral = collaterals[i];
            address vault = _erc4626vaults[i];
            require(IERC4626(vault).asset() == collateral, "Vault asset must be collateral");
            yieldGenerator[collateral] = vault;
        }

        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit CollSurplusPoolAddressChanged(_collSurplusPoolAddress);

        addressesSet = true;
    }

    function setYieldingPercentage(address _collateral, uint256 _bps) external onlyOwner {
        _requireValidCollateralAddress(_collateral);
        require(_bps <= 10_000, "Invalid BPS value");
        yieldingPercentage[_collateral] = _bps;
        emit YieldingPercentageUpdated(_collateral, _bps);
    }

    function setYieldingPercentageDrift(uint256 _driftBps) external onlyOwner {
        require(_driftBps <= 500, "Exceeds max allowed value of 500 BPS");
        yieldingPercentageDrift = _driftBps;
        emit YieldingPercentageDriftUpdated(_driftBps);
    }

    function setYieldClaimThreshold(address _collateral, uint256 _threshold) external onlyOwner {
        _requireValidCollateralAddress(_collateral);
        yieldClaimThreshold[_collateral] = _threshold;
        emit YieldClaimThresholdUpdated(_collateral, _threshold);
    }

    function setYieldDistributionParams(uint256 _treasurySplit, uint256 _SPSplit, uint256 _stakingSplit) external onlyOwner {
        require(_treasurySplit + _SPSplit + _stakingSplit == 10_000, "Splits must add up to 10000 BPS");
        yieldSplitTreasury = _treasurySplit;
        yieldSplitSP = _SPSplit;
        yieldSplitStaking = _stakingSplit;
        emit YieldDistributionParamsUpdated(_treasurySplit, _SPSplit, _stakingSplit);
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the collAmount state variable.
    *
    *Not necessarily equal to the the contract's raw collateral balance - collateral can be forcibly sent to contracts.
    */
    function getCollateral(address _collateral) external view override returns (uint) {
        _requireValidCollateralAddress(_collateral);
        return collAmount[_collateral];
    }

    function getLUSDDebt(address _collateral) external view override returns (uint) {
        _requireValidCollateralAddress(_collateral);
        return LUSDDebt[_collateral];
    }

    // --- Pool functionality ---

    function sendCollateral(address _collateral, address _account, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsBOorTroveMorSP();
        _rebalance(_collateral, _amount);
        collAmount[_collateral] = collAmount[_collateral].sub(_amount);
        emit ActivePoolCollateralBalanceUpdated(_collateral, collAmount[_collateral]);
        emit CollateralSent(_collateral, _account, _amount);

        if (_account == defaultPoolAddress) {
            IERC20(_collateral).safeIncreaseAllowance(defaultPoolAddress, _amount);
            IDefaultPool(defaultPoolAddress).pullCollateralFromActivePool(_collateral, _amount);
        } else if (_account == collSurplusPoolAddress) {
            IERC20(_collateral).safeIncreaseAllowance(collSurplusPoolAddress, _amount);
            ICollSurplusPool(collSurplusPoolAddress).pullCollateralFromActivePool(_collateral, _amount);
        } else {
            IERC20(_collateral).safeTransfer(_account, _amount);
        }
    }

    function increaseLUSDDebt(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsBOorTroveM();
        LUSDDebt[_collateral] = LUSDDebt[_collateral].add(_amount);
        ActivePoolLUSDDebtUpdated(_collateral, LUSDDebt[_collateral]);
    }

    function decreaseLUSDDebt(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsBOorTroveMorSP();
        LUSDDebt[_collateral] = LUSDDebt[_collateral].sub(_amount);
        ActivePoolLUSDDebtUpdated(_collateral, LUSDDebt[_collateral]);
    }

    function pullCollateralFromBorrowerOperationsOrDefaultPool(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsBorrowerOperationsOrDefaultPool();
        collAmount[_collateral] = collAmount[_collateral].add(_amount);
        emit ActivePoolCollateralBalanceUpdated(_collateral, collAmount[_collateral]);

        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _amount);
        _rebalance(_collateral, 0);
    }

    function manualRebalance(address _collateral, uint256 _simulatedAmountLeavingPool) external onlyOwner {
        _requireValidCollateralAddress(_collateral);
        _rebalance(_collateral, _simulatedAmountLeavingPool);
    }

    // Due to "stack too deep" error
    struct LocalVariables_rebalance {
        uint256 currentAllocated;
        IERC4626 yieldGenerator;
        uint256 ownedShares;
        uint256 sharesToAssets;
        uint256 profit;
        uint256 finalBalance;
        uint256 percentOfFinalBal;
        uint256 yieldingPercentage;
        uint256 toDeposit;
        uint256 toWithdraw;
        uint256 yieldingAmount;
        uint256 finalYieldingAmount;
        int256 netAssetMovement;
        uint256 treasurySplit;
        uint256 stakingSplit;
        uint256 stabilityPoolSplit;
    }

    function _rebalance(address _collateral, uint256 _amountLeavingPool) internal {
        LocalVariables_rebalance memory vars;

        // how much has been allocated as per our internal records?
        vars.currentAllocated = yieldingAmount[_collateral];
        
        // what is the present value of our shares?
        vars.yieldGenerator = IERC4626(yieldGenerator[_collateral]);
        vars.ownedShares = vars.yieldGenerator.balanceOf(address(this));
        vars.sharesToAssets = vars.yieldGenerator.convertToAssets(vars.ownedShares);

        // if we have profit that's more than the threshold, record it for withdrawal and redistribution
        vars.profit = vars.sharesToAssets.sub(vars.currentAllocated);
        if (vars.profit < yieldClaimThreshold[_collateral]) {
            vars.profit = 0;
        }
        
        // what % of the final pool balance would the current allocation be?
        vars.finalBalance = collAmount[_collateral].sub(_amountLeavingPool);
        vars.percentOfFinalBal = vars.finalBalance == 0 ? uint256(-1) : vars.currentAllocated.mul(10_000).div(vars.finalBalance);

        // if abs(percentOfFinalBal - yieldingPercentage) > drift, we will need to deposit more or withdraw some
        vars.yieldingPercentage = yieldingPercentage[_collateral];
        vars.finalYieldingAmount = vars.finalBalance.mul(vars.yieldingPercentage).div(10_000);
        vars.yieldingAmount = yieldingAmount[_collateral];
        if (vars.percentOfFinalBal > vars.yieldingPercentage && vars.percentOfFinalBal.sub(vars.yieldingPercentage) > yieldingPercentageDrift) {
            // we will end up overallocated, withdraw some
            vars.toWithdraw = vars.currentAllocated.sub(vars.finalYieldingAmount);
            vars.yieldingAmount = vars.yieldingAmount.sub(vars.toWithdraw);
            yieldingAmount[_collateral] = vars.yieldingAmount;
        } else if(vars.percentOfFinalBal < vars.yieldingPercentage && vars.yieldingPercentage.sub(vars.percentOfFinalBal) > yieldingPercentageDrift) {
            // we will end up underallocated, deposit more
            vars.toDeposit = vars.finalYieldingAmount.sub(vars.currentAllocated);
            vars.yieldingAmount = vars.yieldingAmount.add(vars.toDeposit);
            yieldingAmount[_collateral] = vars.yieldingAmount;
        }

        // + means deposit, - means withdraw
        vars.netAssetMovement = int256(vars.toDeposit) - int256(vars.toWithdraw) - int256(vars.profit);
        if (vars.netAssetMovement > 0) {
            IERC20(_collateral).safeIncreaseAllowance(yieldGenerator[_collateral], uint256(vars.netAssetMovement));
            IERC4626(yieldGenerator[_collateral]).deposit(uint256(vars.netAssetMovement), address(this));
        } else if (vars.netAssetMovement < 0) {
            IERC4626(yieldGenerator[_collateral]).withdraw(uint256(-vars.netAssetMovement), address(this), address(this));
        }

        // if we recorded profit, recalculate it for precision and distribute
        if (vars.profit != 0) {
            // profit is ultimately (coll at hand) + (coll allocated to yield generator) - (recorded total coll Amount in pool)
            vars.profit = IERC20(_collateral).balanceOf(address(this)).add(vars.yieldingAmount).sub(collAmount[_collateral]);
            if (vars.profit != 0) {
                // distribute to treasury, staking pool, and stability pool
                vars.treasurySplit = vars.profit.mul(yieldSplitTreasury).div(10_000);
                if (vars.treasurySplit != 0) {
                    IERC20(_collateral).safeTransfer(treasuryAddress, vars.treasurySplit);
                }

                vars.stakingSplit = vars.profit.mul(yieldSplitStaking).div(10_000);
                if (vars.stakingSplit != 0) {
                    IERC20(_collateral).safeTransfer(lqtyStakingAddress, vars.stakingSplit);
                    ILQTYStaking(lqtyStakingAddress).increaseF_Collateral(_collateral, vars.stakingSplit);
                }

                vars.stabilityPoolSplit = vars.profit.sub(vars.treasurySplit.add(vars.stakingSplit));
                if (vars.stabilityPoolSplit != 0) {
                    IERC20(_collateral).safeTransfer(stabilityPoolAddress, vars.stabilityPoolSplit);
                    IStabilityPool(stabilityPoolAddress).updateRewardSum(_collateral, vars.stabilityPoolSplit);   
                }
            }
        }
    }

    // --- 'require' functions ---

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(
            ICollateralConfig(collateralConfigAddress).isCollateralAllowed(_collateral),
            "Invalid collateral address"
        );
    }

    function _requireCallerIsBorrowerOperationsOrDefaultPool() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == defaultPoolAddress,
            "ActivePool: Caller is neither BO nor Default Pool");
    }

    function _requireCallerIsBOorTroveMorSP() internal view {
        address redemptionHelper = address(ITroveManager(troveManagerAddress).redemptionHelper());
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress ||
            msg.sender == redemptionHelper ||
            msg.sender == stabilityPoolAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool");
    }

    function _requireCallerIsBOorTroveM() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/IBorrowerOperations.sol";
import "./Interfaces/ICollateralConfig.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Interfaces/ILQTYStaking.sol";
import "./Dependencies/LiquityBase.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/SafeERC20.sol";

contract BorrowerOperations is LiquityBase, Ownable, CheckContract, IBorrowerOperations {
    using SafeERC20 for IERC20;

    string constant public NAME = "BorrowerOperations";

    // --- Connected contract declarations ---

    ICollateralConfig public collateralConfig;
    ITroveManager public troveManager;

    address stabilityPoolAddress;

    address gasPoolAddress;

    ICollSurplusPool collSurplusPool;

    ILQTYStaking public lqtyStaking;
    address public lqtyStakingAddress;

    ILUSDToken public lusdToken;

    // A doubly linked list of Troves, sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    /* --- Variable container structs  ---

    Used to hold, return and assign variables inside a function, in order to avoid the error:
    "CompilerError: Stack too deep". */

     struct LocalVariables_adjustTrove {
        uint256 collCCR;
        uint256 collMCR;
        uint256 collDecimals;
        uint price;
        uint collChange;
        uint netDebtChange;
        bool isCollIncrease;
        uint debt;
        uint coll;
        uint oldICR;
        uint newICR;
        uint newTCR;
        uint LUSDFee;
        uint newDebt;
        uint newColl;
        uint stake;
    }

    struct LocalVariables_openTrove {
        uint256 collCCR;
        uint256 collMCR;
        uint256 collDecimals;
        uint price;
        uint LUSDFee;
        uint netDebt;
        uint compositeDebt;
        uint ICR;
        uint NICR;
        uint stake;
        uint arrayIndex;
    }

    struct ContractsCache {
        ITroveManager troveManager;
        IActivePool activePool;
        ILUSDToken lusdToken;
    }

    enum BorrowerOperation {
        openTrove,
        closeTrove,
        adjustTrove
    }

    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event PriceFeedAddressChanged(address  _newPriceFeedAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event LUSDTokenAddressChanged(address _lusdTokenAddress);
    event LQTYStakingAddressChanged(address _lqtyStakingAddress);

    event TroveCreated(address indexed _borrower, address _collateral, uint arrayIndex);
    event TroveUpdated(address indexed _borrower, address _collateral, uint _debt, uint _coll, uint stake, BorrowerOperation operation);
    event LUSDBorrowingFeePaid(address indexed _borrower, address _collateral, uint _LUSDFee);
    
    // --- Dependency setters ---

    function setAddresses(
        address _collateralConfigAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _lusdTokenAddress,
        address _lqtyStakingAddress
    )
        external
        override
        onlyOwner
    {
        // This makes impossible to open a trove with zero withdrawn LUSD
        assert(MIN_NET_DEBT > 0);

        checkContract(_collateralConfigAddress);
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);
        checkContract(_defaultPoolAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_gasPoolAddress);
        checkContract(_collSurplusPoolAddress);
        checkContract(_priceFeedAddress);
        checkContract(_sortedTrovesAddress);
        checkContract(_lusdTokenAddress);
        checkContract(_lqtyStakingAddress);

        collateralConfig = ICollateralConfig(_collateralConfigAddress);
        troveManager = ITroveManager(_troveManagerAddress);
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        stabilityPoolAddress = _stabilityPoolAddress;
        gasPoolAddress = _gasPoolAddress;
        collSurplusPool = ICollSurplusPool(_collSurplusPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        lusdToken = ILUSDToken(_lusdTokenAddress);
        lqtyStakingAddress = _lqtyStakingAddress;
        lqtyStaking = ILQTYStaking(_lqtyStakingAddress);

        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit CollSurplusPoolAddressChanged(_collSurplusPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit LUSDTokenAddressChanged(_lusdTokenAddress);
        emit LQTYStakingAddressChanged(_lqtyStakingAddress);

        renounceOwnership();
    }

    // --- Borrower Trove Operations ---

    function openTrove(address _collateral, uint _collAmount, uint _maxFeePercentage, uint _LUSDAmount, address _upperHint, address _lowerHint) external override {
        _requireValidCollateralAddress(_collateral);
        _requireSufficientCollateralBalanceAndAllowance(msg.sender, _collateral, _collAmount);
        ContractsCache memory contractsCache = ContractsCache(troveManager, activePool, lusdToken);
        LocalVariables_openTrove memory vars;

        vars.collCCR = collateralConfig.getCollateralCCR(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.price = priceFeed.fetchPrice(_collateral);
        bool isRecoveryMode = _checkRecoveryMode(_collateral, vars.price, vars.collCCR, vars.collDecimals);

        _requireValidMaxFeePercentage(_maxFeePercentage, isRecoveryMode);
        _requireTroveisNotActive(contractsCache.troveManager, msg.sender, _collateral);

        vars.netDebt = _LUSDAmount;

        if (!isRecoveryMode) {
            vars.LUSDFee = _triggerBorrowingFee(contractsCache.troveManager, contractsCache.lusdToken, _LUSDAmount, _maxFeePercentage);
            vars.netDebt = vars.netDebt.add(vars.LUSDFee);
        }
        _requireAtLeastMinNetDebt(vars.netDebt);

        // ICR is based on the composite debt, i.e. the requested LUSD amount + LUSD borrowing fee + LUSD gas comp.
        vars.compositeDebt = _getCompositeDebt(vars.netDebt);
        assert(vars.compositeDebt > 0);
        
        vars.ICR = LiquityMath._computeCR(_collAmount, vars.compositeDebt, vars.price, vars.collDecimals);
        vars.NICR = LiquityMath._computeNominalCR(_collAmount, vars.compositeDebt, vars.collDecimals);

        if (isRecoveryMode) {
            _requireICRisAboveCCR(vars.ICR, vars.collCCR);
        } else {
            _requireICRisAboveMCR(vars.ICR, vars.collMCR);
            uint newTCR = _getNewTCRFromTroveChange(
                _collateral,
                _collAmount,
                true, // coll increase
                vars.compositeDebt,
                true, // debt increase
                vars.price,
                vars.collDecimals
            );
            _requireNewTCRisAboveCCR(newTCR, vars.collCCR);
        }

        // Set the trove struct's properties
        contractsCache.troveManager.setTroveStatus(msg.sender, _collateral, 1);
        contractsCache.troveManager.increaseTroveColl(msg.sender, _collateral, _collAmount);
        contractsCache.troveManager.increaseTroveDebt(msg.sender, _collateral, vars.compositeDebt);

        contractsCache.troveManager.updateTroveRewardSnapshots(msg.sender, _collateral);
        vars.stake = contractsCache.troveManager.updateStakeAndTotalStakes(msg.sender, _collateral);

        sortedTroves.insert(_collateral, msg.sender, vars.NICR, _upperHint, _lowerHint);
        vars.arrayIndex = contractsCache.troveManager.addTroveOwnerToArray(msg.sender, _collateral);
        emit TroveCreated(msg.sender, _collateral, vars.arrayIndex);

        // Pull collateral, move it to the Active Pool, and mint the LUSDAmount to the borrower
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collAmount);
        _activePoolAddColl(contractsCache.activePool, _collateral, _collAmount);
        _withdrawLUSD(contractsCache.activePool, contractsCache.lusdToken, _collateral, msg.sender, _LUSDAmount, vars.netDebt);
        // Move the LUSD gas compensation to the Gas Pool
        _withdrawLUSD(contractsCache.activePool, contractsCache.lusdToken, _collateral, gasPoolAddress, LUSD_GAS_COMPENSATION, LUSD_GAS_COMPENSATION);

        emit TroveUpdated(msg.sender, _collateral, vars.compositeDebt, _collAmount, vars.stake, BorrowerOperation.openTrove);
        emit LUSDBorrowingFeePaid(msg.sender, _collateral, vars.LUSDFee);
    }

    // Send more collateral to an existing trove
    function addColl(address _collateral, uint _collAmount, address _upperHint, address _lowerHint) external override {
        _requireSufficientCollateralBalanceAndAllowance(msg.sender, _collateral, _collAmount);
        _adjustTrove(msg.sender, _collateral, _collAmount, 0, 0, false, _upperHint, _lowerHint, 0);
    }

    // Send collateral gain to a trove. Called by only the Stability Pool.
    function moveCollateralGainToTrove(address _borrower, address _collateral, uint _collAmount, address _upperHint, address _lowerHint) external override {
        _requireCallerIsStabilityPool();
        _adjustTrove(_borrower, _collateral, _collAmount, 0, 0, false, _upperHint, _lowerHint, 0);
    }

    // Withdraw collateral from a trove
    function withdrawColl(address _collateral, uint _collWithdrawal, address _upperHint, address _lowerHint) external override {
        _adjustTrove(msg.sender, _collateral, 0, _collWithdrawal, 0, false, _upperHint, _lowerHint, 0);
    }

    // Withdraw LUSD tokens from a trove: mint new LUSD tokens to the owner, and increase the trove's debt accordingly
    function withdrawLUSD(address _collateral, uint _maxFeePercentage, uint _LUSDAmount, address _upperHint, address _lowerHint) external override {
        _adjustTrove(msg.sender, _collateral, 0, 0, _LUSDAmount, true, _upperHint, _lowerHint, _maxFeePercentage);
    }

    // Repay LUSD tokens to a Trove: Burn the repaid LUSD tokens, and reduce the trove's debt accordingly
    function repayLUSD(address _collateral, uint _LUSDAmount, address _upperHint, address _lowerHint) external override {
        _adjustTrove(msg.sender, _collateral, 0, 0, _LUSDAmount, false, _upperHint, _lowerHint, 0);
    }

    function adjustTrove(address _collateral, uint _maxFeePercentage, uint _collTopUp, uint _collWithdrawal, uint _LUSDChange, bool _isDebtIncrease, address _upperHint, address _lowerHint) external override {
        if (_collTopUp != 0) {
            _requireSufficientCollateralBalanceAndAllowance(msg.sender, _collateral, _collTopUp);
        }
        _adjustTrove(msg.sender, _collateral, _collTopUp, _collWithdrawal, _LUSDChange, _isDebtIncrease, _upperHint, _lowerHint, _maxFeePercentage);
    }

    /*
    * _adjustTrove(): Alongside a debt change, this function can perform either a collateral top-up or a collateral withdrawal. 
    *
    * It therefore expects either a positive _collTopUp argument, or a positive _collWithdrawal argument.
    *
    * If both are positive, it will revert.
    */
    function _adjustTrove(address _borrower, address _collateral, uint _collTopUp, uint _collWithdrawal, uint _LUSDChange, bool _isDebtIncrease, address _upperHint, address _lowerHint, uint _maxFeePercentage) internal {
        ContractsCache memory contractsCache = ContractsCache(troveManager, activePool, lusdToken);
        LocalVariables_adjustTrove memory vars;

        vars.collCCR = collateralConfig.getCollateralCCR(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.price = priceFeed.fetchPrice(_collateral);
        bool isRecoveryMode = _checkRecoveryMode(_collateral, vars.price, vars.collCCR, vars.collDecimals);

        if (_isDebtIncrease) {
            _requireValidMaxFeePercentage(_maxFeePercentage, isRecoveryMode);
            _requireNonZeroDebtChange(_LUSDChange);
        }
        _requireSingularCollChange(_collTopUp, _collWithdrawal);
        _requireNonZeroAdjustment(_collTopUp, _collWithdrawal, _LUSDChange);
        _requireTroveisActive(contractsCache.troveManager, _borrower, _collateral);

        // Confirm the operation is either a borrower adjusting their own trove, or a pure collateral transfer from the Stability Pool to a trove
        assert(msg.sender == _borrower || (msg.sender == stabilityPoolAddress && _collTopUp > 0 && _LUSDChange == 0));

        contractsCache.troveManager.applyPendingRewards(_borrower, _collateral);

        // Get the collChange based on whether or not collateral was sent in the transaction
        (vars.collChange, vars.isCollIncrease) = _getCollChange(_collTopUp, _collWithdrawal);

        vars.netDebtChange = _LUSDChange;

        // If the adjustment incorporates a debt increase and system is in Normal Mode, then trigger a borrowing fee
        if (_isDebtIncrease && !isRecoveryMode) { 
            vars.LUSDFee = _triggerBorrowingFee(contractsCache.troveManager, contractsCache.lusdToken, _LUSDChange, _maxFeePercentage);
            vars.netDebtChange = vars.netDebtChange.add(vars.LUSDFee); // The raw debt change includes the fee
        }

        vars.debt = contractsCache.troveManager.getTroveDebt(_borrower, _collateral);
        vars.coll = contractsCache.troveManager.getTroveColl(_borrower, _collateral);
        
        // Get the trove's old ICR before the adjustment, and what its new ICR will be after the adjustment
        vars.oldICR = LiquityMath._computeCR(vars.coll, vars.debt, vars.price, vars.collDecimals);
        vars.newICR = _getNewICRFromTroveChange(
            vars.coll,
            vars.debt,
            vars.collChange,
            vars.isCollIncrease,
            vars.netDebtChange,
            _isDebtIncrease,
            vars.price,
            vars.collDecimals
        );
        assert(_collWithdrawal <= vars.coll); 

        // Check the adjustment satisfies all conditions for the current system mode
        _requireValidAdjustmentInCurrentMode(isRecoveryMode, _collateral, _collWithdrawal, _isDebtIncrease, vars);
            
        // When the adjustment is a debt repayment, check it's a valid amount and that the caller has enough LUSD
        if (!_isDebtIncrease && _LUSDChange > 0) {
            _requireAtLeastMinNetDebt(_getNetDebt(vars.debt).sub(vars.netDebtChange));
            _requireValidLUSDRepayment(vars.debt, vars.netDebtChange);
            _requireSufficientLUSDBalance(contractsCache.lusdToken, _borrower, vars.netDebtChange);
        }

        (vars.newColl, vars.newDebt) = _updateTroveFromAdjustment(contractsCache.troveManager, _borrower, _collateral, vars.collChange, vars.isCollIncrease, vars.netDebtChange, _isDebtIncrease);
        vars.stake = contractsCache.troveManager.updateStakeAndTotalStakes(_borrower, _collateral);

        // Re-insert trove in to the sorted list
        uint newNICR = _getNewNominalICRFromTroveChange(
            vars.coll,
            vars.debt,
            vars.collChange,
            vars.isCollIncrease,
            vars.netDebtChange,
            _isDebtIncrease,
            vars.collDecimals
        );
        sortedTroves.reInsert(_borrower, _collateral, newNICR, _upperHint, _lowerHint);

        emit TroveUpdated(_borrower, _collateral, vars.newDebt, vars.newColl, vars.stake, BorrowerOperation.adjustTrove);
        emit LUSDBorrowingFeePaid(msg.sender,  _collateral, vars.LUSDFee);

        // Use the unmodified _LUSDChange here, as we don't send the fee to the user
        _moveTokensAndCollateralfromAdjustment(
            contractsCache.activePool,
            contractsCache.lusdToken,
            msg.sender,
            _collateral,
            vars.collChange,
            vars.isCollIncrease,
            _LUSDChange,
            _isDebtIncrease,
            vars.netDebtChange
        );
    }

    function closeTrove(address _collateral) external override {
        ITroveManager troveManagerCached = troveManager;
        IActivePool activePoolCached = activePool;
        ILUSDToken lusdTokenCached = lusdToken;

        _requireTroveisActive(troveManagerCached, msg.sender, _collateral);
        uint256 collCCR = collateralConfig.getCollateralCCR(_collateral);
        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        uint price = priceFeed.fetchPrice(_collateral);
        _requireNotInRecoveryMode(_collateral, price, collCCR, collDecimals);

        troveManagerCached.applyPendingRewards(msg.sender, _collateral);

        uint coll = troveManagerCached.getTroveColl(msg.sender, _collateral);
        uint debt = troveManagerCached.getTroveDebt(msg.sender, _collateral);

        _requireSufficientLUSDBalance(lusdTokenCached, msg.sender, debt.sub(LUSD_GAS_COMPENSATION));

        uint newTCR = _getNewTCRFromTroveChange(_collateral, coll, false, debt, false, price, collDecimals);
        _requireNewTCRisAboveCCR(newTCR, collCCR);

        troveManagerCached.removeStake(msg.sender, _collateral);
        troveManagerCached.closeTrove(msg.sender, _collateral, 2); // 2 = closedByOwner

        emit TroveUpdated(msg.sender, _collateral, 0, 0, 0, BorrowerOperation.closeTrove);

        // Burn the repaid LUSD from the user's balance and the gas compensation from the Gas Pool
        _repayLUSD(activePoolCached, lusdTokenCached, _collateral, msg.sender, debt.sub(LUSD_GAS_COMPENSATION));
        _repayLUSD(activePoolCached, lusdTokenCached, _collateral, gasPoolAddress, LUSD_GAS_COMPENSATION);

        // Send the collateral back to the user
        activePoolCached.sendCollateral(_collateral, msg.sender, coll);
    }

    /**
     * Claim remaining collateral from a redemption or from a liquidation with ICR > MCR in Recovery Mode
     */
    function claimCollateral(address _collateral) external override {
        // send collateral from CollSurplus Pool to owner
        collSurplusPool.claimColl(msg.sender, _collateral);
    }

    // --- Helper functions ---

    function _triggerBorrowingFee(ITroveManager _troveManager, ILUSDToken _lusdToken, uint _LUSDAmount, uint _maxFeePercentage) internal returns (uint) {
        _troveManager.decayBaseRateFromBorrowing(); // decay the baseRate state variable
        uint LUSDFee = _troveManager.getBorrowingFee(_LUSDAmount);

        _requireUserAcceptsFee(LUSDFee, _LUSDAmount, _maxFeePercentage);
        
        // Send fee to LQTY staking contract
        lqtyStaking.increaseF_LUSD(LUSDFee);
        _lusdToken.mint(lqtyStakingAddress, LUSDFee);

        return LUSDFee;
    }

    function _getUSDValue(uint _coll, uint _price, uint256 _collDecimals) internal pure returns (uint) {
        uint usdValue = _price.mul(_coll).div(10**_collDecimals);

        return usdValue;
    }

    function _getCollChange(
        uint _collReceived,
        uint _requestedCollWithdrawal
    )
        internal
        pure
        returns(uint collChange, bool isCollIncrease)
    {
        if (_collReceived != 0) {
            collChange = _collReceived;
            isCollIncrease = true;
        } else {
            collChange = _requestedCollWithdrawal;
        }
    }

    // Update trove's coll and debt based on whether they increase or decrease
    function _updateTroveFromAdjustment
    (
        ITroveManager _troveManager,
        address _borrower,
        address _collateral,
        uint _collChange,
        bool _isCollIncrease,
        uint _debtChange,
        bool _isDebtIncrease
    )
        internal
        returns (uint, uint)
    {
        uint newColl = (_isCollIncrease) ? _troveManager.increaseTroveColl(_borrower, _collateral, _collChange)
                                        : _troveManager.decreaseTroveColl(_borrower, _collateral, _collChange);
        uint newDebt = (_isDebtIncrease) ? _troveManager.increaseTroveDebt(_borrower, _collateral, _debtChange)
                                        : _troveManager.decreaseTroveDebt(_borrower, _collateral, _debtChange);

        return (newColl, newDebt);
    }

    function _moveTokensAndCollateralfromAdjustment
    (
        IActivePool _activePool,
        ILUSDToken _lusdToken,
        address _borrower,
        address _collateral,
        uint _collChange,
        bool _isCollIncrease,
        uint _LUSDChange,
        bool _isDebtIncrease,
        uint _netDebtChange
    )
        internal
    {
        if (_isDebtIncrease) {
            _withdrawLUSD(_activePool, _lusdToken, _collateral, _borrower, _LUSDChange, _netDebtChange);
        } else {
            _repayLUSD(_activePool, _lusdToken, _collateral, _borrower, _LUSDChange);
        }

        if (_isCollIncrease) {
            IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collChange);
            _activePoolAddColl(_activePool, _collateral, _collChange);
        } else {
            _activePool.sendCollateral(_collateral, _borrower, _collChange);
        }
    }

    // Send collateral to Active Pool and increase its recorded collateral balance
    function _activePoolAddColl(IActivePool _activePool, address _collateral, uint _amount) internal {
        IERC20(_collateral).safeIncreaseAllowance(address(_activePool), _amount);
        _activePool.pullCollateralFromBorrowerOperationsOrDefaultPool(_collateral, _amount);
    }

    // Issue the specified amount of LUSD to _account and increases the total active debt (_netDebtIncrease potentially includes a LUSDFee)
    function _withdrawLUSD(IActivePool _activePool, ILUSDToken _lusdToken, address _collateral, address _account, uint _LUSDAmount, uint _netDebtIncrease) internal {
        _activePool.increaseLUSDDebt(_collateral, _netDebtIncrease);
        _lusdToken.mint(_account, _LUSDAmount);
    }

    // Burn the specified amount of LUSD from _account and decreases the total active debt
    function _repayLUSD(IActivePool _activePool, ILUSDToken _lusdToken, address _collateral, address _account, uint _LUSD) internal {
        _activePool.decreaseLUSDDebt(_collateral, _LUSD);
        _lusdToken.burn(_account, _LUSD);
    }

    // --- 'Require' wrapper functions ---

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(collateralConfig.isCollateralAllowed(_collateral), "BorrowerOps: Invalid collateral address");
    }

    function _requireSufficientCollateralBalanceAndAllowance(address _user, address _collateral, uint _collAmount) internal view {
        require(IERC20(_collateral).balanceOf(_user) >= _collAmount, "BorrowerOperations: Insufficient user collateral balance");
        require(IERC20(_collateral).allowance(_user, address(this)) >= _collAmount, "BorrowerOperations: Insufficient collateral allowance");
    }

    function _requireSingularCollChange(uint _collTopUp, uint _collWithdrawal) internal pure {
        require(_collTopUp == 0 || _collWithdrawal == 0, "BorrowerOperations: Cannot withdraw and add coll");
    }

    function _requireNonZeroAdjustment(uint _collTopUp, uint _collWithdrawal, uint _LUSDChange) internal pure {
        require(_collTopUp != 0 || _collWithdrawal != 0 || _LUSDChange != 0, "BorrowerOps: There must be either a collateral change or a debt change");
    }

    function _requireTroveisActive(ITroveManager _troveManager, address _borrower, address _collateral) internal view {
        uint status = _troveManager.getTroveStatus(_borrower, _collateral);
        require(status == 1, "BorrowerOps: Trove does not exist or is closed");
    }

    function _requireTroveisNotActive(ITroveManager _troveManager, address _borrower, address _collateral) internal view {
        uint status = _troveManager.getTroveStatus(_borrower, _collateral);
        require(status != 1, "BorrowerOps: Trove is active");
    }

    function _requireNonZeroDebtChange(uint _LUSDChange) internal pure {
        require(_LUSDChange > 0, "BorrowerOps: Debt increase requires non-zero debtChange");
    }
   
    function _requireNotInRecoveryMode(
        address _collateral,
        uint _price,
        uint256 _CCR,
        uint256 _collateralDecimals
    ) internal view {
        require(
            !_checkRecoveryMode(_collateral, _price, _CCR, _collateralDecimals),
            "BorrowerOps: Operation not permitted during Recovery Mode"
        );
    }

    function _requireNoCollWithdrawal(uint _collWithdrawal) internal pure {
        require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted Recovery Mode");
    }

    function _requireValidAdjustmentInCurrentMode 
    (
        bool _isRecoveryMode,
        address _collateral,
        uint _collWithdrawal,
        bool _isDebtIncrease, 
        LocalVariables_adjustTrove memory _vars
    ) 
        internal 
        view 
    {
        /* 
        *In Recovery Mode, only allow:
        *
        * - Pure collateral top-up
        * - Pure debt repayment
        * - Collateral top-up with debt repayment
        * - A debt increase combined with a collateral top-up which makes the ICR >= 150% and improves the ICR (and by extension improves the TCR).
        *
        * In Normal Mode, ensure:
        *
        * - The new ICR is above MCR
        * - The adjustment won't pull the TCR below CCR
        */
        if (_isRecoveryMode) {
            _requireNoCollWithdrawal(_collWithdrawal);
            if (_isDebtIncrease) {
                _requireICRisAboveCCR(_vars.newICR, _vars.collCCR);
                _requireNewICRisAboveOldICR(_vars.newICR, _vars.oldICR);
            }       
        } else { // if Normal Mode
            _requireICRisAboveMCR(_vars.newICR, _vars.collMCR);
            _vars.newTCR = _getNewTCRFromTroveChange(
                _collateral,
                _vars.collChange,
                _vars.isCollIncrease,
                _vars.netDebtChange,
                _isDebtIncrease,
                _vars.price,
                _vars.collDecimals
            );
            _requireNewTCRisAboveCCR(_vars.newTCR, _vars.collCCR);
        }
    }

    function _requireICRisAboveMCR(uint _newICR, uint256 _MCR) internal pure {
        require(_newICR >= _MCR, "BorrowerOps: An operation that would result in ICR < MCR is not permitted");
    }

    function _requireICRisAboveCCR(uint _newICR, uint256 _CCR) internal pure {
        require(_newICR >= _CCR, "BorrowerOps: Operation must leave trove with ICR >= CCR");
    }

    function _requireNewICRisAboveOldICR(uint _newICR, uint _oldICR) internal pure {
        require(_newICR >= _oldICR, "BorrowerOps: Cannot decrease your Trove's ICR in Recovery Mode");
    }

    function _requireNewTCRisAboveCCR(uint _newTCR, uint256 _CCR) internal pure {
        require(_newTCR >= _CCR, "BorrowerOps: An operation that would result in TCR < CCR is not permitted");
    }

    function _requireAtLeastMinNetDebt(uint _netDebt) internal pure {
        require (_netDebt >= MIN_NET_DEBT, "BorrowerOps: Trove's net debt must be greater than minimum");
    }

    function _requireValidLUSDRepayment(uint _currentDebt, uint _debtRepayment) internal pure {
        require(_debtRepayment <= _currentDebt.sub(LUSD_GAS_COMPENSATION), "BorrowerOps: Amount repaid must not be larger than the Trove's debt");
    }

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "BorrowerOps: Caller is not Stability Pool");
    }

     function _requireSufficientLUSDBalance(ILUSDToken _lusdToken, address _borrower, uint _debtRepayment) internal view {
        require(_lusdToken.balanceOf(_borrower) >= _debtRepayment, "BorrowerOps: Caller doesnt have enough LUSD to make repayment");
    }

    function _requireValidMaxFeePercentage(uint _maxFeePercentage, bool _isRecoveryMode) internal pure {
        if (_isRecoveryMode) {
            require(_maxFeePercentage <= DECIMAL_PRECISION,
                "Max fee percentage must less than or equal to 100%");
        } else {
            require(_maxFeePercentage >= BORROWING_FEE_FLOOR && _maxFeePercentage <= DECIMAL_PRECISION,
                "Max fee percentage must be between 0.5% and 100%");
        }
    }

    // --- ICR and TCR getters ---

    // Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewNominalICRFromTroveChange
    (
        uint _coll,
        uint _debt,
        uint _collChange,
        bool _isCollIncrease,
        uint _debtChange,
        bool _isDebtIncrease,
        uint256 _collateralDecimals
    )
        pure
        internal
        returns (uint)
    {
        (uint newColl, uint newDebt) = _getNewTroveAmounts(_coll, _debt, _collChange, _isCollIncrease, _debtChange, _isDebtIncrease);

        uint newNICR = LiquityMath._computeNominalCR(newColl, newDebt, _collateralDecimals);
        return newNICR;
    }

    // Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewICRFromTroveChange
    (
        uint _coll,
        uint _debt,
        uint _collChange,
        bool _isCollIncrease,
        uint _debtChange,
        bool _isDebtIncrease,
        uint _price,
        uint256 _collateralDecimals
    )
        pure
        internal
        returns (uint)
    {
        (uint newColl, uint newDebt) = _getNewTroveAmounts(_coll, _debt, _collChange, _isCollIncrease, _debtChange, _isDebtIncrease);

        uint newICR = LiquityMath._computeCR(newColl, newDebt, _price, _collateralDecimals);
        return newICR;
    }

    function _getNewTroveAmounts(
        uint _coll,
        uint _debt,
        uint _collChange,
        bool _isCollIncrease,
        uint _debtChange,
        bool _isDebtIncrease
    )
        internal
        pure
        returns (uint, uint)
    {
        uint newColl = _coll;
        uint newDebt = _debt;

        newColl = _isCollIncrease ? _coll.add(_collChange) :  _coll.sub(_collChange);
        newDebt = _isDebtIncrease ? _debt.add(_debtChange) : _debt.sub(_debtChange);

        return (newColl, newDebt);
    }

    function _getNewTCRFromTroveChange
    (
        address _collateral,
        uint _collChange,
        bool _isCollIncrease,
        uint _debtChange,
        bool _isDebtIncrease,
        uint _price,
        uint256 _collateralDecimals
    )
        internal
        view
        returns (uint)
    {
        uint totalColl = getEntireSystemColl(_collateral);
        uint totalDebt = getEntireSystemDebt(_collateral);

        totalColl = _isCollIncrease ? totalColl.add(_collChange) : totalColl.sub(_collChange);
        totalDebt = _isDebtIncrease ? totalDebt.add(_debtChange) : totalDebt.sub(_debtChange);

        uint newTCR = LiquityMath._computeCR(totalColl, totalDebt, _price, _collateralDecimals);
        return newTCR;
    }

    function getCompositeDebt(uint _debt) external pure override returns (uint) {
        return _getCompositeDebt(_debt);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Dependencies/CheckContract.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/SafeERC20.sol";
import "./Interfaces/ICollateralConfig.sol";

/**
 * Houses whitelist of allowed collaterals (ERC20s) for the entire system. Also provides access to collateral-specific
 * properties such as decimals, MCR, and CCR. Allowed collaterals and their properties may only be set once
 * during initialization after which they are immutable.
 */
contract CollateralConfig is ICollateralConfig, CheckContract, Ownable {
    using SafeERC20 for IERC20;

    bool public initialized = false;

    // Smallest allowed value for the minimum collateral ratio for individual troves in each market (collateral)
    uint256 constant public MIN_ALLOWED_MCR = 1.08 ether; // 108%

    // Smallest allowed value for Critical system collateral ratio.
    // If a market's (collateral's) total collateral ratio (TCR) falls below the CCR, Recovery Mode is triggered.
    uint256 constant public MIN_ALLOWED_CCR = 1.2 ether; // 120%

    struct Config {
        bool allowed;
        uint256 decimals;
        uint256 MCR;
        uint256 CCR;
    }

    address[] public collaterals; // for returning entire list of allowed collaterals
    mapping (address => Config) public collateralConfig; // for O(1) checking of collateral's validity and properties

    event CollateralWhitelisted(address _collateral, uint256 _decimals, uint256 _MCR, uint256 _CCR);
    event CollateralRatiosUpdated(address _collateral, uint256 _MCR, uint256 _CCR);

    /**
     * @notice One-time owner-only initializer.
     * @param _collaterals Ordered list of ERC20 tokens that will be allowed as collateral throughout the system.
     * @param _MCRs Ordered list of minimum collateralization ratio (MCR) for each of the collaterals.
     * @param _CCRs Ordered list of critical collateralization ratio (CCR) for each of the collaterals.
     */
    function initialize(
        address[] calldata _collaterals,
        uint256[] calldata _MCRs,
        uint256[] calldata _CCRs
    ) external override onlyOwner {
        require(!initialized, "Can only initialize once");
        require(_collaterals.length != 0, "At least one collateral required");
        require(_MCRs.length == _collaterals.length, "Array lengths must match");
        require(_CCRs.length == _collaterals.length, "Array lenghts must match");
        
        for(uint256 i = 0; i < _collaterals.length; i++) {
            address collateral = _collaterals[i];
            checkContract(collateral);
            collaterals.push(collateral);

            Config storage config = collateralConfig[collateral];
            config.allowed = true;
            uint256 decimals = IERC20(collateral).decimals();
            config.decimals = decimals;

            require(_MCRs[i] >= MIN_ALLOWED_MCR, "MCR below allowed minimum");
            config.MCR = _MCRs[i];

            require(_CCRs[i] >= MIN_ALLOWED_CCR, "CCR below allowed minimum");
            config.CCR = _CCRs[i];

            emit CollateralWhitelisted(collateral, decimals, _MCRs[i], _CCRs[i]);
        }

        initialized = true;
    }

    // Admin function to lower the collateralization requirements for a particular collateral.
    // Can only lower, not increase.
    //
    // !!!PLEASE USE EXTREME CARE AND CAUTION. THIS IS IRREVERSIBLE!!!
    //
    // You probably don't want to do this unless a specific asset has proved itself through tough times.
    // Doing this irresponsibly can permanently harm the protocol.
    function updateCollateralRatios(
        address _collateral,
        uint256 _MCR,
        uint256 _CCR
    ) external onlyOwner checkCollateral(_collateral) {
        Config storage config = collateralConfig[_collateral];
        require(_MCR <= config.MCR, "Can only walk down the MCR");
        require(_CCR <= config.CCR, "Can only walk down the CCR");

        require(_MCR >= MIN_ALLOWED_MCR, "MCR below allowed minimum");
        config.MCR = _MCR;

        require(_CCR >= MIN_ALLOWED_CCR, "CCR below allowed minimum");
        config.CCR = _CCR;
        emit CollateralRatiosUpdated(_collateral, _MCR, _CCR);
    }

    function getAllowedCollaterals() external override view returns (address[] memory) {
        return collaterals;
    }

    function isCollateralAllowed(address _collateral) external override view returns (bool) {
        return collateralConfig[_collateral].allowed;
    }

    function getCollateralDecimals(
        address _collateral
    ) external override view checkCollateral(_collateral) returns (uint256) {
        return collateralConfig[_collateral].decimals;
    }

    function getCollateralMCR(
        address _collateral
    ) external override view checkCollateral(_collateral) returns (uint256) {
        return collateralConfig[_collateral].MCR;
    }

    function getCollateralCCR(
        address _collateral
    ) external override view checkCollateral(_collateral) returns (uint256) {
        return collateralConfig[_collateral].CCR;
    }

    modifier checkCollateral(address _collateral) {
        require(collateralConfig[_collateral].allowed, "Invalid collateral address");
        _;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ICollateralConfig.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/SafeERC20.sol";
import "./Dependencies/console.sol";

contract CollSurplusPool is Ownable, CheckContract, ICollSurplusPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string constant public NAME = "CollSurplusPool";

    address public collateralConfigAddress;
    address public borrowerOperationsAddress;
    address public troveManagerAddress;
    address public activePoolAddress;

    // collateral => amount tracker
    mapping (address => uint256) internal collAmount;
    // Collateral surplus claimable by trove owners (address => collateral => amount)
    mapping (address => mapping (address => uint)) internal balances;

    // --- Events ---

    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _newActivePoolAddress);

    event CollBalanceUpdated(address indexed _account, address _collateral, uint _newBalance);
    event CollateralSent(address _collateral, address _to, uint _amount);
    
    // --- Contract setters ---

    function setAddresses(
        address _collateralConfigAddress,
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _activePoolAddress
    )
        external
        override
        onlyOwner
    {
        checkContract(_collateralConfigAddress);
        checkContract(_borrowerOperationsAddress);
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);

        collateralConfigAddress = _collateralConfigAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;
        troveManagerAddress = _troveManagerAddress;
        activePoolAddress = _activePoolAddress;

        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);

        renounceOwnership();
    }

    /* Returns the collAmount state variable.
       Not necessarily equal to the raw collateral balance - collateral can be forcibly sent to contracts. */
    function getCollateral(address _collateral) external view override returns (uint) {
        _requireValidCollateralAddress(_collateral);
        return collAmount[_collateral];
    }

    function getUserCollateral(address _account, address _collateral) external view override returns (uint) {
        _requireValidCollateralAddress(_collateral);
        return balances[_account][_collateral];
    }

    // --- Pool functionality ---

    function accountSurplus(address _account, address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsTroveManager();

        uint newAmount = balances[_account][_collateral].add(_amount);
        balances[_account][_collateral] = newAmount;

        emit CollBalanceUpdated(_account, _collateral, newAmount);
    }

    function claimColl(address _account, address _collateral) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsBorrowerOperations();
        uint claimableColl = balances[_account][_collateral];
        require(claimableColl > 0, "CollSurplusPool: No collateral available to claim");

        balances[_account][_collateral] = 0;
        emit CollBalanceUpdated(_account, _collateral, 0);

        collAmount[_collateral] = collAmount[_collateral].sub(claimableColl);
        emit CollateralSent(_collateral, _account, claimableColl);

        IERC20(_collateral).safeTransfer(_account, claimableColl);
    }

    function pullCollateralFromActivePool(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsActivePool();
        collAmount[_collateral] = collAmount[_collateral].add(_amount);

        IERC20(_collateral).safeTransferFrom(activePoolAddress, address(this), _amount);
    }

    // --- 'require' functions ---

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(
            ICollateralConfig(collateralConfigAddress).isCollateralAllowed(_collateral),
            "Invalid collateral address"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(
            msg.sender == borrowerOperationsAddress,
            "CollSurplusPool: Caller is not Borrower Operations");
    }

    function _requireCallerIsTroveManager() internal view {
        require(
            msg.sender == troveManagerAddress,
            "CollSurplusPool: Caller is not TroveManager");
    }

    function _requireCallerIsActivePool() internal view {
        require(
            msg.sender == activePoolAddress,
            "CollSurplusPool: Caller is not Active Pool");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/IActivePool.sol";
import "./Interfaces/ICollateralConfig.sol";
import './Interfaces/IDefaultPool.sol';
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/SafeERC20.sol";

/*
 * The Default Pool holds the collateral and LUSD debt for each collateral (but not LUSD tokens) from liquidations that have been redistributed
 * to active troves but not yet "applied", i.e. not yet recorded on a recipient active trove's struct.
 *
 * When a trove makes an operation that applies its pending collateral and LUSD debt, its pending collateral and LUSD debt is moved
 * from the Default Pool to the Active Pool.
 */
contract DefaultPool is Ownable, CheckContract, IDefaultPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string constant public NAME = "DefaultPool";

    address public collateralConfigAddress;
    address public troveManagerAddress;
    address public activePoolAddress;
    mapping (address => uint256) internal collAmount;  // collateral => amount tracker
    mapping (address => uint256) internal LUSDDebt;  // collateral => corresponding debt tracker

    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event DefaultPoolLUSDDebtUpdated(address _collateral, uint _LUSDDebt);
    event DefaultPoolCollateralBalanceUpdated(address _collateral, uint _amount);

    // --- Dependency setters ---

    function setAddresses(
        address _collateralConfigAddress,
        address _troveManagerAddress,
        address _activePoolAddress
    )
        external
        onlyOwner
    {
        checkContract(_collateralConfigAddress);
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);

        collateralConfigAddress = _collateralConfigAddress;
        troveManagerAddress = _troveManagerAddress;
        activePoolAddress = _activePoolAddress;

        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);

        renounceOwnership();
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the collAmount state variable.
    *
    * Not necessarily equal to the the contract's raw collateral balance - collateral can be forcibly sent to contracts.
    */
    function getCollateral(address _collateral) external view override returns (uint) {
        _requireValidCollateralAddress(_collateral);
        return collAmount[_collateral];
    }

    function getLUSDDebt(address _collateral) external view override returns (uint) {
        _requireValidCollateralAddress(_collateral);
        return LUSDDebt[_collateral];
    }

    // --- Pool functionality ---

    function sendCollateralToActivePool(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsTroveManager();
        address activePool = activePoolAddress; // cache to save an SLOAD
        collAmount[_collateral] = collAmount[_collateral].sub(_amount);
        emit DefaultPoolCollateralBalanceUpdated(_collateral, collAmount[_collateral]);
        emit CollateralSent(_collateral, activePool, _amount);

        IERC20(_collateral).safeIncreaseAllowance(activePool, _amount);
        IActivePool(activePoolAddress).pullCollateralFromBorrowerOperationsOrDefaultPool(_collateral, _amount);
    }

    function increaseLUSDDebt(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsTroveManager();
        LUSDDebt[_collateral] = LUSDDebt[_collateral].add(_amount);
        emit DefaultPoolLUSDDebtUpdated(_collateral, LUSDDebt[_collateral]);
    }

    function decreaseLUSDDebt(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsTroveManager();
        LUSDDebt[_collateral] = LUSDDebt[_collateral].sub(_amount);
        emit DefaultPoolLUSDDebtUpdated(_collateral, LUSDDebt[_collateral]);
    }

    function pullCollateralFromActivePool(address _collateral, uint _amount) external override {
        _requireValidCollateralAddress(_collateral);
        _requireCallerIsActivePool();
        collAmount[_collateral] = collAmount[_collateral].add(_amount);
        emit DefaultPoolCollateralBalanceUpdated(_collateral, collAmount[_collateral]);

        IERC20(_collateral).safeTransferFrom(activePoolAddress, address(this), _amount);
    }

    // --- 'require' functions ---

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(
            ICollateralConfig(collateralConfigAddress).isCollateralAllowed(_collateral),
            "Invalid collateral address"
        );
    }

    function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "DefaultPool: Caller is not the ActivePool");
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "DefaultPool: Caller is not the TroveManager");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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
        return functionCallWithValue(target, data, 0, errorMessage);
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
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
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

// SPDX-License-Identifier: BUSL-1.1
// Code from https://github.com/smartcontractkit/chainlink/blob/master/evm-contracts/src/v0.6/interfaces/AggregatorV3Interface.sol

pragma solidity 0.6.11;

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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.6.11;


contract BaseMath {
    uint constant public DECIMAL_PRECISION = 1e18;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;


contract CheckContract {
    /**
     * Check that the account is an already deployed non-destroyed contract.
     * See: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol#L12
     */
    function checkContract(address _account) internal view {
        require(_account != address(0), "Account cannot be zero address");

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(_account) }
        require(size > 0, "Account code size cannot be zero");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

// Buidler's helper contract for console logging
library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function log() internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log()"));
		ignored;
	}	function logInt(int p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(int)", p0));
		ignored;
	}

	function logUint(uint p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint)", p0));
		ignored;
	}

	function logString(string memory p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string)", p0));
		ignored;
	}

	function logBool(bool p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool)", p0));
		ignored;
	}

	function logAddress(address p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address)", p0));
		ignored;
	}

	function logBytes(bytes memory p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes)", p0));
		ignored;
	}

	function logByte(byte p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(byte)", p0));
		ignored;
	}

	function logBytes1(bytes1 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes1)", p0));
		ignored;
	}

	function logBytes2(bytes2 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes2)", p0));
		ignored;
	}

	function logBytes3(bytes3 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes3)", p0));
		ignored;
	}

	function logBytes4(bytes4 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes4)", p0));
		ignored;
	}

	function logBytes5(bytes5 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes5)", p0));
		ignored;
	}

	function logBytes6(bytes6 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes6)", p0));
		ignored;
	}

	function logBytes7(bytes7 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes7)", p0));
		ignored;
	}

	function logBytes8(bytes8 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes8)", p0));
		ignored;
	}

	function logBytes9(bytes9 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes9)", p0));
		ignored;
	}

	function logBytes10(bytes10 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes10)", p0));
		ignored;
	}

	function logBytes11(bytes11 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes11)", p0));
		ignored;
	}

	function logBytes12(bytes12 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes12)", p0));
		ignored;
	}

	function logBytes13(bytes13 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes13)", p0));
		ignored;
	}

	function logBytes14(bytes14 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes14)", p0));
		ignored;
	}

	function logBytes15(bytes15 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes15)", p0));
		ignored;
	}

	function logBytes16(bytes16 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes16)", p0));
		ignored;
	}

	function logBytes17(bytes17 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes17)", p0));
		ignored;
	}

	function logBytes18(bytes18 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes18)", p0));
		ignored;
	}

	function logBytes19(bytes19 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes19)", p0));
		ignored;
	}

	function logBytes20(bytes20 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes20)", p0));
		ignored;
	}

	function logBytes21(bytes21 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes21)", p0));
		ignored;
	}

	function logBytes22(bytes22 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes22)", p0));
		ignored;
	}

	function logBytes23(bytes23 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes23)", p0));
		ignored;
	}

	function logBytes24(bytes24 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes24)", p0));
		ignored;
	}

	function logBytes25(bytes25 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes25)", p0));
		ignored;
	}

	function logBytes26(bytes26 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes26)", p0));
		ignored;
	}

	function logBytes27(bytes27 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes27)", p0));
		ignored;
	}

	function logBytes28(bytes28 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes28)", p0));
		ignored;
	}

	function logBytes29(bytes29 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes29)", p0));
		ignored;
	}

	function logBytes30(bytes30 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes30)", p0));
		ignored;
	}

	function logBytes31(bytes31 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes31)", p0));
		ignored;
	}

	function logBytes32(bytes32 p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes32)", p0));
		ignored;
	}

	function log(uint p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint)", p0));
		ignored;
	}

	function log(string memory p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string)", p0));
		ignored;
	}

	function log(bool p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool)", p0));
		ignored;
	}

	function log(address p0) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address)", p0));
		ignored;
	}

	function log(uint p0, uint p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint)", p0, p1));
		ignored;
	}

	function log(uint p0, string memory p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string)", p0, p1));
		ignored;
	}

	function log(uint p0, bool p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool)", p0, p1));
		ignored;
	}

	function log(uint p0, address p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address)", p0, p1));
		ignored;
	}

	function log(string memory p0, uint p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint)", p0, p1));
		ignored;
	}

	function log(string memory p0, string memory p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string)", p0, p1));
		ignored;
	}

	function log(string memory p0, bool p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool)", p0, p1));
		ignored;
	}

	function log(string memory p0, address p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address)", p0, p1));
		ignored;
	}

	function log(bool p0, uint p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint)", p0, p1));
		ignored;
	}

	function log(bool p0, string memory p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string)", p0, p1));
		ignored;
	}

	function log(bool p0, bool p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool)", p0, p1));
		ignored;
	}

	function log(bool p0, address p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address)", p0, p1));
		ignored;
	}

	function log(address p0, uint p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint)", p0, p1));
		ignored;
	}

	function log(address p0, string memory p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string)", p0, p1));
		ignored;
	}

	function log(address p0, bool p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool)", p0, p1));
		ignored;
	}

	function log(address p0, address p1) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address)", p0, p1));
		ignored;
	}

	function log(uint p0, uint p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, uint p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, uint p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, string memory p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, bool p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, bool p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, bool p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, address p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, address p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, address p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, address p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, uint p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, bool p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, address p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, address p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
		ignored;
	}

	function log(string memory p0, address p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, uint p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, uint p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, uint p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, string memory p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, bool p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, bool p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, bool p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, address p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, address p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, address p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
		ignored;
	}

	function log(bool p0, address p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
		ignored;
	}

	function log(address p0, uint p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
		ignored;
	}

	function log(address p0, uint p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
		ignored;
	}

	function log(address p0, uint p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
		ignored;
	}

	function log(address p0, uint p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
		ignored;
	}

	function log(address p0, string memory p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
		ignored;
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
		ignored;
	}

	function log(address p0, string memory p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
		ignored;
	}

	function log(address p0, string memory p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
		ignored;
	}

	function log(address p0, bool p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
		ignored;
	}

	function log(address p0, bool p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
		ignored;
	}

	function log(address p0, bool p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
		ignored;
	}

	function log(address p0, bool p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
		ignored;
	}

	function log(address p0, address p1, uint p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
		ignored;
	}

	function log(address p0, address p1, string memory p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
		ignored;
	}

	function log(address p0, address p1, bool p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
		ignored;
	}

	function log(address p0, address p1, address p2) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
		ignored;
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
		ignored;
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		(bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
		ignored;
	}

}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

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
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

/**
 * Based on the OpenZeppelin IER20 interface:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol
 *
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
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

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

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    
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

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

/**
    * @dev EIP2362 Interface for pull oracles
    * https://github.com/tellor-io/EIP-2362
*/
interface IERC2362
{
	/**
	 * @dev Exposed function pertaining to EIP standards
	 * @param _id bytes32 ID of the query
	 * @return int,uint,uint returns the value, timestamp, and status code of query
	 */
	function valueFor(bytes32 _id) external view returns(int256,uint256,uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

/**
 * @dev Interface of the ERC2612 standard as defined in the EIP.
 *
 * Adds the {permit} method, which can be used to change one's
 * {IERC20-allowance} without having to send a transaction, by signing a
 * message. This allows users to spend tokens without having to hold Ether.
 *
 * See https://eips.ethereum.org/EIPS/eip-2612.
 * 
 * Code adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/pull/2237/
 */
interface IERC2612 {
    /**
     * @dev Sets `amount` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(address owner, address spender, uint256 amount, 
                    uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    
    /**
     * @dev Returns the current ERC2612 nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases `owner`'s nonce by one. This
     * prevents a signature from being used multiple times.
     *
     * `owner` can limit the time a Permit is valid for by setting `deadline` to 
     * a value in the near future. The deadline argument can be set to uint(-1) to 
     * create Permits that effectively never expire.
     */
    function nonces(address owner) external view returns (uint256);
    
    function version() external view returns (string memory);
    function permitTypeHash() external view returns (bytes32);
    function domainSeparator() external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./IERC20.sol";

interface IERC4626 is IERC20 {
    function asset() external view returns (address assetTokenAddress);
    function totalAssets() external view returns (uint256 totalManagedAssets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function maxMint(address receiver) external view returns (uint256 maxShares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function maxRedeem(address owner) external view returns (uint256 maxShares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface IMappingContract{
    function getTellorID(bytes32 _id) external view returns(bytes32);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

interface ITellor {
    //Controller
    function addresses(bytes32) external view returns (address);

    function uints(bytes32) external view returns (uint256);

    function burn(uint256 _amount) external;

    function changeDeity(address _newDeity) external;

    function changeOwner(address _newOwner) external;
    function changeUint(bytes32 _target, uint256 _amount) external;

    function migrate() external;

    function mint(address _reciever, uint256 _amount) external;

    function init() external;

    function getAllDisputeVars(uint256 _disputeId)
        external
        view
        returns (
            bytes32,
            bool,
            bool,
            bool,
            address,
            address,
            address,
            uint256[9] memory,
            int256
        );

    function getDisputeIdByDisputeHash(bytes32 _hash)
        external
        view
        returns (uint256);

    function getDisputeUintVars(uint256 _disputeId, bytes32 _data)
        external
        view
        returns (uint256);

    function getLastNewValueById(uint256 _requestId)
        external
        view
        returns (uint256, bool);

    function retrieveData(uint256 _requestId, uint256 _timestamp)
        external
        view
        returns (uint256);

    function getNewValueCountbyRequestId(uint256 _requestId)
        external
        view
        returns (uint256);

    function getAddressVars(bytes32 _data) external view returns (address);

    function getUintVar(bytes32 _data) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function isMigrated(address _addy) external view returns (bool);

    function allowance(address _user, address _spender)
        external
        view
        returns (uint256);

    function allowedToTrade(address _user, uint256 _amount)
        external
        view
        returns (bool);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function approveAndTransferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function balanceOf(address _user) external view returns (uint256);

    function balanceOfAt(address _user, uint256 _blockNumber)
        external
        view
        returns (uint256);

    function transfer(address _to, uint256 _amount)
        external
        returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool success);

    function depositStake() external;

    function requestStakingWithdraw() external;

    function withdrawStake() external;

    function changeStakingStatus(address _reporter, uint256 _status) external;

    function slashReporter(address _reporter, address _disputer) external;

    function getStakerInfo(address _staker)
        external
        view
        returns (uint256, uint256);

    function getTimestampbyRequestIDandIndex(uint256 _requestId, uint256 _index)
        external
        view
        returns (uint256);

    function getNewCurrentVariables()
        external
        view
        returns (
            bytes32 _c,
            uint256[5] memory _r,
            uint256 _d,
            uint256 _t
        );

    function getNewValueCountbyQueryId(bytes32 _queryId)
        external
        view
        returns (uint256);

    function getTimestampbyQueryIdandIndex(bytes32 _queryId, uint256 _index)
        external
        view
        returns (uint256);

    function retrieveData(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bytes memory);

    //Governance
    enum VoteResult {
        FAILED,
        PASSED,
        INVALID
    }

    function setApprovedFunction(bytes4 _func, bool _val) external;

    function beginDispute(bytes32 _queryId, uint256 _timestamp) external;

    function delegate(address _delegate) external;

    function delegateOfAt(address _user, uint256 _blockNumber)
        external
        view
        returns (address);

    function executeVote(uint256 _disputeId) external;

    function proposeVote(
        address _contract,
        bytes4 _function,
        bytes calldata _data,
        uint256 _timestamp
    ) external;

    function tallyVotes(uint256 _disputeId) external;

    function governance() external view returns (address);

    function updateMinDisputeFee() external;

    function verify() external pure returns (uint256);

    function vote(
        uint256 _disputeId,
        bool _supports,
        bool _invalidQuery
    ) external;

    function voteFor(
        address[] calldata _addys,
        uint256 _disputeId,
        bool _supports,
        bool _invalidQuery
    ) external;

    function getDelegateInfo(address _holder)
        external
        view
        returns (address, uint256);

    function isFunctionApproved(bytes4 _func) external view returns (bool);

    function isApprovedGovernanceContract(address _contract)
        external
        returns (bool);

    function getVoteRounds(bytes32 _hash)
        external
        view
        returns (uint256[] memory);

    function getVoteCount() external view returns (uint256);

    function getVoteInfo(uint256 _disputeId)
        external
        view
        returns (
            bytes32,
            uint256[9] memory,
            bool[2] memory,
            VoteResult,
            bytes memory,
            bytes4,
            address[2] memory
        );

    function getDisputeInfo(uint256 _disputeId)
        external
        view
        returns (
            uint256,
            uint256,
            bytes memory,
            address
        );

    function getOpenDisputesOnId(bytes32 _queryId)
        external
        view
        returns (uint256);

    function didVote(uint256 _disputeId, address _voter)
        external
        view
        returns (bool);

    //Oracle
    function getReportTimestampByIndex(bytes32 _queryId, uint256 _index)
        external
        view
        returns (uint256);

    function getValueByTimestamp(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bytes memory);

    function getBlockNumberByTimestamp(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (uint256);

    function getReportingLock() external view returns (uint256);

    function getReporterByTimestamp(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (address);

    function reportingLock() external view returns (uint256);

    function removeValue(bytes32 _queryId, uint256 _timestamp) external;
    function getTipsByUser(address _user) external view returns(uint256);
    function tipQuery(bytes32 _queryId, uint256 _tip, bytes memory _queryData) external;
    function submitValue(bytes32 _queryId, bytes calldata _value, uint256 _nonce, bytes memory _queryData) external;
    function burnTips() external;

    function changeReportingLock(uint256 _newReportingLock) external;
    function getReportsSubmittedByAddress(address _reporter) external view returns(uint256);
    function changeTimeBasedReward(uint256 _newTimeBasedReward) external;
    function getReporterLastTimestamp(address _reporter) external view returns(uint256);
    function getTipsById(bytes32 _queryId) external view returns(uint256);
    function getTimeBasedReward() external view returns(uint256);
    function getTimestampCountById(bytes32 _queryId) external view returns(uint256);
    function getTimestampIndexByTimestamp(bytes32 _queryId, uint256 _timestamp) external view returns(uint256);
    function getCurrentReward(bytes32 _queryId) external view returns(uint256, uint256);
    function getCurrentValue(bytes32 _queryId) external view returns(bytes memory);
    function getDataBefore(bytes32 _queryId, uint256 _timestamp) external view returns(bool _ifRetrieve, bytes memory _value, uint256 _timestampRetrieved);
    function getTimeOfLastNewValue() external view returns(uint256);
    function depositStake(uint256 _amount) external;
    function requestStakingWithdraw(uint256 _amount) external;

    //Test functions
    function changeAddressVar(bytes32 _id, address _addy) external;

    //parachute functions
    function killContract() external;

    function migrateFor(address _destination, uint256 _amount) external;

    function rescue51PercentAttack(address _tokenHolder) external;

    function rescueBrokenDataReporting() external;

    function rescueFailedUpdate() external;

    //Tellor 360
    function addStakingRewards(uint256 _amount) external;

    function _sliceUint(bytes memory _b)
        external
        pure
        returns (uint256 _number);

    function claimOneTimeTip(bytes32 _queryId, uint256[] memory _timestamps)
        external;

    function claimTip(
        bytes32 _feedId,
        bytes32 _queryId,
        uint256[] memory _timestamps
    ) external;

    function fee() external view returns (uint256);

    function feedsWithFunding(uint256) external view returns (bytes32);

    function fundFeed(
        bytes32 _feedId,
        bytes32 _queryId,
        uint256 _amount
    ) external;

    function getCurrentFeeds(bytes32 _queryId)
        external
        view
        returns (bytes32[] memory);

    function getCurrentTip(bytes32 _queryId) external view returns (uint256);

    function getDataAfter(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bytes memory _value, uint256 _timestampRetrieved);

    function getDataFeed(bytes32 _feedId)
        external
        view
        returns (Autopay.FeedDetails memory);

    function getFundedFeeds() external view returns (bytes32[] memory);

    function getFundedQueryIds() external view returns (bytes32[] memory);

    function getIndexForDataAfter(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bool _found, uint256 _index);

    function getIndexForDataBefore(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bool _found, uint256 _index);

    function getMultipleValuesBefore(
        bytes32 _queryId,
        uint256 _timestamp,
        uint256 _maxAge,
        uint256 _maxCount
    )
        external
        view
        returns (uint256[] memory _values, uint256[] memory _timestamps);

    function getPastTipByIndex(bytes32 _queryId, uint256 _index)
        external
        view
        returns (Autopay.Tip memory);

    function getPastTipCount(bytes32 _queryId) external view returns (uint256);

    function getPastTips(bytes32 _queryId)
        external
        view
        returns (Autopay.Tip[] memory);

    function getQueryIdFromFeedId(bytes32 _feedId)
        external
        view
        returns (bytes32);

    function getRewardAmount(
        bytes32 _feedId,
        bytes32 _queryId,
        uint256[] memory _timestamps
    ) external view returns (uint256 _cumulativeReward);

    function getRewardClaimedStatus(
        bytes32 _feedId,
        bytes32 _queryId,
        uint256 _timestamp
    ) external view returns (bool);

    function getTipsByAddress(address _user) external view returns (uint256);

    function isInDispute(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bool);

    function queryIdFromDataFeedId(bytes32) external view returns (bytes32);

    function queryIdsWithFunding(uint256) external view returns (bytes32);

    function queryIdsWithFundingIndex(bytes32) external view returns (uint256);

    function setupDataFeed(
        bytes32 _queryId,
        uint256 _reward,
        uint256 _startTime,
        uint256 _interval,
        uint256 _window,
        uint256 _priceThreshold,
        uint256 _rewardIncreasePerSecond,
        bytes memory _queryData,
        uint256 _amount
    ) external;

    function tellor() external view returns (address);

    function tip(
        bytes32 _queryId,
        uint256 _amount,
        bytes memory _queryData
    ) external;

    function tips(bytes32, uint256)
        external
        view
        returns (uint256 amount, uint256 timestamp);

    function token() external view returns (address);

    function userTipsTotal(address) external view returns (uint256);

    function valueFor(bytes32 _id)
        external
        view
        returns (
            int256 _value,
            uint256 _timestamp,
            uint256 _statusCode
        );
}

interface Autopay {
    struct FeedDetails {
        uint256 reward;
        uint256 balance;
        uint256 startTime;
        uint256 interval;
        uint256 window;
        uint256 priceThreshold;
        uint256 rewardIncreasePerSecond;
        uint256 feedsWithFundingIndex;
    }

    struct Tip {
        uint256 amount;
        uint256 timestamp;
    }
    function getStakeAmount() external view returns(uint256);
    function stakeAmount() external view returns(uint256);
    function token() external view returns(address);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./BaseMath.sol";
import "./LiquityMath.sol";
import "../Interfaces/IActivePool.sol";
import "../Interfaces/IDefaultPool.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ILiquityBase.sol";

/* 
* Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
* common functions. 
*/
contract LiquityBase is BaseMath, ILiquityBase {
    using SafeMath for uint;

    uint constant public _100pct = 1000000000000000000; // 1e18 == 100%

    // Amount of LUSD to be locked in gas pool on opening troves
    uint constant public LUSD_GAS_COMPENSATION = 1e18;

    // Minimum amount of net LUSD debt a trove must have
    uint constant public MIN_NET_DEBT = 9e18;
    // uint constant public MIN_NET_DEBT = 0; 

    uint constant public PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    uint constant public BORROWING_FEE_FLOOR = DECIMAL_PRECISION / 1000 * 5; // 0.5%

    IActivePool public activePool;

    IDefaultPool public defaultPool;

    IPriceFeed public override priceFeed;

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a trove, for the purpose of ICR calculation
    function _getCompositeDebt(uint _debt) internal pure returns (uint) {
        return _debt.add(LUSD_GAS_COMPENSATION);
    }

    function _getNetDebt(uint _debt) internal pure returns (uint) {
        return _debt.sub(LUSD_GAS_COMPENSATION);
    }

    // Return the amount of ETH to be drawn from a trove's collateral and sent as gas compensation.
    function _getCollGasCompensation(uint _entireColl) internal pure returns (uint) {
        return _entireColl / PERCENT_DIVISOR;
    }

    function getEntireSystemColl(address _collateral) public view returns (uint entireSystemColl) {
        uint activeColl = activePool.getCollateral(_collateral);
        uint liquidatedColl = defaultPool.getCollateral(_collateral);

        return activeColl.add(liquidatedColl);
    }

    function getEntireSystemDebt(address _collateral) public view returns (uint entireSystemDebt) {
        uint activeDebt = activePool.getLUSDDebt(_collateral);
        uint closedDebt = defaultPool.getLUSDDebt(_collateral);

        return activeDebt.add(closedDebt);
    }

    function _getTCR(address _collateral, uint _price, uint256 _collateralDecimals) internal view returns (uint TCR) {
        uint entireSystemColl = getEntireSystemColl(_collateral);
        uint entireSystemDebt = getEntireSystemDebt(_collateral);

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price, _collateralDecimals);

        return TCR;
    }

    function _checkRecoveryMode(
        address _collateral,
        uint _price,
        uint256 _CCR,
        uint256 _collateralDecimals
    ) internal view returns (bool) {
        uint TCR = _getTCR(_collateral, _price, _collateralDecimals);

        return TCR < _CCR;
    }

    function _requireUserAcceptsFee(uint _fee, uint _amount, uint _maxFeePercentage) internal pure {
        uint feePercentage = _fee.mul(DECIMAL_PRECISION).div(_amount);
        require(feePercentage <= _maxFeePercentage, "Fee exceeded provided maximum");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./SafeMath.sol";
import "./console.sol";

library LiquityMath {
    using SafeMath for uint;

    // Collateral decimals used for calculating collateralization ratios (CRs).
    // If collateral has > 18 decimals, its value is scaled down for CR calculation purposes.
    // If collateral has < 18 decimals, its value is scaled up for CR calculation purposes.
    uint256 internal constant CR_CALCULATION_DECIMALS = 18;

    uint internal constant DECIMAL_PRECISION = 1e18;

    /* Precision for Nominal ICR (independent of price). Rationale for the value:
     *
     * - Making it “too high” could lead to overflows.
     * - Making it “too low” could lead to an ICR equal to zero, due to truncation from Solidity floor division. 
     *
     * This value of 1e20 is chosen for safety: the NICR will only overflow for numerator > ~1e39 ETH,
     * and will only truncate to 0 if the denominator is at least 1e20 times greater than the numerator.
     *
     */
    uint internal constant NICR_PRECISION = 1e20;

    function _min(uint _a, uint _b) internal pure returns (uint) {
        return (_a < _b) ? _a : _b;
    }

    function _max(uint _a, uint _b) internal pure returns (uint) {
        return (_a >= _b) ? _a : _b;
    }

    /* 
    * Multiply two decimal numbers and use normal rounding rules:
    * -round product up if 19'th mantissa digit >= 5
    * -round product down if 19'th mantissa digit < 5
    *
    * Used only inside the exponentiation, _decPow().
    */
    function decMul(uint x, uint y) internal pure returns (uint decProd) {
        uint prod_xy = x.mul(y);

        decProd = prod_xy.add(DECIMAL_PRECISION / 2).div(DECIMAL_PRECISION);
    }

    /* 
    * _decPow: Exponentiation function for 18-digit decimal base, and integer exponent n.
    * 
    * Uses the efficient "exponentiation by squaring" algorithm. O(log(n)) complexity. 
    * 
    * Called by two functions that represent time in units of minutes:
    * 1) TroveManager._calcDecayedBaseRate
    * 2) CommunityIssuance._getCumulativeIssuanceFraction 
    * 
    * The exponent is capped to avoid reverting due to overflow. The cap 525600000 equals
    * "minutes in 1000 years": 60 * 24 * 365 * 1000
    * 
    * If a period of > 1000 years is ever used as an exponent in either of the above functions, the result will be
    * negligibly different from just passing the cap, since: 
    *
    * In function 1), the decayed base rate will be 0 for 1000 years or > 1000 years
    * In function 2), the difference in tokens issued at 1000 years and any time > 1000 years, will be negligible
    */
    function _decPow(uint _base, uint _minutes) internal pure returns (uint) {
       
        if (_minutes > 525600000) {_minutes = 525600000;}  // cap to avoid overflow
    
        if (_minutes == 0) {return DECIMAL_PRECISION;}

        uint y = DECIMAL_PRECISION;
        uint x = _base;
        uint n = _minutes;

        // Exponentiation-by-squaring
        while (n > 1) {
            if (n % 2 == 0) {
                x = decMul(x, x);
                n = n.div(2);
            } else { // if (n % 2 != 0)
                y = decMul(x, y);
                x = decMul(x, x);
                n = (n.sub(1)).div(2);
            }
        }

        return decMul(x, y);
  }

    function _getAbsoluteDifference(uint _a, uint _b) internal pure returns (uint) {
        return (_a >= _b) ? _a.sub(_b) : _b.sub(_a);
    }

    function _computeNominalCR(uint _coll, uint _debt, uint256 _collDecimals) internal pure returns (uint) {
        if (_debt > 0) {
            uint256 scaledColl = _getScaledCollAmount(_coll, _collDecimals);
            return scaledColl.mul(NICR_PRECISION).div(_debt);
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else { // if (_debt == 0)
            return 2**256 - 1;
        }
    }

    function _computeCR(uint _coll, uint _debt, uint _price, uint _collDecimals) internal pure returns (uint) {
        if (_debt > 0) {
            uint256 scaledColl = _getScaledCollAmount(_coll, _collDecimals);
            uint newCollRatio = scaledColl.mul(_price).div(_debt);

            return newCollRatio;
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else { // if (_debt == 0)
            return 2**256 - 1; 
        }
    }

    function _getScaledCollAmount(uint256 _collAmount, uint256 _collDecimals) internal pure returns (uint256 scaledColl) {
        scaledColl = _collAmount;
        if (_collDecimals > CR_CALCULATION_DECIMALS) {
            scaledColl = scaledColl.div(10 ** (_collDecimals - CR_CALCULATION_DECIMALS));
        } else if (_collDecimals < CR_CALCULATION_DECIMALS) {
            scaledColl = scaledColl.mul(10 ** (CR_CALCULATION_DECIMALS - _collDecimals));
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

// uint128 addition and subtraction, with overflow protection.

library LiquitySafeMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128) {
        uint128 c = a + b;
        require(c >= a, "LiquitySafeMath128: addition overflow");

        return c;
    }
   
    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "LiquitySafeMath128: subtraction overflow");
        uint128 c = a - b;

        return c;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Context.sol";
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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Address.sol";
import "./IERC20.sol";
import "./SafeMath.sol";

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

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

/**
 * Based on OpenZeppelin's SafeMath:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
 *
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
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "../Interfaces/ITellorCaller.sol";
import "./ITellor.sol";
import "./SafeMath.sol";
import "./UsingTellor.sol";
/*
* This contract has a single external function that calls Tellor: getTellorCurrentValue(). 
*
* The function is called by the Liquity contract PriceFeed.sol. If any of its inner calls to Tellor revert, 
* this function will revert, and PriceFeed will catch the failure and handle it accordingly.
*
* The function comes from Tellor's own wrapper contract, 'UsingTellor.sol':
* https://github.com/tellor-io/usingtellor/blob/master/contracts/UsingTellor.sol
*
*/
contract TellorCaller is UsingTellor, ITellorCaller {
    using SafeMath for uint256;

    constructor (address payable _tellorMasterAddress) UsingTellor(_tellorMasterAddress) public {}

    /*
    * getTellorCurrentValue(): identical to getCurrentValue() in UsingTellor.sol
    *
    * @dev Allows the user to get the latest value for the queryId specified
    * @param _queryId is the queryId to look up the value for
    * @return ifRetrieve bool true if it is able to retrieve a value, the value, and the value's timestamp
    * @return value the value retrieved
    * @return _timestampRetrieved the value's timestamp
    */
    function getTellorCurrentValue(bytes32 _queryId)
        external
        view
        override
        returns (
            bool ifRetrieve,
            uint256 value,
            uint256 _timestampRetrieved
        )
    {
        (bytes memory data, uint256 timestamp) = getDataBefore(_queryId, block.timestamp - 20 minutes);
        uint256 _value = abi.decode(data, (uint256));
        if (timestamp == 0 || _value == 0) return (false, _value, timestamp);
        return (true, _value, timestamp);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./ITellor.sol";
import "./IERC2362.sol";
import "./IMappingContract.sol";

/**
 @author Tellor Inc
 @title UsingTellor
 @dev This contract helps smart contracts read data from Tellor
 */
contract UsingTellor is IERC2362 {
    ITellor public tellor;
    IMappingContract public idMappingContract;

    /*Constructor*/
    /**
     * @dev the constructor sets the oracle address in storage
     * @param _tellor is the Tellor Oracle address
     */
    constructor(address payable _tellor) public {
        tellor = ITellor(_tellor);
    }

    /*Getters*/
    /**
     * @dev Retrieves the next value for the queryId after the specified timestamp
     * @param _queryId is the queryId to look up the value for
     * @param _timestamp after which to search for next value
     * @return _value the value retrieved
     * @return _timestampRetrieved the value's timestamp
     */
    function getDataAfter(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bytes memory _value, uint256 _timestampRetrieved)
    {
        (bool _found, uint256 _index) = getIndexForDataAfter(
            _queryId,
            _timestamp
        );
        if (!_found) {
            return ("", 0);
        }
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, _index);
        _value = retrieveData(_queryId, _timestampRetrieved);
        return (_value, _timestampRetrieved);
    }

    /**
     * @dev Retrieves the latest value for the queryId before the specified timestamp
     * @param _queryId is the queryId to look up the value for
     * @param _timestamp before which to search for latest value
     * @return _value the value retrieved
     * @return _timestampRetrieved the value's timestamp
     */
    function getDataBefore(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bytes memory _value, uint256 _timestampRetrieved)
    {
        (, _value, _timestampRetrieved) = tellor.getDataBefore(
            _queryId,
            _timestamp
        );
    }

    /**
     * @dev Retrieves latest array index of data before the specified timestamp for the queryId
     * @param _queryId is the queryId to look up the index for
     * @param _timestamp is the timestamp before which to search for the latest index
     * @return _found whether the index was found
     * @return _index the latest index found before the specified timestamp
     */
    // slither-disable-next-line calls-loop
    function getIndexForDataAfter(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bool _found, uint256 _index)
    {
        uint256 _count = getNewValueCountbyQueryId(_queryId);
        if (_count == 0) return (false, 0);
        _count--;
        bool _search = true; // perform binary search
        uint256 _middle = 0;
        uint256 _start = 0;
        uint256 _end = _count;
        uint256 _timestampRetrieved;
        // checking boundaries to short-circuit the algorithm
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, _end);
        if (_timestampRetrieved <= _timestamp) return (false, 0);
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, _start);
        if (_timestampRetrieved > _timestamp) {
            // candidate found, check for disputes
            _search = false;
        }
        // since the value is within our boundaries, do a binary search
        while (_search) {
            _middle = (_end + _start) / 2;
            _timestampRetrieved = getTimestampbyQueryIdandIndex(
                _queryId,
                _middle
            );
            if (_timestampRetrieved > _timestamp) {
                // get immediate previous value
                uint256 _prevTime = getTimestampbyQueryIdandIndex(
                    _queryId,
                    _middle - 1
                );
                if (_prevTime <= _timestamp) {
                    // candidate found, check for disputes
                    _search = false;
                } else {
                    // look from start to middle -1(prev value)
                    _end = _middle - 1;
                }
            } else {
                // get immediate next value
                uint256 _nextTime = getTimestampbyQueryIdandIndex(
                    _queryId,
                    _middle + 1
                );
                if (_nextTime > _timestamp) {
                    // candidate found, check for disputes
                    _search = false;
                    _middle++;
                    _timestampRetrieved = _nextTime;
                } else {
                    // look from middle + 1(next value) to end
                    _start = _middle + 1;
                }
            }
        }
        // candidate found, check for disputed values
        if (!isInDispute(_queryId, _timestampRetrieved)) {
            // _timestampRetrieved is correct
            return (true, _middle);
        } else {
            // iterate forward until we find a non-disputed value
            while (
                isInDispute(_queryId, _timestampRetrieved) && _middle < _count
            ) {
                _middle++;
                _timestampRetrieved = getTimestampbyQueryIdandIndex(
                    _queryId,
                    _middle
                );
            }
            if (
                _middle == _count && isInDispute(_queryId, _timestampRetrieved)
            ) {
                return (false, 0);
            }
            // _timestampRetrieved is correct
            return (true, _middle);
        }
    }

    /**
     * @dev Retrieves latest array index of data before the specified timestamp for the queryId
     * @param _queryId is the queryId to look up the index for
     * @param _timestamp is the timestamp before which to search for the latest index
     * @return _found whether the index was found
     * @return _index the latest index found before the specified timestamp
     */
    // slither-disable-next-line calls-loop
    function getIndexForDataBefore(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bool _found, uint256 _index)
    {
        return tellor.getIndexForDataBefore(_queryId, _timestamp);
    }

    /**
     * @dev Retrieves multiple uint256 values before the specified timestamp
     * @param _queryId the unique id of the data query
     * @param _timestamp the timestamp before which to search for values
     * @param _maxAge the maximum number of seconds before the _timestamp to search for values
     * @param _maxCount the maximum number of values to return
     * @return _values the values retrieved, ordered from oldest to newest
     * @return _timestamps the timestamps of the values retrieved
     */
    function getMultipleValuesBefore(
        bytes32 _queryId,
        uint256 _timestamp,
        uint256 _maxAge,
        uint256 _maxCount
    )
        public
        view
        returns (bytes[] memory _values, uint256[] memory _timestamps)
    {
        // get index of first possible value
        (bool _ifRetrieve, uint256 _startIndex) = getIndexForDataAfter(
            _queryId,
            _timestamp - _maxAge
        );
        // no value within range
        if (!_ifRetrieve) {
            return (new bytes[](0), new uint256[](0));
        }
        uint256 _endIndex;
        // get index of last possible value
        (_ifRetrieve, _endIndex) = getIndexForDataBefore(_queryId, _timestamp);
        // no value before _timestamp
        if (!_ifRetrieve) {
            return (new bytes[](0), new uint256[](0));
        }
        uint256 _valCount = 0;
        uint256 _index = 0;
        uint256[] memory _timestampsArrayTemp = new uint256[](_maxCount);
        // generate array of non-disputed timestamps within range
        while (_valCount < _maxCount && _endIndex + 1 - _index > _startIndex) {
            uint256 _timestampRetrieved = getTimestampbyQueryIdandIndex(
                _queryId,
                _endIndex - _index
            );
            if (!isInDispute(_queryId, _timestampRetrieved)) {
                _timestampsArrayTemp[_valCount] = _timestampRetrieved;
                _valCount++;
            }
            _index++;
        }

        bytes[] memory _valuesArray = new bytes[](_valCount);
        uint256[] memory _timestampsArray = new uint256[](_valCount);
        // retrieve values and reverse timestamps order
        for (uint256 _i = 0; _i < _valCount; _i++) {
            _timestampsArray[_i] = _timestampsArrayTemp[_valCount - 1 - _i];
            _valuesArray[_i] = retrieveData(_queryId, _timestampsArray[_i]);
        }
        return (_valuesArray, _timestampsArray);
    }

    /**
     * @dev Counts the number of values that have been submitted for the queryId
     * @param _queryId the id to look up
     * @return uint256 count of the number of values received for the queryId
     */
    function getNewValueCountbyQueryId(bytes32 _queryId)
        public
        view
        returns (uint256)
    {
        return tellor.getNewValueCountbyQueryId(_queryId);
    }

    /**
     * @dev Returns the address of the reporter who submitted a value for a data ID at a specific time
     * @param _queryId is ID of the specific data feed
     * @param _timestamp is the timestamp to find a corresponding reporter for
     * @return address of the reporter who reported the value for the data ID at the given timestamp
     */
    function getReporterByTimestamp(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (address)
    {
        return tellor.getReporterByTimestamp(_queryId, _timestamp);
    }

    /**
     * @dev Gets the timestamp for the value based on their index
     * @param _queryId is the id to look up
     * @param _index is the value index to look up
     * @return uint256 timestamp
     */
    function getTimestampbyQueryIdandIndex(bytes32 _queryId, uint256 _index)
        public
        view
        returns (uint256)
    {
        return tellor.getTimestampbyQueryIdandIndex(_queryId, _index);
    }

    /**
     * @dev Determines whether a value with a given queryId and timestamp has been disputed
     * @param _queryId is the value id to look up
     * @param _timestamp is the timestamp of the value to look up
     * @return bool true if queryId/timestamp is under dispute
     */
    function isInDispute(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bool)
    {
        return tellor.isInDispute(_queryId, _timestamp);
    }

    /**
     * @dev Retrieve value from oracle based on queryId/timestamp
     * @param _queryId being requested
     * @param _timestamp to retrieve data/value from
     * @return bytes value for query/timestamp submitted
     */
    function retrieveData(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bytes memory)
    {
        return tellor.retrieveData(_queryId, _timestamp);
    }

    /**
     * @dev allows dev to set mapping contract for valueFor (EIP2362)
     * @param _addy address of mapping contract
     */
    function setIdMappingContract(address _addy) external {
        require(address(idMappingContract) == address(0));
        idMappingContract = IMappingContract(_addy);
    }

    /**
     * @dev Retrieve most recent int256 value from oracle based on queryId
     * @param _id being requested
     * @return _value most recent value submitted
     * @return _timestamp timestamp of most recent value
     * @return _statusCode 200 if value found, 404 if not found
     */
    function valueFor(bytes32 _id)
        external
        view
        override
        returns (
            int256 _value,
            uint256 _timestamp,
            uint256 _statusCode
        )
    {
        bytes32 _queryId = idMappingContract.getTellorID(_id);
        bytes memory _valueBytes;
        (_valueBytes, _timestamp) = getDataBefore(
            _queryId,
            block.timestamp + 1
        );
        if (_timestamp == 0) {
            return (0, 0, 404);
        }
        uint256 _valueUint = _sliceUint(_valueBytes);
        _value = int256(_valueUint);
        return (_value, _timestamp, 200);
    }

    // Internal functions
    /**
     * @dev Convert bytes to uint256
     * @param _b bytes value to convert to uint256
     * @return _number uint256 converted from bytes
     */
    function _sliceUint(bytes memory _b)
        internal
        pure
        returns (uint256 _number)
    {
        for (uint256 _i = 0; _i < _b.length; _i++) {
            _number = _number * 256 + uint8(_b[_i]);
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;


/**
 * The purpose of this contract is to hold LUSD tokens for gas compensation:
 * https://github.com/liquity/dev#gas-compensation
 * When a borrower opens a trove, an additional 50 LUSD debt is issued,
 * and 50 LUSD is minted and sent to this contract.
 * When a borrower closes their active trove, this gas compensation is refunded:
 * 50 LUSD is burned from the this contract's balance, and the corresponding
 * 50 LUSD debt on the trove is cancelled.
 * See this issue for more context: https://github.com/liquity/dev/issues/186
 */
contract GasPool {
    // do nothing, as the core contracts have permission to send to and burn from this address
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ICollateralConfig.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Dependencies/LiquityBase.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";

contract HintHelpers is LiquityBase, Ownable, CheckContract {
    string constant public NAME = "HintHelpers";

    ICollateralConfig public collateralConfig;
    ISortedTroves public sortedTroves;
    ITroveManager public troveManager;

    // --- Events ---

    event CollateralConfigAddressChanged(address _collateralConfigAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event TroveManagerAddressChanged(address _troveManagerAddress);

    // --- Dependency setters ---

    function setAddresses(
        address _collateralConfigAddress,
        address _sortedTrovesAddress,
        address _troveManagerAddress
    )
        external
        onlyOwner
    {
        checkContract(_collateralConfigAddress);
        checkContract(_sortedTrovesAddress);
        checkContract(_troveManagerAddress);

        collateralConfig = ICollateralConfig(_collateralConfigAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        troveManager = ITroveManager(_troveManagerAddress);

        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);

        renounceOwnership();
    }

    // --- Functions ---

    /* getRedemptionHints() - Helper function for finding the right hints to pass to redeemCollateral().
     *
     * It simulates a redemption of `_LUSDamount` to figure out where the redemption sequence will start and what state the final Trove
     * of the sequence will end up in.
     *
     * Returns three hints:
     *  - `firstRedemptionHint` is the address of the first Trove with ICR >= MCR (i.e. the first Trove that will be redeemed).
     *  - `partialRedemptionHintNICR` is the final nominal ICR of the last Trove of the sequence after being hit by partial redemption,
     *     or zero in case of no partial redemption.
     *  - `truncatedLUSDamount` is the maximum amount that can be redeemed out of the the provided `_LUSDamount`. This can be lower than
     *    `_LUSDamount` when redeeming the full amount would leave the last Trove of the redemption sequence with less net debt than the
     *    minimum allowed value (i.e. MIN_NET_DEBT).
     *
     * The number of Troves to consider for redemption can be capped by passing a non-zero value as `_maxIterations`, while passing zero
     * will leave it uncapped.
     */

    // Due to "stack too deep" error
    struct LocalVariables_getRedemptionHints {
        uint256 collDecimals;
        uint256 collMCR;
        uint remainingLUSD;
        ISortedTroves sortedTroves;
        address currentTroveuser;
        uint netLUSDDebt;
        uint maxRedeemableLUSD;
        uint collAmount;
        uint newColl;
        uint newDebt;
        uint compositeDebt;
    }

    function getRedemptionHints(
        address _collateral,
        uint _LUSDamount, 
        uint _price,
        uint _maxIterations
    )
        external
        view
        returns (
            address firstRedemptionHint,
            uint partialRedemptionHintNICR,
            uint truncatedLUSDamount
        )
    {
        _requireValidCollateralAddress(_collateral);
        LocalVariables_getRedemptionHints memory vars;

        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        vars.remainingLUSD = _LUSDamount;
        vars.sortedTroves = sortedTroves;
        vars.currentTroveuser = vars.sortedTroves.getLast(_collateral);

        while (
            vars.currentTroveuser != address(0) &&
            troveManager.getCurrentICR(vars.currentTroveuser, _collateral, _price) < vars.collMCR
        ) {
            vars.currentTroveuser = vars.sortedTroves.getPrev(_collateral, vars.currentTroveuser);
        }

        firstRedemptionHint = vars.currentTroveuser;

        if (_maxIterations == 0) {
            _maxIterations = uint(-1);
        }

        while (vars.currentTroveuser != address(0) && vars.remainingLUSD > 0 && _maxIterations-- > 0) {
            vars.netLUSDDebt = _getNetDebt(troveManager.getTroveDebt(vars.currentTroveuser, _collateral))
                .add(troveManager.getPendingLUSDDebtReward(vars.currentTroveuser, _collateral));

            if (vars.netLUSDDebt > vars.remainingLUSD) {
                if (vars.netLUSDDebt > MIN_NET_DEBT) {
                    vars.maxRedeemableLUSD = LiquityMath._min(vars.remainingLUSD, vars.netLUSDDebt.sub(MIN_NET_DEBT));

                    vars.collAmount = troveManager.getTroveColl(vars.currentTroveuser, _collateral)
                        .add(troveManager.getPendingCollateralReward(vars.currentTroveuser, _collateral));

                    vars.newColl = vars.collAmount.sub(vars.maxRedeemableLUSD.mul(10**vars.collDecimals).div(_price));
                    vars.newDebt = vars.netLUSDDebt.sub(vars.maxRedeemableLUSD);

                    vars.compositeDebt = _getCompositeDebt(vars.newDebt);
                    partialRedemptionHintNICR = LiquityMath._computeNominalCR(vars.newColl, vars.compositeDebt, vars.collDecimals);

                    vars.remainingLUSD = vars.remainingLUSD.sub(vars.maxRedeemableLUSD);
                }
                break;
            } else {
                vars.remainingLUSD = vars.remainingLUSD.sub(vars.netLUSDDebt);
            }

            vars.currentTroveuser = vars.sortedTroves.getPrev(_collateral, vars.currentTroveuser);
        }

        truncatedLUSDamount = _LUSDamount.sub(vars.remainingLUSD);
    }

    /* getApproxHint() - return address of a Trove that is, on average, (length / numTrials) positions away in the 
    sortedTroves list from the correct insert position of the Trove to be inserted. 
    
    Note: The output address is worst-case O(n) positions away from the correct insert position, however, the function 
    is probabilistic. Input can be tuned to guarantee results to a high degree of confidence, e.g:

    Submitting numTrials = k * sqrt(length), with k = 15 makes it very, very likely that the ouput address will 
    be <= sqrt(length) positions away from the correct insert position.
    */
    function getApproxHint(address _collateral, uint _CR, uint _numTrials, uint _inputRandomSeed)
        external
        view
        returns (address hintAddress, uint diff, uint latestRandomSeed)
    {
        _requireValidCollateralAddress(_collateral);
        uint arrayLength = troveManager.getTroveOwnersCount(_collateral);

        if (arrayLength == 0) {
            return (address(0), 0, _inputRandomSeed);
        }

        hintAddress = sortedTroves.getLast(_collateral);
        diff = LiquityMath._getAbsoluteDifference(_CR, troveManager.getNominalICR(hintAddress, _collateral));
        latestRandomSeed = _inputRandomSeed;

        uint i = 1;

        while (i < _numTrials) {
            latestRandomSeed = uint(keccak256(abi.encodePacked(latestRandomSeed)));

            uint arrayIndex = latestRandomSeed % arrayLength;
            address currentAddress = troveManager.getTroveFromTroveOwnersArray(_collateral, arrayIndex);
            uint currentNICR = troveManager.getNominalICR(currentAddress, _collateral);

            // check if abs(current - CR) > abs(closest - CR), and update closest if current is closer
            uint currentDiff = LiquityMath._getAbsoluteDifference(currentNICR, _CR);

            if (currentDiff < diff) {
                diff = currentDiff;
                hintAddress = currentAddress;
            }
            i++;
        }
    }

    function computeNominalCR(uint _coll, uint _debt, uint8 _collDecimals) external pure returns (uint) {
        return LiquityMath._computeNominalCR(_coll, _debt, _collDecimals);
    }

    function computeCR(uint _coll, uint _debt, uint _price, uint8 _collDecimals) external pure returns (uint) {
        return LiquityMath._computeCR(_coll, _debt, _price, _collDecimals);
    }

    // --- 'require' functions ---

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(collateralConfig.isCollateralAllowed(_collateral),"Invalid collateral address");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./IPool.sol";


interface IActivePool is IPool {
    // --- Events ---
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event ActivePoolLUSDDebtUpdated(address _collateral, uint _LUSDDebt);
    event ActivePoolCollateralBalanceUpdated(address _collateral, uint _amount);

    // --- Functions ---
    function sendCollateral(address _collateral, address _account, uint _amount) external;
    function pullCollateralFromBorrowerOperationsOrDefaultPool(address _collateral, uint _amount) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

// Common interface for the Trove Manager.
interface IBorrowerOperations {

    // --- Events ---

    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event PriceFeedAddressChanged(address  _newPriceFeedAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event LUSDTokenAddressChanged(address _lusdTokenAddress);
    event LQTYStakingAddressChanged(address _lqtyStakingAddress);

    event TroveCreated(address indexed _borrower, address _collateral, uint arrayIndex);
    event TroveUpdated(address indexed _borrower, address _collateral, uint _debt, uint _coll, uint stake, uint8 operation);
    event LUSDBorrowingFeePaid(address indexed _borrower, address _collateral, uint _LUSDFee);

    // --- Functions ---

    function setAddresses(
        address _collateralConfigAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _lusdTokenAddress,
        address _lqtyStakingAddress
    ) external;

    function openTrove(address _collateral, uint _collAmount, uint _maxFee, uint _LUSDAmount, address _upperHint, address _lowerHint) external;

    function addColl(address _collateral, uint _collAmount, address _upperHint, address _lowerHint) external;

    function moveCollateralGainToTrove(address _user, address _collateral, uint _collAmount, address _upperHint, address _lowerHint) external;

    function withdrawColl(address _collateral, uint _amount, address _upperHint, address _lowerHint) external;

    function withdrawLUSD(address _collateral, uint _maxFee, uint _amount, address _upperHint, address _lowerHint) external;

    function repayLUSD(address _collateral, uint _amount, address _upperHint, address _lowerHint) external;

    function closeTrove(address _collateral) external;

    function adjustTrove(address _collateral, uint _maxFee, uint _collTopUp, uint _collWithdrawal, uint _debtChange, bool isDebtIncrease, address _upperHint, address _lowerHint) external;

    function claimCollateral(address _collateral) external;

    function getCompositeDebt(uint _debt) external pure returns (uint);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface ICollateralConfig {
    function getAllowedCollaterals() external view returns (address[] memory);
    function getCollateralCCR(address _collateral) external view returns (uint256);
    function getCollateralDecimals(address _collateral) external view returns (uint256);
    function getCollateralMCR(address _collateral) external view returns (uint256);
    function initialize(address[] calldata _collaterals, uint256[] calldata _MCRs, uint256[] calldata _CCRs) external;
    function isCollateralAllowed(address _collateral) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;


interface ICollSurplusPool {

    // --- Events ---
    
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _newActivePoolAddress);

    event CollBalanceUpdated(address indexed _account, address _collateral, uint _newBalance);
    event CollateralSent(address _collateral, address _to, uint _amount);

    // --- Contract setters ---

    function setAddresses(
        address _collateralConfigAddress,
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _activePoolAddress
    ) external;

    function getCollateral(address _collateral) external view returns (uint);

    function getUserCollateral(address _account, address _collateral) external view returns (uint);

    function accountSurplus(address _account, address _collateral, uint _amount) external;

    function claimColl(address _account, address _collateral) external;

    function pullCollateralFromActivePool(address _collateral, uint _amount) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface ICommunityIssuance { 
    
    // --- Events ---
    
    event OATHTokenAddressSet(address _lqtyTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalOathIssuedUpdated(uint _totalLQTYIssued);

    // --- Functions ---

    function setAddresses(address _lqtyTokenAddress, address _stabilityPoolAddress) external;

    function issueOath() external returns (uint);

    function sendOath(address _account, uint _LQTYamount) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./IPool.sol";


interface IDefaultPool is IPool {
    // --- Events ---
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event DefaultPoolLUSDDebtUpdated(address _collateral, uint _LUSDDebt);
    event DefaultPoolCollateralBalanceUpdated(address _collateral, uint _amount);

    // --- Functions ---
    function sendCollateralToActivePool(address _collateral, uint _amount) external;
    function pullCollateralFromActivePool(address _collateral, uint _amount) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./IPriceFeed.sol";


interface ILiquityBase {
    function priceFeed() external view returns (IPriceFeed);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface ILQTYStaking {

    // --- Events --
    
    event LQTYTokenAddressSet(address _lqtyTokenAddress);
    event LUSDTokenAddressSet(address _lusdTokenAddress);
    event TroveManagerAddressSet(address _troveManager);
    event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    event ActivePoolAddressSet(address _activePoolAddress);
    event CollateralConfigAddressSet(address _collateralConfigAddress);

    event StakeChanged(address indexed staker, uint newStake);
    event StakingGainsWithdrawn(address indexed staker, uint LUSDGain, address[] _assets, uint[] _amounts);
    event F_CollateralUpdated(address _collateral, uint _F_Collateral);
    event F_LUSDUpdated(uint _F_LUSD);
    event TotalLQTYStakedUpdated(uint _totalLQTYStaked);
    event CollateralSent(address _account, address _collateral, uint _amount);
    event StakerSnapshotsUpdated(address _staker, address[] _assets, uint[] _amounts, uint _F_LUSD);

    // --- Functions ---

    function setAddresses
    (
        address _lqtyTokenAddress,
        address _lusdTokenAddress,
        address _troveManagerAddress, 
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _collateralConfigAddress
    )  external;

    function stake(uint _LQTYamount) external;

    function unstake(uint _LQTYamount) external;

    function increaseF_Collateral(address _collateral, uint _collFee) external;

    function increaseF_LUSD(uint _LQTYFee) external;  

    function getPendingCollateralGain(address _user) external view returns (address[] memory, uint[] memory);

    function getPendingLUSDGain(address _user) external view returns (uint);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "../Dependencies/IERC2612.sol";

interface ILUSDToken is IERC20, IERC2612 { 
    
    // --- Events ---

    event TroveManagerAddressChanged(address _troveManagerAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);

    event LUSDTokenBalanceUpdated(address _user, uint _amount);

    // --- Functions ---

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function sendToPool(address _sender,  address poolAddress, uint256 _amount) external;

    function returnFromPool(address poolAddress, address user, uint256 _amount ) external;

    function getDeploymentStartTime() external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

// Common interface for the Pools.
interface IPool {
    
    // --- Events ---
    
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event CollateralSent(address _collateral, address _to, uint _amount);

    // --- Functions ---
    
    function getCollateral(address _collateral) external view returns (uint);

    function getLUSDDebt(address _collateral) external view returns (uint);

    function increaseLUSDDebt(address _collateral, uint _amount) external;

    function decreaseLUSDDebt(address _collateral, uint _amount) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface IPriceFeed {

    // --- Events ---
    event LastGoodPriceUpdated(address _collateral, uint _lastGoodPrice);
   
    // --- Function ---
    function fetchPrice(address _collateral) external returns (uint);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface IRedemptionHelper {
    function redeemCollateral(
        address _collateral,
        address _redeemer,
        uint _LUSDamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFeePercentage
    ) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

// Common interface for the SortedTroves Doubly Linked List.
interface ISortedTroves {

    // --- Events ---
    
    event SortedTrovesAddressChanged(address _sortedDoublyLLAddress);
    event BorrowerOperationsAddressChanged(address _borrowerOperationsAddress);
    event NodeAdded(address _collateral, address _id, uint _NICR);
    event NodeRemoved(address _collateral, address _id);

    // --- Functions ---
    
    function setParams(address _TroveManagerAddress, address _borrowerOperationsAddress) external;

    function insert(address _collateral, address _id, uint256 _ICR, address _prevId, address _nextId) external;

    function remove(address _collateral, address _id) external;

    function reInsert(address _id, address _collateral, uint256 _newICR, address _prevId, address _nextId) external;

    function contains(address _collateral, address _id) external view returns (bool);

    function isEmpty(address _collateral) external view returns (bool);

    function getSize(address _collateral) external view returns (uint256);

    function getFirst(address _collateral) external view returns (address);

    function getLast(address _collateral) external view returns (address);

    function getNext(address _collateral, address _id) external view returns (address);

    function getPrev(address _collateral, address _id) external view returns (address);

    function validInsertPosition(address _collateral, uint256 _ICR, address _prevId, address _nextId) external view returns (bool);

    function findInsertPosition(address _collateral, uint256 _ICR, address _prevId, address _nextId) external view returns (address, address);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface IStabilityPool {

    // --- Events ---
    
    event StabilityPoolCollateralBalanceUpdated(address _collateral, uint _newBalance);
    event StabilityPoolLUSDBalanceUpdated(uint _newBalance);

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event LUSDTokenAddressChanged(address _newLUSDTokenAddress);
    event SortedTrovesAddressChanged(address _newSortedTrovesAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event CommunityIssuanceAddressChanged(address _newCommunityIssuanceAddress);

    event P_Updated(uint _P);
    event S_Updated(address _collateral, uint _S, uint128 _epoch, uint128 _scale);
    event G_Updated(uint _G, uint128 _epoch, uint128 _scale);
    event EpochUpdated(uint128 _currentEpoch);
    event ScaleUpdated(uint128 _currentScale);

    event DepositSnapshotUpdated(address indexed _depositor, uint _P, address[] _assets, uint[] _amounts, uint _G);
    event UserDepositChanged(address indexed _depositor, uint _newDeposit);

    event CollateralGainWithdrawn(address indexed _depositor, address _collateral, uint _collAmount);
    event LQTYPaidToDepositor(address indexed _depositor, uint _LQTY);
    event CollateralSent(address _collateral, address _to, uint _amount);

    // --- Functions ---

    /*
     * Called only once on init, to set addresses of other Liquity contracts
     * Callable only by owner, renounces ownership at the end
     */
    function setAddresses(
        address _borrowerOperationsAddress,
        address _collateralConfigAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _lusdTokenAddress,
        address _sortedTrovesAddress,
        address _priceFeedAddress,
        address _communityIssuanceAddress
    ) external;

    /*
     * Initial checks:
     * - _amount is not zero
     * ---
     * - Triggers a LQTY issuance, based on time passed since the last issuance. The LQTY issuance is shared between *all* depositors
     * - Sends depositor's accumulated gains (LQTY, ETH) to depositor
     * - Increases depositor's deposit, and takes new snapshot.
     */
    function provideToSP(uint _amount) external;

    /*
     * Initial checks:
     * - _amount is zero or there are no under collateralized troves left in the system
     * - User has a non zero deposit
     * ---
     * - Triggers a LQTY issuance, based on time passed since the last issuance. The LQTY issuance is shared between *all* depositors
     * - Sends all depositor's accumulated gains (LQTY, ETH) to depositor
     * - Decreases depositor's deposit, and takes new snapshot.
     *
     * If _amount > userDeposit, the user withdraws all of their compounded deposit.
     */
    function withdrawFromSP(uint _amount) external;

    /*
     * Initial checks:
     * - Caller is TroveManager
     * ---
     * Cancels out the specified debt against the LUSD contained in the Stability Pool (as far as possible)
     * and transfers the Trove's collateral from ActivePool to StabilityPool.
     * Only called by liquidation functions in the TroveManager.
     */
    function offset(address _collateral, uint _debt, uint _coll) external;

    /*
     * Initial checks:
     * - Caller is ActivePool
     * ---
     * Updates the reward sum for the specified collateral. A trimmed down version of "offset()" that doesn't
     * concern itself with any debt to offset or LUSD loss. Only called by ActivePool when distributing
     * yield farming rewards.
     */
    function updateRewardSum(address _collateral, uint _coll) external;

    /*
     * Returns the total amount of the specified collateral held by the pool, accounted in an internal variable.
     */
    function getCollateral(address _collateral) external view returns (uint);

    /*
     * Returns LUSD held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
     */
    function getTotalLUSDDeposits() external view returns (uint);

    /*
     * Calculates the collateral gain earned by the deposit since its last snapshots were taken.
     */
    function getDepositorCollateralGain(address _depositor) external view returns (address[] memory assets, uint[] memory amounts);

    /*
     * Calculate the LQTY gain earned by a deposit since its last snapshots were taken.
     * If not tagged with a front end, the depositor gets a 100% cut of what their deposit earned.
     * Otherwise, their cut of the deposit's earnings is equal to the kickbackRate, set by the front end through
     * which they made their deposit.
     */
    function getDepositorLQTYGain(address _depositor) external view returns (uint);

    /*
     * Return the user's compounded deposit.
     */
    function getCompoundedLUSDDeposit(address _depositor) external view returns (uint);

    /*
     * A depositor's snapshot struct now contains a mapping for the running sum (S) for each collateral.
     * Mappings within a struct are not accessible via the auto-generated getters in the ABI, so we provide
     * this separate function that will return the specified depositor's "S" snapshot for the given collateral.
     */
    function depositSnapshots_S(address _depositor, address _collateral) external view returns (uint);

    /*
     * Fallback function
     * Only callable by Active Pool, it just accounts for ETH received
     * receive() external payable;
     */
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

interface ITellorCaller {
    function getTellorCurrentValue(bytes32 _queryId) external view returns (bool, uint256, uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./ILiquityBase.sol";
import "./IStabilityPool.sol";
import "./ILUSDToken.sol";
import "./ILQTYStaking.sol";
import "./IRedemptionHelper.sol";
import "../Dependencies/IERC20.sol";


// Common interface for the Trove Manager.
interface ITroveManager is ILiquityBase {
    
    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event LUSDTokenAddressChanged(address _newLUSDTokenAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event LQTYTokenAddressChanged(address _lqtyTokenAddress);
    event LQTYStakingAddressChanged(address _lqtyStakingAddress);

    event Liquidation(address _collateral, uint _liquidatedDebt, uint _liquidatedColl, uint _collGasCompensation, uint _LUSDGasCompensation);
    event TroveUpdated(address indexed _borrower, address _collateral, uint _debt, uint _coll, uint _stake, uint8 _operation);
    event TroveLiquidated(address indexed _borrower, address _collateral, uint _debt, uint _coll, uint8 _operation);
    event BaseRateUpdated(uint _baseRate);
    event LastFeeOpTimeUpdated(uint _lastFeeOpTime);
    event TotalStakesUpdated(address _collateral, uint _newTotalStakes);
    event SystemSnapshotsUpdated(address _collateral, uint _totalStakesSnapshot, uint _totalCollateralSnapshot);
    event LTermsUpdated(address _collateral, uint _L_Collateral, uint _L_LUSDDebt);
    event TroveSnapshotsUpdated(address _collateral, uint _L_Collateral, uint _L_LUSDDebt);
    event TroveIndexUpdated(address _borrower, address _collateral, uint _newIndex);
    event Redemption(
        address _collateral,
        uint _attemptedLUSDAmount,
        uint _actualLUSDAmount,
        uint _collSent,
        uint _collFee
    );

    // --- Functions ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _collateralConfigAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _lusdTokenAddress,
        address _sortedTrovesAddress,
        address _lqtyTokenAddress,
        address _lqtyStakingAddress,
        address _redemptionHelperAddress
    ) external;

    function REDEMPTION_FEE_FLOOR() external pure returns (uint256);
    function stabilityPool() external view returns (IStabilityPool);
    function lusdToken() external view returns (ILUSDToken);
    function lqtyToken() external view returns (IERC20);
    function lqtyStaking() external view returns (ILQTYStaking);

    function getTroveOwnersCount(address _collateral) external view returns (uint);

    function getTroveFromTroveOwnersArray(address _collateral, uint _index) external view returns (address);

    function getNominalICR(address _borrower, address _collateral) external view returns (uint);
    function getCurrentICR(address _borrower, address _collateral, uint _price) external view returns (uint);

    function liquidate(address _borrower, address _collateral) external;

    function liquidateTroves(address _collateral, uint _n) external;

    function batchLiquidateTroves(address _collateral, address[] calldata _troveArray) external;

    function redeemCollateral(
        address _collateral,
        uint _LUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFee
    ) external;

    function redeemCloseTrove(address _borrower, address _collateral, uint256 _LUSD, uint256 _collAmount) external;

    function reInsert(address _id, address _collateral, uint256 _newNICR, address _prevId, address _nextId) external;

    function updateDebtAndCollAndStakesPostRedemption(
        address _borrower,
        address _collateral,
        uint256 _newDebt,
        uint256 _newColl
    ) external;

    function burnLUSDAndEmitRedemptionEvent(
        address _redeemer,
        address _collateral,
        uint _attemptedLUSDAmount,
        uint _actualLUSDAmount,
        uint _collSent,
        uint _collFee
    ) external;

    function updateBaseRateFromRedemption(
        uint _collateralDrawn,
        uint _price,
        uint256 _collDecimals,
        uint _totalLUSDSupply
    ) external returns (uint);

    function redemptionHelper() external view returns (IRedemptionHelper);

    function updateStakeAndTotalStakes(address _borrower, address _collateral) external returns (uint);

    function updateTroveRewardSnapshots(address _borrower, address _collateral) external;

    function addTroveOwnerToArray(address _borrower, address _collateral) external returns (uint index);

    function applyPendingRewards(address _borrower, address _collateral) external;

    function getPendingCollateralReward(address _borrower, address _collateral) external view returns (uint);

    function getPendingLUSDDebtReward(address _borrower, address _collateral) external view returns (uint);

     function hasPendingRewards(address _borrower, address _collateral) external view returns (bool);

    function getEntireDebtAndColl(address _borrower, address _collateral) external view returns (
        uint debt, 
        uint coll, 
        uint pendingLUSDDebtReward, 
        uint pendingCollateralReward
    );

    function closeTrove(address _borrower, address _collateral, uint256 _closedStatusNum) external;

    function removeStake(address _borrower, address _collateral) external;

    function getRedemptionRate() external view returns (uint);
    function getRedemptionRateWithDecay() external view returns (uint);

    function getRedemptionFee(uint _collateralDrawn) external view returns (uint);
    function getRedemptionFeeWithDecay(uint _collateralDrawn) external view returns (uint);

    function getBorrowingRate() external view returns (uint);
    function getBorrowingRateWithDecay() external view returns (uint);

    function getBorrowingFee(uint LUSDDebt) external view returns (uint);
    function getBorrowingFeeWithDecay(uint _LUSDDebt) external view returns (uint);

    function decayBaseRateFromBorrowing() external;

    function getTroveStatus(address _borrower, address _collateral) external view returns (uint);
    
    function getTroveStake(address _borrower, address _collateral) external view returns (uint);

    function getTroveDebt(address _borrower, address _collateral) external view returns (uint);

    function getTroveColl(address _borrower, address _collateral) external view returns (uint);

    function setTroveStatus(address _borrower, address _collateral, uint num) external;

    function increaseTroveColl(address _borrower, address _collateral, uint _collIncrease) external returns (uint);

    function decreaseTroveColl(address _borrower, address _collateral, uint _collDecrease) external returns (uint);

    function increaseTroveDebt(address _borrower, address _collateral, uint _debtIncrease) external returns (uint);

    function decreaseTroveDebt(address _borrower, address _collateral, uint _collDecrease) external returns (uint);

    function getTCR(address _collateral, uint _price) external view returns (uint);

    function checkRecoveryMode(address _collateral, uint _price) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "../Interfaces/ICommunityIssuance.sol";
import "../Dependencies/BaseMath.sol";
import "../Dependencies/LiquityMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/CheckContract.sol";
import "../Dependencies/SafeMath.sol";


contract CommunityIssuance is ICommunityIssuance, Ownable, CheckContract, BaseMath {
    using SafeMath for uint;

    // --- Data ---

    string constant public NAME = "CommunityIssuance";

    bool public initialized = false;

   /* The issuance factor F determines the curvature of the issuance curve.
    *
    * Minutes in one year: 60*24*365 = 525600
    *
    * For 50% of remaining tokens issued each year, with minutes as time units, we have:
    * 
    * F ** 525600 = 0.5
    * 
    * Re-arranging:
    * 
    * 525600 * ln(F) = ln(0.5)
    * F = 0.5 ** (1/525600)
    * F = 0.999998681227695000 
    */
    IERC20 public OathToken;

    address public stabilityPoolAddress;

    uint public totalOATHIssued;
    uint public lastDistributionTime;
    uint public distributionPeriod;
    uint public rewardPerSecond;

    uint public lastIssuanceTimestamp;

    // --- Events ---

    event OathTokenAddressSet(address _oathTokenAddress);
    event LogRewardPerSecond(uint _rewardPerSecond);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalOATHIssuedUpdated(uint _totalOATHIssued);

    // --- Functions ---

    constructor() public {
        distributionPeriod = 14 days;
    }

    function setAddresses
    (
        address _oathTokenAddress, 
        address _stabilityPoolAddress
    ) 
        external 
        onlyOwner 
        override 
    {
        require(!initialized, "issuance has been initialized");
        checkContract(_oathTokenAddress);
        checkContract(_stabilityPoolAddress);

        OathToken = IERC20(_oathTokenAddress);
        stabilityPoolAddress = _stabilityPoolAddress;

        initialized = true;

        emit OathTokenAddressSet(_oathTokenAddress);
        emit StabilityPoolAddressSet(_stabilityPoolAddress);
    }

    // @dev issues a set amount of Oath to the stability pool
    function issueOath() external override returns (uint issuance) {
        _requireCallerIsStabilityPool();
        if (lastIssuanceTimestamp < lastDistributionTime) {
            uint256 endTimestamp = block.timestamp > lastDistributionTime ? lastDistributionTime : block.timestamp;
            uint256 timePassed = endTimestamp.sub(lastIssuanceTimestamp);
            issuance = timePassed.mul(rewardPerSecond);
            totalOATHIssued = totalOATHIssued.add(issuance);
        }

        lastIssuanceTimestamp = block.timestamp;
        emit TotalOATHIssuedUpdated(totalOATHIssued);
    }

    /*
      @dev funds the contract and updates the distribution
      @param amount: amount of $OATH to send to the contract
    */
    function fund(uint amount) external onlyOwner {
        require(amount != 0, "cannot fund 0");
        OathToken.transferFrom(msg.sender, address(this), amount);

        // roll any unissued OATH into new distribution
        if (lastIssuanceTimestamp < lastDistributionTime) {
            uint timeLeft = lastDistributionTime.sub(lastIssuanceTimestamp);
            uint notIssued = timeLeft.mul(rewardPerSecond);
            amount = amount.add(notIssued);
        }

        rewardPerSecond = amount.div(distributionPeriod);
        lastDistributionTime = block.timestamp.add(distributionPeriod);
        lastIssuanceTimestamp = block.timestamp;

        emit LogRewardPerSecond(rewardPerSecond);
    }

    // Owner-only function to update the distribution period
    function updateDistributionPeriod(uint256 _newDistributionPeriod) external onlyOwner {
        distributionPeriod = _newDistributionPeriod;
    }

    function sendOath(address _account, uint _OathAmount) external override {
        _requireCallerIsStabilityPool();

        OathToken.transfer(_account, _OathAmount);
    }

    // --- 'require' functions ---

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "CommunityIssuance: caller is not SP");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/BaseMath.sol";
import "../Dependencies/SafeMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/CheckContract.sol";
import "../Dependencies/console.sol";
import "../Dependencies/IERC20.sol";
import "../Interfaces/ICollateralConfig.sol";
import "../Interfaces/ILQTYStaking.sol";
import "../Interfaces/ITroveManager.sol";
import "../Dependencies/LiquityMath.sol";
import "../Interfaces/ILUSDToken.sol";
import "../Dependencies/SafeERC20.sol";

contract LQTYStaking is ILQTYStaking, Ownable, CheckContract, BaseMath {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    // --- Data ---
    string constant public NAME = "LQTYStaking";

    mapping( address => uint) public stakes;
    uint public totalLQTYStaked;

    mapping (address => uint) public F_Collateral;  // Running sum of collateral fees per-LQTY-staked
    uint public F_LUSD; // Running sum of LUSD fees per-LQTY-staked

    // User snapshots of F_Collateral and F_LUSD, taken at the point at which their latest deposit was made
    mapping (address => Snapshot) public snapshots; 

    struct Snapshot {
        mapping (address => uint) F_Collateral_Snapshot;
        uint F_LUSD_Snapshot;
    }
    
    IERC20 public lqtyToken;
    ILUSDToken public lusdToken;
    ICollateralConfig public collateralConfig;

    address public troveManagerAddress;
    address public borrowerOperationsAddress;
    address public activePoolAddress;

    // --- Events ---

    event LQTYTokenAddressSet(address _lqtyTokenAddress);
    event LUSDTokenAddressSet(address _lusdTokenAddress);
    event TroveManagerAddressSet(address _troveManager);
    event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    event ActivePoolAddressSet(address _activePoolAddress);
    event CollateralConfigAddressSet(address _collateralConfigAddress);

    event StakeChanged(address indexed staker, uint newStake);
    event StakingGainsWithdrawn(address indexed staker, uint LUSDGain, address[] _assets, uint[] _amounts);
    event F_CollateralUpdated(address _collateral, uint _F_Collateral);
    event F_LUSDUpdated(uint _F_LUSD);
    event TotalLQTYStakedUpdated(uint _totalLQTYStaked);
    event CollateralSent(address _account, address _collateral, uint _amount);
    event StakerSnapshotsUpdated(address _staker, address[] _assets, uint[] _amounts, uint _F_LUSD);

    // --- Functions ---

    function setAddresses
    (
        address _lqtyTokenAddress,
        address _lusdTokenAddress,
        address _troveManagerAddress, 
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _collateralConfigAddress
    ) 
        external 
        onlyOwner 
        override 
    {
        checkContract(_lqtyTokenAddress);
        checkContract(_lusdTokenAddress);
        checkContract(_troveManagerAddress);
        checkContract(_borrowerOperationsAddress);
        checkContract(_activePoolAddress);
        checkContract(_collateralConfigAddress);

        lqtyToken = IERC20(_lqtyTokenAddress);
        lusdToken = ILUSDToken(_lusdTokenAddress);
        troveManagerAddress = _troveManagerAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;
        activePoolAddress = _activePoolAddress;
        collateralConfig = ICollateralConfig(_collateralConfigAddress);

        emit LQTYTokenAddressSet(_lqtyTokenAddress);
        emit LQTYTokenAddressSet(_lusdTokenAddress);
        emit TroveManagerAddressSet(_troveManagerAddress);
        emit BorrowerOperationsAddressSet(_borrowerOperationsAddress);
        emit ActivePoolAddressSet(_activePoolAddress);
        emit CollateralConfigAddressSet(_collateralConfigAddress);

        renounceOwnership();
    }

    // If caller has a pre-existing stake, send any accumulated collateral and LUSD gains to them. 
    function stake(uint _LQTYamount) external override {
        _requireNonZeroAmount(_LQTYamount);

        uint currentStake = stakes[msg.sender];

        address[] memory collGainAssets;
        uint[] memory collGainAmounts;
        uint LUSDGain;
        // Grab any accumulated collateral and LUSD gains from the current stake
        if (currentStake != 0) {
            (collGainAssets, collGainAmounts) = _getPendingCollateralGain(msg.sender);
            LUSDGain = _getPendingLUSDGain(msg.sender);
        }
    
       _updateUserSnapshots(msg.sender);

        uint newStake = currentStake.add(_LQTYamount);

        // Increase user’s stake and total LQTY staked
        stakes[msg.sender] = newStake;
        totalLQTYStaked = totalLQTYStaked.add(_LQTYamount);
        emit TotalLQTYStakedUpdated(totalLQTYStaked);

        // Transfer LQTY from caller to this contract
        lqtyToken.safeTransferFrom(msg.sender, address(this), _LQTYamount);

        emit StakeChanged(msg.sender, newStake);
        emit StakingGainsWithdrawn(msg.sender, LUSDGain, collGainAssets, collGainAmounts);

         // Send accumulated LUSD and collateral gains to the caller
        if (currentStake != 0) {
            lusdToken.transfer(msg.sender, LUSDGain);
            _sendCollGainToUser(collGainAssets, collGainAmounts);
        }
    }

    // Unstake the LQTY and send the it back to the caller, along with their accumulated LUSD & collateral gains.
    // If requested amount > stake, send their entire stake.
    function unstake(uint _LQTYamount) external override {
        uint currentStake = stakes[msg.sender];
        _requireUserHasStake(currentStake);

        // Grab any accumulated ETH and LUSD gains from the current stake
        (address[] memory collGainAssets, uint[] memory collGainAmounts) = _getPendingCollateralGain(msg.sender);
        uint LUSDGain = _getPendingLUSDGain(msg.sender);
        
        _updateUserSnapshots(msg.sender);

        if (_LQTYamount > 0) {
            uint LQTYToWithdraw = LiquityMath._min(_LQTYamount, currentStake);

            uint newStake = currentStake.sub(LQTYToWithdraw);

            // Decrease user's stake and total LQTY staked
            stakes[msg.sender] = newStake;
            totalLQTYStaked = totalLQTYStaked.sub(LQTYToWithdraw);
            emit TotalLQTYStakedUpdated(totalLQTYStaked);

            // Transfer unstaked LQTY to user
            lqtyToken.safeTransfer(msg.sender, LQTYToWithdraw);

            emit StakeChanged(msg.sender, newStake);
        }

        emit StakingGainsWithdrawn(msg.sender, LUSDGain, collGainAssets, collGainAmounts);

        // Send accumulated LUSD and ETH gains to the caller
        lusdToken.transfer(msg.sender, LUSDGain);
        _sendCollGainToUser(collGainAssets, collGainAmounts);
    }

    // --- Reward-per-unit-staked increase functions. Called by Liquity core contracts ---

    function increaseF_Collateral(address _collateral, uint _collFee) external override {
        _requireCallerIsTroveManagerOrActivePool();
        uint collFeePerLQTYStaked;
     
        if (totalLQTYStaked > 0) {collFeePerLQTYStaked = _collFee.mul(DECIMAL_PRECISION).div(totalLQTYStaked);}

        F_Collateral[_collateral] = F_Collateral[_collateral].add(collFeePerLQTYStaked);
        emit F_CollateralUpdated(_collateral, F_Collateral[_collateral]);
    }

    function increaseF_LUSD(uint _LUSDFee) external override {
        _requireCallerIsBorrowerOperations();
        uint LUSDFeePerLQTYStaked;
        
        if (totalLQTYStaked > 0) {LUSDFeePerLQTYStaked = _LUSDFee.mul(DECIMAL_PRECISION).div(totalLQTYStaked);}
        
        F_LUSD = F_LUSD.add(LUSDFeePerLQTYStaked);
        emit F_LUSDUpdated(F_LUSD);
    }

    // --- Pending reward functions ---

    function getPendingCollateralGain(address _user) external view override returns (address[] memory, uint[] memory) {
        return _getPendingCollateralGain(_user);
    }

    function _getPendingCollateralGain(address _user) internal view returns (address[] memory assets, uint[] memory amounts) {
        assets = collateralConfig.getAllowedCollaterals();
        amounts = new uint[](assets.length);
        for (uint i = 0; i < assets.length; i++) {
            address collateral = assets[i];
            uint F_Collateral_Snapshot = snapshots[_user].F_Collateral_Snapshot[collateral];
            amounts[i] = stakes[_user].mul(F_Collateral[collateral].sub(F_Collateral_Snapshot)).div(DECIMAL_PRECISION);
        }
    }

    function getPendingLUSDGain(address _user) external view override returns (uint) {
        return _getPendingLUSDGain(_user);
    }

    function _getPendingLUSDGain(address _user) internal view returns (uint) {
        uint F_LUSD_Snapshot = snapshots[_user].F_LUSD_Snapshot;
        uint LUSDGain = stakes[_user].mul(F_LUSD.sub(F_LUSD_Snapshot)).div(DECIMAL_PRECISION);
        return LUSDGain;
    }

    // --- Internal helper functions ---

    function _updateUserSnapshots(address _user) internal {
        address[] memory collaterals = collateralConfig.getAllowedCollaterals();
        uint[] memory amounts = new uint[](collaterals.length);
        for (uint i = 0; i < collaterals.length; i++) {
            address collateral = collaterals[i];
            snapshots[_user].F_Collateral_Snapshot[collateral] = F_Collateral[collateral];
            amounts[i] = F_Collateral[collateral];
        }
        uint fLUSD = F_LUSD;
        snapshots[_user].F_LUSD_Snapshot = fLUSD;
        emit StakerSnapshotsUpdated(_user, collaterals, amounts, fLUSD);
    }

    function _sendCollGainToUser(address[] memory assets, uint[] memory amounts) internal {
        uint numCollaterals = assets.length;
        for (uint i = 0; i < numCollaterals; i++) {
            if (amounts[i] != 0) {
                address collateral = assets[i];
                emit CollateralSent(msg.sender, collateral, amounts[i]);
                IERC20(collateral).safeTransfer(msg.sender, amounts[i]);
            }
        }
    }

    // --- 'require' functions ---

    function _requireCallerIsTroveManagerOrActivePool() internal view {
        address redemptionHelper = address(ITroveManager(troveManagerAddress).redemptionHelper());
        require(
            msg.sender == troveManagerAddress ||
            msg.sender == redemptionHelper ||
            msg.sender == activePoolAddress,
            "LQTYStaking: caller is not TroveM or ActivePool"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress, "LQTYStaking: caller is not BorrowerOps");
    }

    function _requireUserHasStake(uint currentStake) internal pure {  
        require(currentStake > 0, 'LQTYStaking: User must have a non-zero stake');  
    }

    function _requireNonZeroAmount(uint _amount) internal pure {
        require(_amount > 0, 'LQTYStaking: Amount must be non-zero');
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/ITroveManager.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
/*
*
* Based upon OpenZeppelin's ERC20 contract:
* https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol
*  
* and their EIP2612 (ERC20Permit / ERC712) functionality:
* https://github.com/OpenZeppelin/openzeppelin-contracts/blob/53516bc555a454862470e7860a9b5254db4d00f5/contracts/token/ERC20/ERC20Permit.sol
* 
*
* --- Functionality added specific to the LUSDToken ---
* 
* 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core Liquity contracts) in external 
* transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending LUSD directly to a Liquity 
* core contract, when they should rather call the right function. 
*
* 2) sendToPool() and returnFromPool(): functions callable only Liquity core contracts, which move LUSD tokens between Liquity <-> user.
*/

contract LUSDToken is CheckContract, ILUSDToken {
    using SafeMath for uint256;
    
    uint256 private _totalSupply;
    string constant internal _NAME = "Ethos Reserve Note";
    string constant internal _SYMBOL = "ERN";
    string constant internal _VERSION = "1";
    uint8 constant internal _DECIMALS = 18;

    bool public mintingPaused = false;
    
    // --- Data for EIP2612 ---
    
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    
    mapping (address => uint256) private _nonces;
    
    // User data for LUSD token
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;  
    
    // --- Addresses ---
    // mappings store addresses of old versions so they can still burn (close troves)
    mapping (address => bool) public troveManagers;
    mapping (address => bool) public stabilityPools;
    mapping (address => bool) public borrowerOperations;
    // simple address variables track current version that can mint (in addition to burning)
    // this design makes it so that only the latest version can open troves
    address public troveManagerAddress;
    address public stabilityPoolAddress;
    address public borrowerOperationsAddress;
    address public governanceAddress; // can pause/unpause minting and upgrade addresses
    address public guardianAddress; // can pause minting during emergency

    // Copied from LQTYToken.sol; since we deleted that file, we use LUSDToken's initialization
    // to mark system deployment start time
    uint internal immutable deploymentStartTime;
    
    // --- Events ---
    event TroveManagerAddressChanged(address _troveManagerAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event GovernanceAddressChanged(address _governanceAddress);
    event GuardianAddressChanged(address _guardianAddress);

    constructor
    ( 
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress,
        address _governanceAddress,
        address _guardianAddress
    ) 
        public 
    {  
        checkContract(_troveManagerAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_borrowerOperationsAddress);

        // must be a smart contract (multi-sig, timelock, etc.)
        checkContract(_governanceAddress);
        checkContract(_guardianAddress);

        troveManagerAddress = _troveManagerAddress;
        troveManagers[_troveManagerAddress] = true;
        emit TroveManagerAddressChanged(_troveManagerAddress);

        stabilityPoolAddress = _stabilityPoolAddress;
        stabilityPools[_stabilityPoolAddress] = true;
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        borrowerOperations[_borrowerOperationsAddress] = true;
        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);

        governanceAddress = _governanceAddress;
        emit GovernanceAddressChanged(_governanceAddress);

        guardianAddress = _guardianAddress;
        emit GuardianAddressChanged(_guardianAddress);
        
        bytes32 hashedName = keccak256(bytes(_NAME));
        bytes32 hashedVersion = keccak256(bytes(_VERSION));
        
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = _chainID();
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);

        deploymentStartTime = block.timestamp;
    }

    // --- Governance operations ---

    function pauseMinting() external {
        require(
            msg.sender == guardianAddress || msg.sender == governanceAddress,
            "LUSD: Caller is not guardian or governance"
        );
        mintingPaused = true;
    }

    function unpauseMinting() external {
        _requireCallerIsGovernance();
        mintingPaused = false;
    }

    function updateGovernance(address _newGovernanceAddress) external {
        _requireCallerIsGovernance();
        checkContract(_newGovernanceAddress); // must be a smart contract (multi-sig, timelock, etc.)
        governanceAddress = _newGovernanceAddress;
        emit GovernanceAddressChanged(_newGovernanceAddress);
    }

    function updateGuardian(address _newGuardianAddress) external {
        _requireCallerIsGovernance();
        checkContract(_newGuardianAddress); // must be a smart contract (multi-sig, timelock, etc.)
        guardianAddress = _newGuardianAddress;
        emit GuardianAddressChanged(_newGuardianAddress);
    }

    function upgradeProtocol(
        address _newTroveManagerAddress,
        address _newStabilityPoolAddress,
        address _newBorrowerOperationsAddress
    ) external {
        _requireCallerIsGovernance();
        checkContract(_newTroveManagerAddress);
        checkContract(_newStabilityPoolAddress);
        checkContract(_newBorrowerOperationsAddress);

        troveManagerAddress = _newTroveManagerAddress;
        troveManagers[_newTroveManagerAddress] = true;
        emit TroveManagerAddressChanged(_newTroveManagerAddress);

        stabilityPoolAddress = _newStabilityPoolAddress;
        stabilityPools[_newStabilityPoolAddress] = true;
        emit StabilityPoolAddressChanged(_newStabilityPoolAddress);

        borrowerOperationsAddress = _newBorrowerOperationsAddress;
        borrowerOperations[_newBorrowerOperationsAddress] = true;
        emit BorrowerOperationsAddressChanged(_newBorrowerOperationsAddress);
    }

    // --- Functions for intra-Liquity calls ---

    function mint(address _account, uint256 _amount) external override {
        _requireMintingNotPaused();
        _requireCallerIsBorrowerOperations();
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override {
        _requireCallerIsBOorTroveMorSP();
        _burn(_account, _amount);
    }

    function sendToPool(address _sender,  address _poolAddress, uint256 _amount) external override {
        _requireCallerIsStabilityPool();
        _transfer(_sender, _poolAddress, _amount);
    }

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external override {
        _requireCallerIsTroveMorSP();
        _transfer(_poolAddress, _receiver, _amount);
    }

    function getDeploymentStartTime() external view override returns (uint256) {
        return deploymentStartTime;
    }

    // --- External functions ---

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _requireValidRecipient(recipient);
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _requireValidRecipient(recipient);
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    // --- EIP 2612 Functionality ---

    function domainSeparator() public view override returns (bytes32) {    
        if (_chainID() == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function permit
    (
        address owner, 
        address spender, 
        uint amount, 
        uint deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
        external 
        override 
    {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert('LUSD: Invalid s value');
        }
        require(deadline >= now, 'LUSD: expired deadline');
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', 
                         domainSeparator(), keccak256(abi.encode(
                         _PERMIT_TYPEHASH, owner, spender, amount, 
                         _nonces[owner]++, deadline))));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, 'LUSD: invalid signature');
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view override returns (uint256) { // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _chainID() private pure returns (uint256 chainID) {
        assembly {
            chainID := chainid()
        }
    }
    
    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, name, version, _chainID(), address(this)));
    }

    // --- Internal operations ---
    // Warning: sanity checks (for sender and recipient) should have been done before calling these internal functions

    function _transfer(address sender, address recipient, uint256 amount) internal {
        assert(sender != address(0));
        assert(recipient != address(0));

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        assert(account != address(0));

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        assert(account != address(0));
        
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        assert(owner != address(0));
        assert(spender != address(0));

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // --- 'require' functions ---

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && 
            _recipient != address(this),
            "LUSD: Cannot transfer tokens directly to the LUSD token contract or the zero address"
        );
        require(
            !stabilityPools[_recipient] &&
            !troveManagers[_recipient] &&
            !borrowerOperations[_recipient],
            "LUSD: Cannot transfer tokens directly to the StabilityPool, TroveManager or BorrowerOps"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        // only latest borrowerOps version can mint
        require(msg.sender == borrowerOperationsAddress, "LUSDToken: Caller is not BorrowerOperations");
    }

    function _requireCallerIsBOorTroveMorSP() internal view {
        // old versions of the protocol may still burn
        require(
            troveManagers[msg.sender] ||
            stabilityPools[msg.sender] ||
            borrowerOperations[msg.sender],
            "LUSD: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool"
        );
    }

    function _requireCallerIsStabilityPool() internal view {
        // only latest stabilityPool can accept new deposits
        require(msg.sender == stabilityPoolAddress, "LUSD: Caller is not the StabilityPool");
    }

    function _requireCallerIsTroveMorSP() internal view {
        // old versions of the protocol may still:
        // 1. send lusd gas reserve to liquidator
        // 2. be able to return users their lusd from the stability pool
        require(
            troveManagers[msg.sender] || stabilityPools[msg.sender],
            "LUSD: Caller is neither TroveManager nor StabilityPool");
    }

    function _requireCallerIsGovernance() internal view {
        require(msg.sender == governanceAddress, "LUSDToken: Caller is not Governance");
    }

    function _requireMintingNotPaused() internal view {
        require(!mintingPaused, "LUSDToken: Minting is currently paused");
    }

    // --- Optional functions ---

    function name() external view override returns (string memory) {
        return _NAME;
    }

    function symbol() external view override returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external view override returns (uint8) {
        return _DECIMALS;
    }

    function version() external view override returns (string memory) {
        return _VERSION;
    }

    function permitTypeHash() external view override returns (bytes32) {
        return _PERMIT_TYPEHASH;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./Interfaces/ICollateralConfig.sol";
import "./TroveManager.sol";
import "./SortedTroves.sol";

/*  Helper contract for grabbing Trove data for the front end. Not part of the core Liquity system. */
contract MultiTroveGetter {
    struct CombinedTroveData {
        address owner;

        uint debt;
        uint coll;
        uint stake;

        uint snapshotCollAmount;
        uint snapshotLUSDDebt;
    }

    ICollateralConfig public collateralConfig;
    TroveManager public troveManager; // XXX Troves missing from ITroveManager?
    ISortedTroves public sortedTroves;

    constructor(ICollateralConfig _collateralConfig, TroveManager _troveManager, ISortedTroves _sortedTroves) public {
        collateralConfig = _collateralConfig;
        troveManager = _troveManager;
        sortedTroves = _sortedTroves;
    }

    function getMultipleSortedTroves(address _collateral, int _startIdx, uint _count)
        external view returns (CombinedTroveData[] memory _troves)
    {
        require(collateralConfig.isCollateralAllowed(_collateral),"Invalid collateral address");
        uint startIdx;
        bool descend;

        if (_startIdx >= 0) {
            startIdx = uint(_startIdx);
            descend = true;
        } else {
            startIdx = uint(-(_startIdx + 1));
            descend = false;
        }

        uint sortedTrovesSize = sortedTroves.getSize(_collateral);

        if (startIdx >= sortedTrovesSize) {
            _troves = new CombinedTroveData[](0);
        } else {
            uint maxCount = sortedTrovesSize - startIdx;

            if (_count > maxCount) {
                _count = maxCount;
            }

            if (descend) {
                _troves = _getMultipleSortedTrovesFromHead(_collateral, startIdx, _count);
            } else {
                _troves = _getMultipleSortedTrovesFromTail(_collateral, startIdx, _count);
            }
        }
    }

    function _getMultipleSortedTrovesFromHead(address _collateral, uint _startIdx, uint _count)
        internal view returns (CombinedTroveData[] memory _troves)
    {
        address currentTroveowner = sortedTroves.getFirst(_collateral);

        for (uint idx = 0; idx < _startIdx; ++idx) {
            currentTroveowner = sortedTroves.getNext(_collateral, currentTroveowner);
        }

        _troves = new CombinedTroveData[](_count);

        for (uint idx = 0; idx < _count; ++idx) {
            _troves[idx].owner = currentTroveowner;
            (
                _troves[idx].debt,
                _troves[idx].coll,
                _troves[idx].stake,
                /* status */,
                /* arrayIndex */
            ) = troveManager.Troves(currentTroveowner, _collateral);
            (
                _troves[idx].snapshotCollAmount,
                _troves[idx].snapshotLUSDDebt
            ) = troveManager.rewardSnapshots(currentTroveowner, _collateral);

            currentTroveowner = sortedTroves.getNext(_collateral, currentTroveowner);
        }
    }

    function _getMultipleSortedTrovesFromTail(address _collateral, uint _startIdx, uint _count)
        internal view returns (CombinedTroveData[] memory _troves)
    {
        address currentTroveowner = sortedTroves.getLast(_collateral);

        for (uint idx = 0; idx < _startIdx; ++idx) {
            currentTroveowner = sortedTroves.getPrev(_collateral, currentTroveowner);
        }

        _troves = new CombinedTroveData[](_count);

        for (uint idx = 0; idx < _count; ++idx) {
            _troves[idx].owner = currentTroveowner;
            (
                _troves[idx].debt,
                _troves[idx].coll,
                _troves[idx].stake,
                /* status */,
                /* arrayIndex */
            ) = troveManager.Troves(currentTroveowner, _collateral);
            (
                _troves[idx].snapshotCollAmount,
                _troves[idx].snapshotLUSDDebt
            ) = troveManager.rewardSnapshots(currentTroveowner, _collateral);

            currentTroveowner = sortedTroves.getPrev(_collateral, currentTroveowner);
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ICollateralConfig.sol";
import "./Interfaces/IPriceFeed.sol";
import "./Interfaces/ITellorCaller.sol";
import "./Dependencies/AggregatorV3Interface.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/BaseMath.sol";
import "./Dependencies/LiquityMath.sol";
import "./Dependencies/console.sol";

/*
* PriceFeed for mainnet deployment, to be connected to Chainlink's live ETH:USD aggregator reference 
* contract, and a wrapper contract TellorCaller, which connects to TellorMaster contract.
*
* The PriceFeed uses Chainlink as primary oracle, and Tellor as fallback. It contains logic for
* switching oracles based on oracle failures, timeouts, and conditions for returning to the primary
* Chainlink oracle.
*/
contract PriceFeed is Ownable, CheckContract, BaseMath, IPriceFeed {
    using SafeMath for uint256;

    string constant public NAME = "PriceFeed";

    bool public initialized = false;

    mapping (address => AggregatorV3Interface) public priceAggregator;  // collateral => Mainnet Chainlink aggregator
    ITellorCaller tellorCaller; // Wrapper contract that calls the Tellor system
    mapping (address => bytes32) public tellorQueryId;  // collateral => Tellor query ID

    // Core Liquity contracts
    ICollateralConfig public collateralConfig;

    // Use to convert a price answer to an 18-digit precision uint
    uint constant public TARGET_DIGITS = 18;
    // legacy Tellor "request IDs" use 6 decimals, newer Tellor "query IDs" use 18 decimals
    uint constant public TELLOR_DIGITS = 18;

    // Maximum time period allowed since Chainlink's latest round data timestamp, beyond which Chainlink is considered frozen.
    uint constant public TIMEOUT = 14400;  // 4 hours: 60 * 60 * 4
    
    // Maximum deviation allowed between two consecutive Chainlink oracle prices. 18-digit precision.
    uint constant public MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND =  5e17; // 50%

    /* 
    * The maximum relative price difference between two oracle responses allowed in order for the PriceFeed
    * to return to using the Chainlink oracle. 18-digit precision.
    */
    uint constant public MAX_PRICE_DIFFERENCE_BETWEEN_ORACLES = 5e16; // 5%

    // The last good price seen from an oracle by Liquity for each collateral
    mapping (address => uint) public lastGoodPrice;

    struct ChainlinkResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
        uint8 decimals;
    }

    struct TellorResponse {
        bool ifRetrieve;
        uint256 value;
        uint256 timestamp;
        bool success;
    }

    enum Status {
        chainlinkWorking, 
        usingTellorChainlinkUntrusted, 
        bothOraclesUntrusted,
        usingTellorChainlinkFrozen, 
        usingChainlinkTellorUntrusted
    }

    // The current status of the PricFeed for each collateral, which determines the conditions for the next price fetch attempt
    mapping (address => Status) public status;

    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event LastGoodPriceUpdated(address _collateral, uint _lastGoodPrice);
    event PriceFeedStatusChanged(address _collateral, Status newStatus);

    // --- Dependency setters ---
    
    function setAddresses(
        address _collateralConfigAddress,
        address[] calldata _priceAggregatorAddresses,
        address _tellorCallerAddress,
        bytes32[] calldata _tellorQueryIds
    )
        external
        onlyOwner
    {
        require(!initialized, "Can only initialize once");
        checkContract(_collateralConfigAddress);
        collateralConfig = ICollateralConfig(_collateralConfigAddress);
        emit CollateralConfigAddressChanged(_collateralConfigAddress);

        address[] memory collaterals = collateralConfig.getAllowedCollaterals();
        uint256 numCollaterals = collaterals.length;
        require(numCollaterals != 0, "At least one collateral required");
        require(_priceAggregatorAddresses.length == numCollaterals, "Array lengths must match");
        require(_tellorQueryIds.length == numCollaterals, "Array lengths must match");

        checkContract(_tellorCallerAddress);
        tellorCaller = ITellorCaller(_tellorCallerAddress);

        for (uint256 i = 0; i < numCollaterals; i++) {
            address collateral = collaterals[i];
            address priceAggregatorAddress = _priceAggregatorAddresses[i];
            bytes32 queryId = _tellorQueryIds[i];

            checkContract(priceAggregatorAddress);
            require(queryId != bytes32(0), "Invalid Tellor Query ID");

            priceAggregator[collateral] = AggregatorV3Interface(priceAggregatorAddress);
            tellorQueryId[collateral] = queryId;

            // Explicitly set initial system status
            status[collateral] = Status.chainlinkWorking;

            // Get an initial price from Chainlink to serve as first reference for lastGoodPrice
            ChainlinkResponse memory chainlinkResponse = _getCurrentChainlinkResponse(collateral);
            ChainlinkResponse memory prevChainlinkResponse = _getPrevChainlinkResponse(collateral, chainlinkResponse.roundId, chainlinkResponse.decimals);

            require(!_chainlinkIsBroken(chainlinkResponse, prevChainlinkResponse) && !_chainlinkIsFrozen(chainlinkResponse), 
                "PriceFeed: Chainlink must be working and current");

            _storeChainlinkPrice(collateral, chainlinkResponse);
        }

        initialized = true;
    }

    // Admin function to update the Chainlink aggregator address for a particular collateral.
    //
    // !!!PLEASE USE EXTREME CARE AND CAUTION!!!
    function updateChainlinkAggregator(
        address _collateral,
        address _priceAggregatorAddress
    ) external onlyOwner {
        _requireValidCollateralAddress(_collateral);
        checkContract(_priceAggregatorAddress);
        priceAggregator[_collateral] = AggregatorV3Interface(_priceAggregatorAddress);

        // Explicitly set initial system status
        status[_collateral] = Status.chainlinkWorking;

        // Get an initial price from Chainlink to serve as first reference for lastGoodPrice
        ChainlinkResponse memory chainlinkResponse = _getCurrentChainlinkResponse(_collateral);
        ChainlinkResponse memory prevChainlinkResponse = _getPrevChainlinkResponse(_collateral, chainlinkResponse.roundId, chainlinkResponse.decimals);

        require(!_chainlinkIsBroken(chainlinkResponse, prevChainlinkResponse) && !_chainlinkIsFrozen(chainlinkResponse),
            "PriceFeed: Chainlink must be working and current");

        _storeChainlinkPrice(_collateral, chainlinkResponse);
    }

    // Admin function to update the TellorCaller.
    //
    // !!!PLEASE USE EXTREME CARE AND CAUTION!!!
    function updateTellorCaller(
        address _tellorCallerAddress
    ) external onlyOwner {
        checkContract(_tellorCallerAddress);
        tellorCaller = ITellorCaller(_tellorCallerAddress);
    }

    // --- Functions ---

    /*
    * fetchPrice():
    * Returns the latest price obtained from the Oracle. Called by Liquity functions that require a current price.
    *
    * Also callable by anyone externally.
    *
    * Non-view function - it stores the last good price seen by Liquity.
    *
    * Uses a main oracle (Chainlink) and a fallback oracle (Tellor) in case Chainlink fails. If both fail, 
    * it uses the last good price seen by Liquity.
    *
    */
    function fetchPrice(address _collateral) external override returns (uint) {
        _requireValidCollateralAddress(_collateral);

        // Get current and previous price data from Chainlink, and current price data from Tellor
        ChainlinkResponse memory chainlinkResponse = _getCurrentChainlinkResponse(_collateral);
        ChainlinkResponse memory prevChainlinkResponse = _getPrevChainlinkResponse(_collateral, chainlinkResponse.roundId, chainlinkResponse.decimals);
        TellorResponse memory tellorResponse = _getCurrentTellorResponse(_collateral);

        // --- CASE 1: System fetched last price from Chainlink  ---
        if (status[_collateral] == Status.chainlinkWorking) {
            // If Chainlink is broken, try Tellor
            if (_chainlinkIsBroken(chainlinkResponse, prevChainlinkResponse)) {
                // If Tellor is broken then both oracles are untrusted, so return the last good price
                if (_tellorIsBroken(tellorResponse)) {
                    _changeStatus(_collateral, Status.bothOraclesUntrusted);
                    return lastGoodPrice[_collateral];
                }
                /*
                * If Tellor is only frozen but otherwise returning valid data, return the last good price.
                * Tellor may need to be tipped to return current data.
                */
                if (_tellorIsFrozen(tellorResponse)) {
                    _changeStatus(_collateral, Status.usingTellorChainlinkUntrusted);
                    return lastGoodPrice[_collateral];
                }
                
                // If Chainlink is broken and Tellor is working, switch to Tellor and return current Tellor price
                _changeStatus(_collateral, Status.usingTellorChainlinkUntrusted);
                return _storeTellorPrice(_collateral, tellorResponse);
            }

            // If Chainlink is frozen, try Tellor
            if (_chainlinkIsFrozen(chainlinkResponse)) {          
                // If Tellor is broken too, remember Tellor broke, and return last good price
                if (_tellorIsBroken(tellorResponse)) {
                    _changeStatus(_collateral, Status.usingChainlinkTellorUntrusted);
                    return lastGoodPrice[_collateral];
                }

                // If Tellor is frozen or working, remember Chainlink froze, and switch to Tellor
                _changeStatus(_collateral, Status.usingTellorChainlinkFrozen);
               
                if (_tellorIsFrozen(tellorResponse)) {return lastGoodPrice[_collateral];}

                // If Tellor is working, use it
                return _storeTellorPrice(_collateral, tellorResponse);
            }

            // If Chainlink price has changed by > 50% between two consecutive rounds, compare it to Tellor's price
            if (_chainlinkPriceChangeAboveMax(chainlinkResponse, prevChainlinkResponse)) {
                // If Tellor is broken, both oracles are untrusted, and return last good price
                 if (_tellorIsBroken(tellorResponse)) {
                    _changeStatus(_collateral, Status.bothOraclesUntrusted);
                    return lastGoodPrice[_collateral];
                }

                // If Tellor is frozen, switch to Tellor and return last good price 
                if (_tellorIsFrozen(tellorResponse)) { 
                    _changeStatus(_collateral, Status.usingTellorChainlinkUntrusted);
                    return lastGoodPrice[_collateral];
                }

                /* 
                * If Tellor is live and both oracles have a similar price, conclude that Chainlink's large price deviation between
                * two consecutive rounds was likely a legitmate market price movement, and so continue using Chainlink 
                */
                if (_bothOraclesSimilarPrice(chainlinkResponse, tellorResponse)) {
                    return _storeChainlinkPrice(_collateral, chainlinkResponse);
                }               

                // If Tellor is live but the oracles differ too much in price, conclude that Chainlink's initial price deviation was
                // an oracle failure. Switch to Tellor, and use Tellor price
                _changeStatus(_collateral, Status.usingTellorChainlinkUntrusted);
                return _storeTellorPrice(_collateral, tellorResponse);
            }

            // If Chainlink is working and Tellor is broken, remember Tellor is broken
            if (_tellorIsBroken(tellorResponse)) {
                _changeStatus(_collateral, Status.usingChainlinkTellorUntrusted);
            }   

            // If Chainlink is working, return Chainlink current price (no status change)
            return _storeChainlinkPrice(_collateral, chainlinkResponse);
        }


        // --- CASE 2: The system fetched last price from Tellor --- 
        if (status[_collateral] == Status.usingTellorChainlinkUntrusted) {
            // If both Tellor and Chainlink are live, unbroken, and reporting similar prices, switch back to Chainlink
            if (_bothOraclesLiveAndUnbrokenAndSimilarPrice(chainlinkResponse, prevChainlinkResponse, tellorResponse)) {
                _changeStatus(_collateral, Status.chainlinkWorking);
                return _storeChainlinkPrice(_collateral, chainlinkResponse);
            }

            if (_tellorIsBroken(tellorResponse)) {
                _changeStatus(_collateral, Status.bothOraclesUntrusted);
                return lastGoodPrice[_collateral];
            }

            /*
            * If Tellor is only frozen but otherwise returning valid data, just return the last good price.
            * Tellor may need to be tipped to return current data.
            */
            if (_tellorIsFrozen(tellorResponse)) {return lastGoodPrice[_collateral];}
            
            // Otherwise, use Tellor price
            return _storeTellorPrice(_collateral, tellorResponse);
        }

        // --- CASE 3: Both oracles were untrusted at the last price fetch ---
        if (status[_collateral] == Status.bothOraclesUntrusted) {
            /*
            * If both oracles are now live, unbroken and similar price, we assume that they are reporting
            * accurately, and so we switch back to Chainlink.
            */
            if (_bothOraclesLiveAndUnbrokenAndSimilarPrice(chainlinkResponse, prevChainlinkResponse, tellorResponse)) {
                _changeStatus(_collateral, Status.chainlinkWorking);
                return _storeChainlinkPrice(_collateral, chainlinkResponse);
            } 

            // Otherwise, return the last good price - both oracles are still untrusted (no status change)
            return lastGoodPrice[_collateral];
        }

        // --- CASE 4: Using Tellor, and Chainlink is frozen ---
        if (status[_collateral] == Status.usingTellorChainlinkFrozen) {
            if (_chainlinkIsBroken(chainlinkResponse, prevChainlinkResponse)) {
                // If both Oracles are broken, return last good price
                if (_tellorIsBroken(tellorResponse)) {
                    _changeStatus(_collateral, Status.bothOraclesUntrusted);
                    return lastGoodPrice[_collateral];
                }

                // If Chainlink is broken, remember it and switch to using Tellor
                _changeStatus(_collateral, Status.usingTellorChainlinkUntrusted);

                if (_tellorIsFrozen(tellorResponse)) {return lastGoodPrice[_collateral];}

                // If Tellor is working, return Tellor current price
                return _storeTellorPrice(_collateral, tellorResponse);
            }

            if (_chainlinkIsFrozen(chainlinkResponse)) {
                // if Chainlink is frozen and Tellor is broken, remember Tellor broke, and return last good price
                if (_tellorIsBroken(tellorResponse)) {
                    _changeStatus(_collateral, Status.usingChainlinkTellorUntrusted);
                    return lastGoodPrice[_collateral];
                }

                // If both are frozen, just use lastGoodPrice
                if (_tellorIsFrozen(tellorResponse)) {return lastGoodPrice[_collateral];}

                // if Chainlink is frozen and Tellor is working, keep using Tellor (no status change)
                return _storeTellorPrice(_collateral, tellorResponse);
            }

            // if Chainlink is live and Tellor is broken, remember Tellor broke, and return Chainlink price
            if (_tellorIsBroken(tellorResponse)) {
                _changeStatus(_collateral, Status.usingChainlinkTellorUntrusted);
                return _storeChainlinkPrice(_collateral, chainlinkResponse);
            }

             // If Chainlink is live and Tellor is frozen, just use last good price (no status change) since we have no basis for comparison
            if (_tellorIsFrozen(tellorResponse)) {return lastGoodPrice[_collateral];}

            // If Chainlink is live and Tellor is working, compare prices. Switch to Chainlink
            // if prices are within 5%, and return Chainlink price.
            if (_bothOraclesSimilarPrice(chainlinkResponse, tellorResponse)) {
                _changeStatus(_collateral, Status.chainlinkWorking);
                return _storeChainlinkPrice(_collateral, chainlinkResponse);
            }

            // Otherwise if Chainlink is live but price not within 5% of Tellor, distrust Chainlink, and return Tellor price
            _changeStatus(_collateral, Status.usingTellorChainlinkUntrusted);
            return _storeTellorPrice(_collateral, tellorResponse);
        }

        // --- CASE 5: Using Chainlink, Tellor is untrusted ---
         if (status[_collateral] == Status.usingChainlinkTellorUntrusted) {
            // If Chainlink breaks, now both oracles are untrusted
            if (_chainlinkIsBroken(chainlinkResponse, prevChainlinkResponse)) {
                _changeStatus(_collateral, Status.bothOraclesUntrusted);
                return lastGoodPrice[_collateral];
            }

            // If Chainlink is frozen, return last good price (no status change)
            if (_chainlinkIsFrozen(chainlinkResponse)) {
                return lastGoodPrice[_collateral];
            }

            // If Chainlink and Tellor are both live, unbroken and similar price, switch back to chainlinkWorking and return Chainlink price
            if (_bothOraclesLiveAndUnbrokenAndSimilarPrice(chainlinkResponse, prevChainlinkResponse, tellorResponse)) {
                _changeStatus(_collateral, Status.chainlinkWorking);
                return _storeChainlinkPrice(_collateral, chainlinkResponse);
            }

            // If Chainlink is live but deviated >50% from it's previous price and Tellor is still untrusted, switch 
            // to bothOraclesUntrusted and return last good price
            if (_chainlinkPriceChangeAboveMax(chainlinkResponse, prevChainlinkResponse)) {
                _changeStatus(_collateral, Status.bothOraclesUntrusted);
                return lastGoodPrice[_collateral];
            }

            // Otherwise if Chainlink is live and deviated <50% from it's previous price and Tellor is still untrusted, 
            // return Chainlink price (no status change)
            return _storeChainlinkPrice(_collateral, chainlinkResponse);
        }
    }

    // --- Helper functions ---

    /* Chainlink is considered broken if its current or previous round data is in any way bad. We check the previous round
    * for two reasons:
    *
    * 1) It is necessary data for the price deviation check in case 1,
    * and
    * 2) Chainlink is the PriceFeed's preferred primary oracle - having two consecutive valid round responses adds
    * peace of mind when using or returning to Chainlink.
    */
    function _chainlinkIsBroken(ChainlinkResponse memory _currentResponse, ChainlinkResponse memory _prevResponse) internal view returns (bool) {
        return _badChainlinkResponse(_currentResponse) || _badChainlinkResponse(_prevResponse);
    }

    function _badChainlinkResponse(ChainlinkResponse memory _response) internal view returns (bool) {
         // Check for response call reverted
        if (!_response.success) {return true;}
        // Check for an invalid roundId that is 0
        if (_response.roundId == 0) {return true;}
        // Check for an invalid timeStamp that is 0, or in the future
        if (_response.timestamp == 0 || _response.timestamp > block.timestamp) {return true;}
        // Check for non-positive price
        if (_response.answer <= 0) {return true;}

        return false;
    }

    function _chainlinkIsFrozen(ChainlinkResponse memory _response) internal view returns (bool) {
        return block.timestamp.sub(_response.timestamp) > TIMEOUT;
    }

    function _chainlinkPriceChangeAboveMax(ChainlinkResponse memory _currentResponse, ChainlinkResponse memory _prevResponse) internal pure returns (bool) {
        uint currentScaledPrice = _scaleChainlinkPriceByDigits(uint256(_currentResponse.answer), _currentResponse.decimals);
        uint prevScaledPrice = _scaleChainlinkPriceByDigits(uint256(_prevResponse.answer), _prevResponse.decimals);

        uint minPrice = LiquityMath._min(currentScaledPrice, prevScaledPrice);
        uint maxPrice = LiquityMath._max(currentScaledPrice, prevScaledPrice);

        /*
        * Use the larger price as the denominator:
        * - If price decreased, the percentage deviation is in relation to the the previous price.
        * - If price increased, the percentage deviation is in relation to the current price.
        */
        uint percentDeviation = maxPrice.sub(minPrice).mul(DECIMAL_PRECISION).div(maxPrice);

        // Return true if price has more than doubled, or more than halved.
        return percentDeviation > MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND;
    }

    function _tellorIsBroken(TellorResponse memory _response) internal view returns (bool) {
        // Check for response call reverted
        if (!_response.success) {return true;}
        // Check for an invalid timeStamp that is 0, or in the future
        if (_response.timestamp == 0 || _response.timestamp > block.timestamp) {return true;}
        // Check for zero price
        if (_response.value == 0) {return true;}

        return false;
    }

     function _tellorIsFrozen(TellorResponse  memory _tellorResponse) internal view returns (bool) {
        return block.timestamp.sub(_tellorResponse.timestamp) > TIMEOUT;
    }

    function _bothOraclesLiveAndUnbrokenAndSimilarPrice
    (
        ChainlinkResponse memory _chainlinkResponse,
        ChainlinkResponse memory _prevChainlinkResponse,
        TellorResponse memory _tellorResponse
    )
        internal
        view
        returns (bool)
    {
        // Return false if either oracle is broken or frozen
        if
        (
            _tellorIsBroken(_tellorResponse) ||
            _tellorIsFrozen(_tellorResponse) ||
            _chainlinkIsBroken(_chainlinkResponse, _prevChainlinkResponse) ||
            _chainlinkIsFrozen(_chainlinkResponse)
        )
        {
            return false;
        }

        return _bothOraclesSimilarPrice(_chainlinkResponse, _tellorResponse);
    }

    function _bothOraclesSimilarPrice( ChainlinkResponse memory _chainlinkResponse, TellorResponse memory _tellorResponse) internal pure returns (bool) {
        uint scaledChainlinkPrice = _scaleChainlinkPriceByDigits(uint256(_chainlinkResponse.answer), _chainlinkResponse.decimals);
        uint scaledTellorPrice = _scaleTellorPriceByDigits(_tellorResponse.value);

        // Get the relative price difference between the oracles. Use the lower price as the denominator, i.e. the reference for the calculation.
        uint minPrice = LiquityMath._min(scaledTellorPrice, scaledChainlinkPrice);
        uint maxPrice = LiquityMath._max(scaledTellorPrice, scaledChainlinkPrice);
        uint percentPriceDifference = maxPrice.sub(minPrice).mul(DECIMAL_PRECISION).div(minPrice);

        /*
        * Return true if the relative price difference is <= 3%: if so, we assume both oracles are probably reporting
        * the honest market price, as it is unlikely that both have been broken/hacked and are still in-sync.
        */
        return percentPriceDifference <= MAX_PRICE_DIFFERENCE_BETWEEN_ORACLES;
    }

    function _scaleChainlinkPriceByDigits(uint _price, uint _answerDigits) internal pure returns (uint) {
        /*
        * Convert the price returned by the Chainlink oracle to an 18-digit decimal for use by Liquity.
        * At date of Liquity launch, Chainlink uses an 8-digit price, but we also handle the possibility of
        * future changes.
        *
        */
        uint price;
        if (_answerDigits >= TARGET_DIGITS) {
            // Scale the returned price value down to Liquity's target precision
            price = _price.div(10 ** (_answerDigits - TARGET_DIGITS));
        }
        else if (_answerDigits < TARGET_DIGITS) {
            // Scale the returned price value up to Liquity's target precision
            price = _price.mul(10 ** (TARGET_DIGITS - _answerDigits));
        }
        return price;
    }

    function _scaleTellorPriceByDigits(uint _price) internal pure returns (uint) {
        uint256 price = _price;
        if (TARGET_DIGITS > TELLOR_DIGITS) {
            price = price.mul(10**(TARGET_DIGITS - TELLOR_DIGITS));
        } else if (TARGET_DIGITS < TELLOR_DIGITS) {
            price = price.div(10**(TELLOR_DIGITS - TARGET_DIGITS));
        }
        return price;
    }

    function _changeStatus(address _collateral, Status _status) internal {
        status[_collateral] = _status;
        emit PriceFeedStatusChanged(_collateral, _status);
    }

    function _storePrice(address _collateral, uint _currentPrice) internal {
        lastGoodPrice[_collateral] = _currentPrice;
        emit LastGoodPriceUpdated(_collateral, _currentPrice);
    }

     function _storeTellorPrice(address _collateral, TellorResponse memory _tellorResponse) internal returns (uint) {
        uint scaledTellorPrice = _scaleTellorPriceByDigits(_tellorResponse.value);
        _storePrice(_collateral, scaledTellorPrice);

        return scaledTellorPrice;
    }

    function _storeChainlinkPrice(address _collateral, ChainlinkResponse memory _chainlinkResponse) internal returns (uint) {
        uint scaledChainlinkPrice = _scaleChainlinkPriceByDigits(uint256(_chainlinkResponse.answer), _chainlinkResponse.decimals);
        _storePrice(_collateral, scaledChainlinkPrice);

        return scaledChainlinkPrice;
    }

    // --- Oracle response wrapper functions ---

    function _getCurrentTellorResponse(address _collateral) internal view returns (TellorResponse memory tellorResponse) {
        try tellorCaller.getTellorCurrentValue(tellorQueryId[_collateral]) returns
        (
            bool ifRetrieve,
            uint256 value,
            uint256 _timestampRetrieved
        )
        {
            // If call to Tellor succeeds, return the response and success = true
            tellorResponse.ifRetrieve = ifRetrieve;
            tellorResponse.value = value;
            tellorResponse.timestamp = _timestampRetrieved;
            tellorResponse.success = true;

            return (tellorResponse);
        }catch {
             // If call to Tellor reverts, return a zero response with success = false
            return (tellorResponse);
        }
    }

    function _getCurrentChainlinkResponse(address _collateral) internal view returns (ChainlinkResponse memory chainlinkResponse) {
        // First, try to get current decimal precision:
        try priceAggregator[_collateral].decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkResponse.decimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }

        // Secondly, try to get latest price data:
        try priceAggregator[_collateral].latestRoundData() returns
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = timestamp;
            chainlinkResponse.success = true;
            return chainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    function _getPrevChainlinkResponse(address _collateral, uint80 _currentRoundId, uint8 _currentDecimals) internal view returns (ChainlinkResponse memory prevChainlinkResponse) {
        /*
        * NOTE: Chainlink only offers a current decimals() value - there is no way to obtain the decimal precision used in a 
        * previous round.  We assume the decimals used in the previous round are the same as the current round.
        */

        // Try to get the price data from the previous round:
        try priceAggregator[_collateral].getRoundData(_currentRoundId - 1) returns
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            prevChainlinkResponse.roundId = roundId;
            prevChainlinkResponse.answer = answer;
            prevChainlinkResponse.timestamp = timestamp;
            prevChainlinkResponse.decimals = _currentDecimals;
            prevChainlinkResponse.success = true;
            return prevChainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return prevChainlinkResponse;
        }
    }

    // --- 'require' functions ---

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(collateralConfig.isCollateralAllowed(_collateral), "Invalid collateral address");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Dependencies/SafeERC20.sol";
import "../Interfaces/IBorrowerOperations.sol";


contract BorrowerOperationsScript is CheckContract {
    using SafeERC20 for IERC20;

    IBorrowerOperations immutable borrowerOperations;

    constructor(IBorrowerOperations _borrowerOperations) public {
        checkContract(address(_borrowerOperations));
        borrowerOperations = _borrowerOperations;
    }

    function openTrove(address _collateral, uint _collAmount, uint _maxFee, uint _LUSDAmount, address _upperHint, address _lowerHint) external {
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collAmount);
        IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), _collAmount);
        borrowerOperations.openTrove(_collateral, _collAmount, _maxFee, _LUSDAmount, _upperHint, _lowerHint);
    }

    function addColl(address _collateral, uint _collAmount, address _upperHint, address _lowerHint) external {
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collAmount);
        IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), _collAmount);
        borrowerOperations.addColl(_collateral, _collAmount, _upperHint, _lowerHint);
    }

    function withdrawColl(address _collateral, uint _amount, address _upperHint, address _lowerHint) external {
        borrowerOperations.withdrawColl(_collateral, _amount, _upperHint, _lowerHint);
    }

    function withdrawLUSD(address _collateral, uint _maxFee, uint _amount, address _upperHint, address _lowerHint) external {
        borrowerOperations.withdrawLUSD(_collateral, _maxFee, _amount, _upperHint, _lowerHint);
    }

    function repayLUSD(address _collateral, uint _amount, address _upperHint, address _lowerHint) external {
        borrowerOperations.repayLUSD(_collateral, _amount, _upperHint, _lowerHint);
    }

    function closeTrove(address _collateral) external {
        borrowerOperations.closeTrove(_collateral);
    }

    function adjustTrove(address _collateral, uint _maxFee, uint _collTopUp, uint _collWithdrawal, uint _debtChange, bool isDebtIncrease, address _upperHint, address _lowerHint) external {
        if (_collTopUp != 0) {
            IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collTopUp);
            IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), _collTopUp);
        }
        borrowerOperations.adjustTrove(_collateral, _maxFee, _collTopUp, _collWithdrawal, _debtChange, isDebtIncrease, _upperHint, _lowerHint);
    }

    function claimCollateral(address _collateral) external {
        borrowerOperations.claimCollateral(_collateral);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/SafeMath.sol";
import "../Dependencies/LiquityMath.sol";
import "../Dependencies/IERC20.sol";
import "../Interfaces/IBorrowerOperations.sol";
import "../Interfaces/ICollateralConfig.sol";
import "../Interfaces/ITroveManager.sol";
import "../Interfaces/IStabilityPool.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ILQTYStaking.sol";
import "./BorrowerOperationsScript.sol";
import "./ERC20TransferScript.sol";
import "./LQTYStakingScript.sol";
import "../Dependencies/console.sol";
import "../Dependencies/SafeERC20.sol";


contract BorrowerWrappersScript is BorrowerOperationsScript, ERC20TransferScript, LQTYStakingScript {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    string constant public NAME = "BorrowerWrappersScript";

    ICollateralConfig immutable collateralConfig;
    ITroveManager immutable troveManager;
    IStabilityPool immutable stabilityPool;
    IPriceFeed immutable priceFeed;
    IERC20 immutable lusdToken;
    IERC20 immutable lqtyToken;
    ILQTYStaking immutable lqtyStaking;

    constructor(
        address _borrowerOperationsAddress,
        address _collateralConfigAddress,
        address _troveManagerAddress,
        address _lqtyStakingAddress
    )
        BorrowerOperationsScript(IBorrowerOperations(_borrowerOperationsAddress))
        LQTYStakingScript(_lqtyStakingAddress)
        public
    {
        checkContract(_collateralConfigAddress);
        ICollateralConfig collateralConfigCached = ICollateralConfig(_collateralConfigAddress);
        collateralConfig = collateralConfigCached;

        checkContract(_troveManagerAddress);
        ITroveManager troveManagerCached = ITroveManager(_troveManagerAddress);
        troveManager = troveManagerCached;

        IStabilityPool stabilityPoolCached = troveManagerCached.stabilityPool();
        checkContract(address(stabilityPoolCached));
        stabilityPool = stabilityPoolCached;

        IPriceFeed priceFeedCached = troveManagerCached.priceFeed();
        checkContract(address(priceFeedCached));
        priceFeed = priceFeedCached;

        address lusdTokenCached = address(troveManagerCached.lusdToken());
        checkContract(lusdTokenCached);
        lusdToken = IERC20(lusdTokenCached);

        address lqtyTokenCached = address(troveManagerCached.lqtyToken());
        checkContract(lqtyTokenCached);
        lqtyToken = IERC20(lqtyTokenCached);

        ILQTYStaking lqtyStakingCached = troveManagerCached.lqtyStaking();
        require(_lqtyStakingAddress == address(lqtyStakingCached), "BorrowerWrappersScript: Wrong LQTYStaking address");
        lqtyStaking = lqtyStakingCached;
    }

    function claimCollateralAndOpenTrove(address _collateral, uint _collAmount, uint _maxFee, uint _LUSDAmount, address _upperHint, address _lowerHint) external {
        uint balanceBefore = IERC20(_collateral).balanceOf(address(this));

        // Claim collateral
        borrowerOperations.claimCollateral(_collateral);

        uint balanceAfter = IERC20(_collateral).balanceOf(address(this));

        // already checked in CollSurplusPool
        assert(balanceAfter > balanceBefore);

        uint totalCollateral = balanceAfter.sub(balanceBefore).add(_collAmount);

        // Open trove with obtained collateral, plus collateral sent by user
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collAmount);
        IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), totalCollateral);
        borrowerOperations.openTrove(_collateral, totalCollateral, _maxFee, _LUSDAmount, _upperHint, _lowerHint);
    }

    function claimSPRewardsAndRecycle(address _collateral, uint _maxFee, address _upperHint, address _lowerHint) external {
        uint collBalanceBefore = IERC20(_collateral).balanceOf(address(this));
        uint lqtyBalanceBefore = lqtyToken.balanceOf(address(this));

        // Claim rewards
        stabilityPool.withdrawFromSP(0);

        uint collBalanceAfter = IERC20(_collateral).balanceOf(address(this));
        uint lqtyBalanceAfter = lqtyToken.balanceOf(address(this));
        uint claimedCollateral = collBalanceAfter.sub(collBalanceBefore);

        // Add claimed ETH to trove, get more LUSD and stake it into the Stability Pool
        if (claimedCollateral > 0) {
            _requireUserHasTrove(address(this), _collateral);
            uint LUSDAmount = _getNetLUSDAmount(_collateral, claimedCollateral);
            IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), claimedCollateral);
            borrowerOperations.adjustTrove(_collateral, _maxFee, claimedCollateral, 0, LUSDAmount, true, _upperHint, _lowerHint);
            // Provide withdrawn LUSD to Stability Pool
            if (LUSDAmount > 0) {
                stabilityPool.provideToSP(LUSDAmount);
            }
        }

        // Stake claimed LQTY
        uint claimedLQTY = lqtyBalanceAfter.sub(lqtyBalanceBefore);
        if (claimedLQTY > 0) {
            lqtyToken.approve(address(lqtyStaking), claimedLQTY);
            lqtyStaking.stake(claimedLQTY);
        }
    }

    function claimStakingGainsAndRecycle(address _collateral, uint _maxFee, address _upperHint, address _lowerHint) external {
        uint collBalanceBefore = IERC20(_collateral).balanceOf(address(this));
        uint lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint lqtyBalanceBefore = lqtyToken.balanceOf(address(this));

        // Claim gains
        lqtyStaking.unstake(0);

        uint gainedCollateral = IERC20(_collateral).balanceOf(address(this)).sub(collBalanceBefore); // stack too deep issues :'(
        uint gainedLUSD = lusdToken.balanceOf(address(this)).sub(lusdBalanceBefore);

        uint netLUSDAmount;
        // Top up trove and get more LUSD, keeping ICR constant
        if (gainedCollateral > 0) {
            _requireUserHasTrove(address(this), _collateral);
            netLUSDAmount = _getNetLUSDAmount(_collateral, gainedCollateral);
            IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), gainedCollateral);
            borrowerOperations.adjustTrove(_collateral, _maxFee, gainedCollateral, 0, netLUSDAmount, true, _upperHint, _lowerHint);
        }

        uint totalLUSD = gainedLUSD.add(netLUSDAmount);
        if (totalLUSD > 0) {
            stabilityPool.provideToSP(totalLUSD);

            // Providing to Stability Pool also triggers LQTY claim, so stake it if any
            uint lqtyBalanceAfter = lqtyToken.balanceOf(address(this));
            uint claimedLQTY = lqtyBalanceAfter.sub(lqtyBalanceBefore);
            if (claimedLQTY > 0) {
                lqtyToken.approve(address(lqtyStaking), claimedLQTY);
                lqtyStaking.stake(claimedLQTY);
            }
        }

    }

    function _getNetLUSDAmount(address _collateral, uint _collAmount) internal returns (uint) {
        uint price = priceFeed.fetchPrice(_collateral);
        uint ICR = troveManager.getCurrentICR(address(this), _collateral, price);

        uint collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        uint LUSDAmount = _getScaledCollAmount(_collAmount, collDecimals).mul(price).div(ICR);
        uint borrowingRate = troveManager.getBorrowingRateWithDecay();
        uint netDebt = LUSDAmount.mul(LiquityMath.DECIMAL_PRECISION).div(LiquityMath.DECIMAL_PRECISION.add(borrowingRate));

        return netDebt;
    }

    function _requireUserHasTrove(address _depositor, address _collateral) internal view {
        require(troveManager.getTroveStatus(_depositor, _collateral) == 1, "BorrowerWrappersScript: caller must have an active trove");
    }

    function _getScaledCollAmount(uint256 _collAmount, uint256 _collDecimals) internal pure returns (uint256 scaledColl) {
        scaledColl = _collAmount;
        if (_collDecimals > LiquityMath.CR_CALCULATION_DECIMALS) {
            scaledColl = scaledColl.div(10 ** (_collDecimals - LiquityMath.CR_CALCULATION_DECIMALS));
        } else if (_collDecimals < LiquityMath.CR_CALCULATION_DECIMALS) {
            scaledColl = scaledColl.mul(10 ** (LiquityMath.CR_CALCULATION_DECIMALS - _collDecimals));
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";

contract ERC20TransferScript {
    function transferERC20(address _token, address _recipient, uint256 _amount) external returns (bool) {
        return IERC20(_token).transfer(_recipient, _amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Interfaces/ILQTYStaking.sol";


contract LQTYStakingScript is CheckContract {
    ILQTYStaking immutable LQTYStaking;

    constructor(address _lqtyStakingAddress) public {
        checkContract(_lqtyStakingAddress);
        LQTYStaking = ILQTYStaking(_lqtyStakingAddress);
    }

    function stake(uint _LQTYamount) external {
        LQTYStaking.stake(_LQTYamount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Interfaces/IStabilityPool.sol";


contract StabilityPoolScript is CheckContract {
    string constant public NAME = "StabilityPoolScript";

    IStabilityPool immutable stabilityPool;

    constructor(IStabilityPool _stabilityPool) public {
        checkContract(address(_stabilityPool));
        stabilityPool = _stabilityPool;
    }

    function provideToSP(uint _amount) external {
        stabilityPool.provideToSP(_amount);
    }

    function withdrawFromSP(uint _amount) external {
        stabilityPool.withdrawFromSP(_amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Dependencies/IERC20.sol";


contract TokenScript is CheckContract {
    string constant public NAME = "TokenScript";

    IERC20 immutable token;

    constructor(address _tokenAddress) public {
        checkContract(_tokenAddress);
        token = IERC20(_tokenAddress);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        token.transfer(recipient, amount);
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        token.allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        token.approve(spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        token.transferFrom(sender, recipient, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        token.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        token.decreaseAllowance(spender, subtractedValue);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Interfaces/ITroveManager.sol";


contract TroveManagerScript is CheckContract {
    string constant public NAME = "TroveManagerScript";

    ITroveManager immutable troveManager;

    constructor(ITroveManager _troveManager) public {
        checkContract(address(_troveManager));
        troveManager = _troveManager;
    }

    function redeemCollateral(
        address _collateral,
        uint _LUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFee
    ) external returns (uint) {
        troveManager.redeemCollateral(
            _collateral,
            _LUSDAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFee
        );
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ICollateralConfig.sol";
import "./Interfaces/ILQTYStaking.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/IPriceFeed.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IRedemptionHelper.sol";
import "./Dependencies/LiquityBase.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/IERC20.sol";

contract RedemptionHelper is LiquityBase, Ownable, IRedemptionHelper {
    uint constant public BOOTSTRAP_PERIOD = 14 days;

    ITroveManager public troveManager;
    ICollateralConfig public collateralConfig;
    IERC20 public lqtyToken;
    ILUSDToken public lusdToken;
    ISortedTroves public sortedTroves;
    ILQTYStaking public lqtyStaking;

    struct RedemptionTotals {
        uint remainingLUSD;
        uint totalLUSDToRedeem;
        uint totalCollateralDrawn;
        uint collateralFee;
        uint collateralToSendToRedeemer;
        uint decayedBaseRate;
        uint price;
        uint totalLUSDSupplyAtStart;
        uint256 collDecimals;
        uint256 collMCR;
        address currentBorrower;
    }

    struct SingleRedemptionValues {
        uint LUSDLot;
        uint collLot;
        bool cancelledPartial;
    }

    // Due to "stack too deep" error
    struct LocalVariables_redeemCollateralFromTrove {
        uint newDebt;
        uint newColl;
        uint newNICR;
        uint256 collDecimals;
    }

    function setAddresses(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        ITroveManager _troveManager,
        ICollateralConfig _collateralConfig,
        IERC20 _lqtyToken,
        IPriceFeed _priceFeed,
        ILUSDToken _lusdToken,
        ISortedTroves _sortedTroves,
        ILQTYStaking _lqtyStaking
    ) external onlyOwner {
        activePool = _activePool;
        defaultPool = _defaultPool;
        troveManager = _troveManager;
        collateralConfig = _collateralConfig;
        lqtyToken = _lqtyToken;
        priceFeed = _priceFeed;
        lusdToken = _lusdToken;
        sortedTroves = _sortedTroves;
        lqtyStaking = _lqtyStaking;

        renounceOwnership();
    }

    /* Send _LUSDamount LUSD to the system and redeem the corresponding amount of collateral from as many Troves as are needed to fill the redemption
    * request.  Applies pending rewards to a Trove before reducing its debt and coll.
    *
    * Note that if _amount is very large, this function can run out of gas, specially if traversed troves are small. This can be easily avoided by
    * splitting the total _amount in appropriate chunks and calling the function multiple times.
    *
    * Param `_maxIterations` can also be provided, so the loop through Troves is capped (if it’s zero, it will be ignored).This makes it easier to
    * avoid OOG for the frontend, as only knowing approximately the average cost of an iteration is enough, without needing to know the “topology”
    * of the trove list. It also avoids the need to set the cap in stone in the contract, nor doing gas calculations, as both gas price and opcode
    * costs can vary.
    *
    * All Troves that are redeemed from -- with the likely exception of the last one -- will end up with no debt left, therefore they will be closed.
    * If the last Trove does have some remaining debt, it has a finite ICR, and the reinsertion could be anywhere in the list, therefore it requires a hint.
    * A frontend should use getRedemptionHints() to calculate what the ICR of this Trove will be after redemption, and pass a hint for its position
    * in the sortedTroves list along with the ICR value that the hint was found for.
    *
    * If another transaction modifies the list between calling getRedemptionHints() and passing the hints to redeemCollateral(), it
    * is very likely that the last (partially) redeemed Trove would end up with a different ICR than what the hint is for. In this case the
    * redemption will stop after the last completely redeemed Trove and the sender will keep the remaining LUSD amount, which they can attempt
    * to redeem later.
    */
    function redeemCollateral(
        address _collateral,
        address _redeemer,
        uint _LUSDamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFeePercentage
    )
        external override
    {
        _requireCallerIsTroveManager();
        _requireValidCollateralAddress(_collateral);
        RedemptionTotals memory totals;

        _requireValidMaxFeePercentage(_maxFeePercentage);
        _requireAfterBootstrapPeriod();
        totals.price = priceFeed.fetchPrice(_collateral);
        ICollateralConfig collateralConfigCached = collateralConfig;
        totals.collDecimals = collateralConfigCached.getCollateralDecimals(_collateral);
        totals.collMCR = collateralConfigCached.getCollateralMCR(_collateral);
        _requireTCRoverMCR(_collateral, totals.price, totals.collDecimals, totals.collMCR);
        _requireAmountGreaterThanZero(_LUSDamount);
        _requireLUSDBalanceCoversRedemption(lusdToken, _redeemer, _LUSDamount);

        totals.totalLUSDSupplyAtStart = getEntireSystemDebt(_collateral);
        // Confirm redeemer's balance is less than total LUSD supply
        assert(lusdToken.balanceOf(_redeemer) <= totals.totalLUSDSupplyAtStart);

        totals.remainingLUSD = _LUSDamount;

        ISortedTroves sortedTrovesCached = sortedTroves;
        if (_isValidFirstRedemptionHint(
            sortedTrovesCached,
            _collateral,
            _firstRedemptionHint,
            totals.price,
            totals.collMCR)
        ) {
            totals.currentBorrower = _firstRedemptionHint;
        } else {
            totals.currentBorrower = sortedTrovesCached.getLast(_collateral);
            // Find the first trove with ICR >= MCR
            while (totals.currentBorrower != address(0) &&
                troveManager.getCurrentICR(totals.currentBorrower, _collateral, totals.price) < totals.collMCR) 
            {
                totals.currentBorrower = sortedTrovesCached.getPrev(_collateral, totals.currentBorrower);
            }
        }

        // Loop through the Troves starting from the one with lowest collateral ratio until _amount of LUSD is exchanged for collateral
        if (_maxIterations == 0) { _maxIterations = uint(-1); }
        while (totals.currentBorrower != address(0) && totals.remainingLUSD > 0 && _maxIterations > 0) {
            _maxIterations--;
            // Save the address of the Trove preceding the current one, before potentially modifying the list
            address nextUserToCheck = sortedTrovesCached.getPrev(_collateral, totals.currentBorrower);

            troveManager.applyPendingRewards(totals.currentBorrower, _collateral);

            SingleRedemptionValues memory singleRedemption = _redeemCollateralFromTrove(
                totals.currentBorrower,
                _collateral,
                totals.remainingLUSD,
                totals.price,
                _upperPartialRedemptionHint,
                _lowerPartialRedemptionHint,
                _partialRedemptionHintNICR,
                collateralConfigCached
            );

            if (singleRedemption.cancelledPartial) break; // Partial redemption was cancelled (out-of-date hint, or new net debt < minimum), therefore we could not redeem from the last Trove

            totals.totalLUSDToRedeem  = totals.totalLUSDToRedeem.add(singleRedemption.LUSDLot);
            totals.totalCollateralDrawn = totals.totalCollateralDrawn.add(singleRedemption.collLot);

            totals.remainingLUSD = totals.remainingLUSD.sub(singleRedemption.LUSDLot);
            totals.currentBorrower = nextUserToCheck;
        }
        require(totals.totalCollateralDrawn > 0);

        // Decay the baseRate due to time passed, and then increase it according to the size of this redemption.
        // Use the saved total LUSD supply value, from before it was reduced by the redemption.
        troveManager.updateBaseRateFromRedemption(
            totals.totalCollateralDrawn,
            totals.price,
            totals.collDecimals,
            totals.totalLUSDSupplyAtStart
        );

        // Calculate the ETH fee
        totals.collateralFee = troveManager.getRedemptionFee(totals.totalCollateralDrawn);

        _requireUserAcceptsFee(totals.collateralFee, totals.totalCollateralDrawn, _maxFeePercentage);

        // Send the collateral fee to the LQTY staking contract
        activePool.sendCollateral(_collateral, address(lqtyStaking), totals.collateralFee);
        lqtyStaking.increaseF_Collateral(_collateral, totals.collateralFee);

        totals.collateralToSendToRedeemer = totals.totalCollateralDrawn.sub(totals.collateralFee);

        // Burn the total LUSD that is cancelled with debt, and send the redeemed collateral to _redeemer
        troveManager.burnLUSDAndEmitRedemptionEvent(
            _redeemer,
            _collateral,
            _LUSDamount,
            totals.totalLUSDToRedeem,
            totals.totalCollateralDrawn,
            totals.collateralFee
        );

        // Update Active Pool LUSD, and send ETH to account
        activePool.decreaseLUSDDebt(_collateral, totals.totalLUSDToRedeem);
        activePool.sendCollateral(_collateral, _redeemer, totals.collateralToSendToRedeemer);
    }

    function _isValidFirstRedemptionHint(
        ISortedTroves _sortedTroves,
        address _collateral,
        address _firstRedemptionHint,
        uint _price,
        uint256 _MCR
    ) internal view returns (bool) {
        if (_firstRedemptionHint == address(0) ||
            !_sortedTroves.contains(_collateral, _firstRedemptionHint) ||
            troveManager.getCurrentICR(_firstRedemptionHint, _collateral, _price) < _MCR
        ) {
            return false;
        }

        address nextTrove = _sortedTroves.getNext(_collateral, _firstRedemptionHint);
        return nextTrove == address(0) || troveManager.getCurrentICR(nextTrove, _collateral, _price) < _MCR;
    }

    // Redeem as much collateral as possible from _borrower's Trove in exchange for LUSD up to _maxLUSDamount
    function _redeemCollateralFromTrove(
        address _borrower,
        address _collateral,
        uint _maxLUSDamount,
        uint _price,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        ICollateralConfig _collateralConfig
    )
        internal returns (SingleRedemptionValues memory singleRedemption)
    {
        // Determine the remaining amount (lot) to be redeemed, capped by the entire debt of the Trove minus the liquidation reserve
        singleRedemption.LUSDLot = LiquityMath._min(
            _maxLUSDamount,
            troveManager.getTroveDebt(_borrower, _collateral).sub(LUSD_GAS_COMPENSATION)
        );

        LocalVariables_redeemCollateralFromTrove memory vars;
        vars.collDecimals = _collateralConfig.getCollateralDecimals(_collateral);

        // Get the collLot of equivalent value in USD
        singleRedemption.collLot = singleRedemption.LUSDLot.mul(10**vars.collDecimals).div(_price);

        // Decrease the debt and collateral of the current Trove according to the LUSD lot and corresponding collateral to send
        vars.newDebt = troveManager.getTroveDebt(_borrower, _collateral).sub(singleRedemption.LUSDLot);
        vars.newColl = troveManager.getTroveColl(_borrower, _collateral).sub(singleRedemption.collLot);

        if (vars.newDebt == LUSD_GAS_COMPENSATION) {
            // No debt left in the Trove (except for the liquidation reserve), therefore the trove gets closed
            troveManager.removeStake(_borrower, _collateral);
            troveManager.closeTrove(_borrower, _collateral, 4); // 4 = closedByRedemption
            troveManager.redeemCloseTrove(_borrower, _collateral, LUSD_GAS_COMPENSATION, vars.newColl);
        } else {
            vars.newNICR = LiquityMath._computeNominalCR(vars.newColl, vars.newDebt, vars.collDecimals);

            /*
            * If the provided hint is out of date, we bail since trying to reinsert without a good hint will almost
            * certainly result in running out of gas. 
            *
            * If the resultant net debt of the partial is less than the minimum, net debt we bail.
            */
            if (vars.newNICR != _partialRedemptionHintNICR || _getNetDebt(vars.newDebt) < MIN_NET_DEBT) {
                singleRedemption.cancelledPartial = true;
                return singleRedemption;
            }

            troveManager.reInsert(
                _borrower,
                _collateral,
                vars.newNICR,
                _upperPartialRedemptionHint,
                _lowerPartialRedemptionHint
            );
            troveManager.updateDebtAndCollAndStakesPostRedemption(_borrower, _collateral, vars.newDebt, vars.newColl);
        }

        return singleRedemption;
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == address(troveManager), "RedemptionHelper: Caller is not TroveManager");
    }

    function _requireValidCollateralAddress(address _collateral) internal view {
        require(collateralConfig.isCollateralAllowed(_collateral), "Invalid collateral address");
    }

    function _requireValidMaxFeePercentage(uint _maxFeePercentage) internal view {
        require(_maxFeePercentage >= troveManager.REDEMPTION_FEE_FLOOR() && _maxFeePercentage <= DECIMAL_PRECISION);
    }

    function _requireAfterBootstrapPeriod() internal view {
        uint systemDeploymentTime = lusdToken.getDeploymentStartTime();
        require(block.timestamp >= systemDeploymentTime.add(BOOTSTRAP_PERIOD));
    }

    function _requireTCRoverMCR(address _collateral, uint _price, uint256 _collDecimals, uint256 _MCR) internal view {
        require(_getTCR(_collateral, _price, _collDecimals) >= _MCR);
    }

    function _requireAmountGreaterThanZero(uint _amount) internal pure {
        require(_amount > 0);
    }

    function _requireLUSDBalanceCoversRedemption(ILUSDToken _lusdToken, address _redeemer, uint _amount) internal view {
        require(_lusdToken.balanceOf(_redeemer) >= _amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ISortedTroves.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IBorrowerOperations.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";

/*
* A sorted doubly linked list with nodes sorted in descending order.
*
* Nodes map to active Troves in the system - the ID property is the address of a Trove owner.
* Nodes are ordered according to their current nominal individual collateral ratio (NICR),
* which is like the ICR but without the price, i.e., just collateral / debt.
*
* The list optionally accepts insert position hints.
*
* NICRs are computed dynamically at runtime, and not stored on the Node. This is because NICRs of active Troves
* change dynamically as liquidation events occur.
*
* The list relies on the fact that liquidation events preserve ordering: a liquidation decreases the NICRs of all active Troves,
* but maintains their order. A node inserted based on current NICR will maintain the correct position,
* relative to it's peers, as rewards accumulate, as long as it's raw collateral and debt have not changed.
* Thus, Nodes remain sorted by current NICR.
*
* Nodes need only be re-inserted upon a Trove operation - when the owner adds or removes collateral or debt
* to their position.
*
* The list is a modification of the following audited SortedDoublyLinkedList:
* https://github.com/livepeer/protocol/blob/master/contracts/libraries/SortedDoublyLL.sol
*
*
* Changes made in the Liquity implementation:
*
* - Keys have been removed from nodes
*
* - Ordering checks for insertion are performed by comparing an NICR argument to the current NICR, calculated at runtime.
*   The list relies on the property that ordering by ICR is maintained as the ETH:USD price varies.
*
* - Public functions with parameters have been made internal to save gas, and given an external wrapper function for external access
*/
contract SortedTroves is Ownable, CheckContract, ISortedTroves {
    using SafeMath for uint256;

    string constant public NAME = "SortedTroves";

    event TroveManagerAddressChanged(address _troveManagerAddress);
    event BorrowerOperationsAddressChanged(address _borrowerOperationsAddress);
    event NodeAdded(address _collateral, address _id, uint _NICR);
    event NodeRemoved(address _collateral, address _id);

    address public borrowerOperationsAddress;

    ITroveManager public troveManager;

    // Information for a node in the list
    struct Node {
        bool exists;
        address nextId;                  // Id of next node (smaller NICR) in the list
        address prevId;                  // Id of previous node (larger NICR) in the list
    }

    // Information for the list
    struct Data {
        address head;                        // Head of the list. Also the node in the list with the largest NICR
        address tail;                        // Tail of the list. Also the node in the list with the smallest NICR
        uint256 size;                        // Current size of the list
        mapping (address => Node) nodes;     // Track the corresponding ids for each node in the list
    }

    // Each collateral has its own list of sorted troves
    mapping (address => Data) public data;

    // --- Dependency setters ---

    function setParams(address _troveManagerAddress, address _borrowerOperationsAddress) external override onlyOwner {
        checkContract(_troveManagerAddress);
        checkContract(_borrowerOperationsAddress);

        troveManager = ITroveManager(_troveManagerAddress);
        borrowerOperationsAddress = _borrowerOperationsAddress;

        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);

        renounceOwnership();
    }

    /*
     * @dev Add a node to the list
     * @param _collateral Identifier for the list to operate on
     * @param _id Node's id
     * @param _NICR Node's NICR
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */

    function insert (address _collateral, address _id, uint256 _NICR, address _prevId, address _nextId) external override {
        ITroveManager troveManagerCached = troveManager;

        _requireCallerIsBOorTroveM(troveManagerCached);
        _insert(troveManagerCached, _collateral, _id, _NICR, _prevId, _nextId);
    }

    function _insert(ITroveManager _troveManager, address _collateral, address _id, uint256 _NICR, address _prevId, address _nextId) internal {
        // List must not already contain node
        require(!contains(_collateral, _id), "SortedTroves: List already contains the node");
        // Node id must not be null
        require(_id != address(0), "SortedTroves: Id cannot be zero");
        // NICR must be non-zero
        require(_NICR > 0, "SortedTroves: NICR must be positive");

        address prevId = _prevId;
        address nextId = _nextId;

        if (!_validInsertPosition(_troveManager, _collateral, _NICR, prevId, nextId)) {
            // Sender's hint was not a valid insert position
            // Use sender's hint to find a valid insert position
            (prevId, nextId) = _findInsertPosition(_troveManager, _collateral, _NICR, prevId, nextId);
        }

         data[_collateral].nodes[_id].exists = true;

        if (prevId == address(0) && nextId == address(0)) {
            // Insert as head and tail
            data[_collateral].head = _id;
            data[_collateral].tail = _id;
        } else if (prevId == address(0)) {
            // Insert before `prevId` as the head
            data[_collateral].nodes[_id].nextId = data[_collateral].head;
            data[_collateral].nodes[data[_collateral].head].prevId = _id;
            data[_collateral].head = _id;
        } else if (nextId == address(0)) {
            // Insert after `nextId` as the tail
            data[_collateral].nodes[_id].prevId = data[_collateral].tail;
            data[_collateral].nodes[data[_collateral].tail].nextId = _id;
            data[_collateral].tail = _id;
        } else {
            // Insert at insert position between `prevId` and `nextId`
            data[_collateral].nodes[_id].nextId = nextId;
            data[_collateral].nodes[_id].prevId = prevId;
            data[_collateral].nodes[prevId].nextId = _id;
            data[_collateral].nodes[nextId].prevId = _id;
        }

        data[_collateral].size = data[_collateral].size.add(1);
        emit NodeAdded(_collateral, _id, _NICR);
    }

    function remove(address _collateral, address _id) external override {
        _requireCallerIsTroveManager();
        _remove(_collateral, _id);
    }

    /*
     * @dev Remove a node from the list
     * @param _collateral Address of the collateral whose list to be removed from
     * @param _id Node's id
     */
    function _remove(address _collateral, address _id) internal {
        // List must contain the node
        require(contains(_collateral, _id), "SortedTroves: List does not contain the id");

        if (data[_collateral].size > 1) {
            // List contains more than a single node
            if (_id == data[_collateral].head) {
                // The removed node is the head
                // Set head to next node
                data[_collateral].head = data[_collateral].nodes[_id].nextId;
                // Set prev pointer of new head to null
                data[_collateral].nodes[data[_collateral].head].prevId = address(0);
            } else if (_id == data[_collateral].tail) {
                // The removed node is the tail
                // Set tail to previous node
                data[_collateral].tail = data[_collateral].nodes[_id].prevId;
                // Set next pointer of new tail to null
                data[_collateral].nodes[data[_collateral].tail].nextId = address(0);
            } else {
                // The removed node is neither the head nor the tail
                // Set next pointer of previous node to the next node
                data[_collateral].nodes[data[_collateral].nodes[_id].prevId].nextId = data[_collateral].nodes[_id].nextId;
                // Set prev pointer of next node to the previous node
                data[_collateral].nodes[data[_collateral].nodes[_id].nextId].prevId = data[_collateral].nodes[_id].prevId;
            }
        } else {
            // List contains a single node
            // Set the head and tail to null
            data[_collateral].head = address(0);
            data[_collateral].tail = address(0);
        }

        delete data[_collateral].nodes[_id];
        data[_collateral].size = data[_collateral].size.sub(1);
        NodeRemoved(_collateral, _id);
    }

    /*
     * @dev Re-insert the node at a new position, based on its new NICR
     * @param _id Node's id
     * @param _collateral Address of collateral whose list is to be inserted into
     * @param _newNICR Node's new NICR
     * @param _prevId Id of previous node for the new insert position
     * @param _nextId Id of next node for the new insert position
     */
    function reInsert(address _id, address _collateral, uint256 _newNICR, address _prevId, address _nextId) external override {
        ITroveManager troveManagerCached = troveManager;

        _requireCallerIsBOorTroveM(troveManagerCached);
        // List must contain the node
        require(contains(_collateral, _id), "SortedTroves: List does not contain the id");
        // NICR must be non-zero
        require(_newNICR > 0, "SortedTroves: NICR must be positive");

        // Remove node from the list
        _remove(_collateral, _id);

        _insert(troveManagerCached, _collateral, _id, _newNICR, _prevId, _nextId);
    }

    /*
     * @dev Checks if the specified collateral's list contains a node
     */
    function contains(address _collateral, address _id) public view override returns (bool) {
        return data[_collateral].nodes[_id].exists;
    }

    /*
     * @dev Checks if the specified collateral's list is empty
     */
    function isEmpty(address _collateral) public view override returns (bool) {
        return data[_collateral].size == 0;
    }

    /*
     * @dev Returns the current size of the list for the specified collateral
     */
    function getSize(address _collateral) external view override returns (uint256) {
        return data[_collateral].size;
    }

    /*
     * @dev Returns the first node in the list for the specified collateral (node with the largest NICR)
     */
    function getFirst(address _collateral) external view override returns (address) {
        return data[_collateral].head;
    }

    /*
     * @dev Returns the last node in the list for the specified collateral(node with the smallest NICR)
     */
    function getLast(address _collateral) external view override returns (address) {
        return data[_collateral].tail;
    }

    /*
     * @dev Returns the next node (with a smaller NICR) in the specified collateral's list for a given node
     * @param _collateral Address of collateral whose list to look at
     * @param _id Node's id
     */
    function getNext(address _collateral, address _id) external view override returns (address) {
        return data[_collateral].nodes[_id].nextId;
    }

    /*
     * @dev Returns the previous node (with a larger NICR) in the specified collateral's list for a given node
     * @param _collateral Address of collateral whose list to look at
     * @param _id Node's id
     */
    function getPrev(address _collateral, address _id) external view override returns (address) {
        return data[_collateral].nodes[_id].prevId;
    }

    /*
     * @dev Check if a pair of nodes is a valid insertion point for a new node with the given NICR
     * @param _collateral Address of collateral whose list is being checked against
     * @param _NICR Node's NICR
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function validInsertPosition(address _collateral, uint256 _NICR, address _prevId, address _nextId) external view override returns (bool) {
        return _validInsertPosition(troveManager, _collateral, _NICR, _prevId, _nextId);
    }

    function _validInsertPosition(ITroveManager _troveManager, address _collateral, uint256 _NICR, address _prevId, address _nextId) internal view returns (bool) {
        if (_prevId == address(0) && _nextId == address(0)) {
            // `(null, null)` is a valid insert position if the list is empty
            return isEmpty(_collateral);
        } else if (_prevId == address(0)) {
            // `(null, _nextId)` is a valid insert position if `_nextId` is the head of the list
            return data[_collateral].head == _nextId && _NICR >= _troveManager.getNominalICR(_nextId, _collateral);
        } else if (_nextId == address(0)) {
            // `(_prevId, null)` is a valid insert position if `_prevId` is the tail of the list
            return data[_collateral].tail == _prevId && _NICR <= _troveManager.getNominalICR(_prevId, _collateral);
        } else {
            // `(_prevId, _nextId)` is a valid insert position if they are adjacent nodes and `_NICR` falls between the two nodes' NICRs
            return data[_collateral].nodes[_prevId].nextId == _nextId &&
                   _troveManager.getNominalICR(_prevId, _collateral) >= _NICR &&
                   _NICR >= _troveManager.getNominalICR(_nextId, _collateral);
        }
    }

    /*
     * @dev Descend the list (larger NICRs to smaller NICRs) to find a valid insert position
     * @param _troveManager TroveManager contract, passed in as param to save SLOAD’s
     * @param _collateral Address for the collateral whose list is going to be traversed
     * @param _NICR Node's NICR
     * @param _startId Id of node to start descending the list from
     */
    function _descendList(ITroveManager _troveManager, address _collateral, uint256 _NICR, address _startId) internal view returns (address, address) {
        // If `_startId` is the head, check if the insert position is before the head
        if (data[_collateral].head == _startId && _NICR >= _troveManager.getNominalICR(_startId, _collateral)) {
            return (address(0), _startId);
        }

        address prevId = _startId;
        address nextId = data[_collateral].nodes[prevId].nextId;

        // Descend the list until we reach the end or until we find a valid insert position
        while (prevId != address(0) && !_validInsertPosition(_troveManager, _collateral, _NICR, prevId, nextId)) {
            prevId = data[_collateral].nodes[prevId].nextId;
            nextId = data[_collateral].nodes[prevId].nextId;
        }

        return (prevId, nextId);
    }

    /*
     * @dev Ascend the list (smaller NICRs to larger NICRs) to find a valid insert position
     * @param _troveManager TroveManager contract, passed in as param to save SLOAD’s
     * @param _collateral Address for the collateral whose list is going to be traversed
     * @param _NICR Node's NICR
     * @param _startId Id of node to start ascending the list from
     */
    function _ascendList(ITroveManager _troveManager, address _collateral, uint256 _NICR, address _startId) internal view returns (address, address) {
        // If `_startId` is the tail, check if the insert position is after the tail
        if (data[_collateral].tail == _startId && _NICR <= _troveManager.getNominalICR(_startId, _collateral)) {
            return (_startId, address(0));
        }

        address nextId = _startId;
        address prevId = data[_collateral].nodes[nextId].prevId;

        // Ascend the list until we reach the end or until we find a valid insertion point
        while (nextId != address(0) && !_validInsertPosition(_troveManager, _collateral, _NICR, prevId, nextId)) {
            nextId = data[_collateral].nodes[nextId].prevId;
            prevId = data[_collateral].nodes[nextId].prevId;
        }

        return (prevId, nextId);
    }

    /*
     * @dev Find the insert position for a new node with the given NICR
     * @param _collateral Address of collateral whose list is being checked against
     * @param _NICR Node's NICR
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function findInsertPosition(address _collateral, uint256 _NICR, address _prevId, address _nextId) external view override returns (address, address) {
        return _findInsertPosition(troveManager, _collateral, _NICR, _prevId, _nextId);
    }

    function _findInsertPosition(ITroveManager _troveManager, address _collateral, uint256 _NICR, address _prevId, address _nextId) internal view returns (address, address) {
        address prevId = _prevId;
        address nextId = _nextId;

        if (prevId != address(0)) {
            if (!contains(_collateral, prevId) || _NICR > _troveManager.getNominalICR(prevId, _collateral)) {
                // `prevId` does not exist anymore or now has a smaller NICR than the given NICR
                prevId = address(0);
            }
        }

        if (nextId != address(0)) {
            if (!contains(_collateral, nextId) || _NICR < _troveManager.getNominalICR(nextId, _collateral)) {
                // `nextId` does not exist anymore or now has a larger NICR than the given NICR
                nextId = address(0);
            }
        }

        if (prevId == address(0) && nextId == address(0)) {
            // No hint - descend list starting from head
            return _descendList(_troveManager, _collateral, _NICR, data[_collateral].head);
        } else if (prevId == address(0)) {
            // No `prevId` for hint - ascend list starting from `nextId`
            return _ascendList(_troveManager, _collateral, _NICR, nextId);
        } else if (nextId == address(0)) {
            // No `nextId` for hint - descend list starting from `prevId`
            return _descendList(_troveManager, _collateral, _NICR, prevId);
        } else {
            // Descend list starting from `prevId`
            return _descendList(_troveManager, _collateral, _NICR, prevId);
        }
    }

    // --- 'require' functions ---

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == address(troveManager), "SortedTroves: Caller is not the TroveManager");
    }

    function _requireCallerIsBOorTroveM(ITroveManager _troveManager) internal view {
        require(msg.sender == borrowerOperationsAddress || msg.sender == address(_troveManager),
                "SortedTroves: Caller is neither BO nor TroveM");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import './Interfaces/IBorrowerOperations.sol';
import "./Interfaces/ICollateralConfig.sol";
import './Interfaces/IStabilityPool.sol';
import './Interfaces/IBorrowerOperations.sol';
import './Interfaces/ITroveManager.sol';
import './Interfaces/ILUSDToken.sol';
import './Interfaces/ISortedTroves.sol';
import "./Interfaces/ICommunityIssuance.sol";
import "./Dependencies/LiquityBase.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/LiquitySafeMath128.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/SafeERC20.sol";

/*
 * The Stability Pool holds LUSD tokens deposited by Stability Pool depositors.
 *
 * When a trove is liquidated, then depending on system conditions, some of its LUSD debt gets offset with
 * LUSD in the Stability Pool:  that is, the offset debt evaporates, and an equal amount of LUSD tokens in the Stability Pool is burned.
 *
 * Thus, a liquidation causes each depositor to receive a LUSD loss, in proportion to their deposit as a share of total deposits.
 * They also receive a collateral gain, as the collateral of the liquidated trove is distributed among Stability depositors,
 * in the same proportion.
 *
 * When a liquidation occurs, it depletes every deposit by the same fraction: for example, a liquidation that depletes 40%
 * of the total LUSD in the Stability Pool, depletes 40% of each deposit.
 *
 * A deposit that has experienced a series of liquidations is termed a "compounded deposit": each liquidation depletes the deposit,
 * multiplying it by some factor in range ]0,1[
 *
 *
 * --- IMPLEMENTATION ---
 *
 * We use a highly scalable method of tracking deposits and collateral gains that has O(1) complexity.
 *
 * When a liquidation occurs, rather than updating each depositor's deposit and collateral gain, we simply update two state variables:
 * a product P, and a sum S.
 *
 * A mathematical manipulation allows us to factor out the initial deposit, and accurately track all depositors' compounded deposits
 * and accumulated collateral gains over time, as liquidations occur, using just these two variables P and S. When depositors join the
 * Stability Pool, they get a snapshot of the latest P and S: P_t and S_t, respectively.
 *
 * The formula for a depositor's accumulated collateral gain is derived here:
 * https://github.com/liquity/dev/blob/main/packages/contracts/mathProofs/Scalable%20Compounding%20Stability%20Pool%20Deposits.pdf
 *
 * For a given deposit d_t, the ratio P/P_t tells us the factor by which a deposit has decreased since it joined the Stability Pool,
 * and the term d_t * (S - S_t)/P_t gives us the deposit's total accumulated collateral gain.
 *
 * Each liquidation updates the product P and sum S. After a series of liquidations, a compounded deposit and corresponding collateral gain
 * can be calculated using the initial deposit, the depositor’s snapshots of P and S, and the latest values of P and S.
 *
 * Any time a depositor updates their deposit (withdrawal, top-up) their accumulated collateral gain is paid out, their new deposit is recorded
 * (based on their latest compounded deposit and modified by the withdrawal/top-up), and they receive new snapshots of the latest P and S.
 * Essentially, they make a fresh deposit that overwrites the old one.
 *
 *
 * --- SCALE FACTOR ---
 *
 * Since P is a running product in range ]0,1] that is always-decreasing, it should never reach 0 when multiplied by a number in range ]0,1[.
 * Unfortunately, Solidity floor division always reaches 0, sooner or later.
 *
 * A series of liquidations that nearly empty the Pool (and thus each multiply P by a very small number in range ]0,1[ ) may push P
 * to its 18 digit decimal limit, and round it to 0, when in fact the Pool hasn't been emptied: this would break deposit tracking.
 *
 * So, to track P accurately, we use a scale factor: if a liquidation would cause P to decrease to <1e-9 (and be rounded to 0 by Solidity),
 * we first multiply P by 1e9, and increment a currentScale factor by 1.
 *
 * The added benefit of using 1e9 for the scale factor (rather than 1e18) is that it ensures negligible precision loss close to the 
 * scale boundary: when P is at its minimum value of 1e9, the relative precision loss in P due to floor division is only on the 
 * order of 1e-9. 
 *
 * --- EPOCHS ---
 *
 * Whenever a liquidation fully empties the Stability Pool, all deposits should become 0. However, setting P to 0 would make P be 0
 * forever, and break all future reward calculations.
 *
 * So, every time the Stability Pool is emptied by a liquidation, we reset P = 1 and currentScale = 0, and increment the currentEpoch by 1.
 *
 * --- TRACKING DEPOSIT OVER SCALE CHANGES AND EPOCHS ---
 *
 * When a deposit is made, it gets snapshots of the currentEpoch and the currentScale.
 *
 * When calculating a compounded deposit, we compare the current epoch to the deposit's epoch snapshot. If the current epoch is newer,
 * then the deposit was present during a pool-emptying liquidation, and necessarily has been depleted to 0.
 *
 * Otherwise, we then compare the current scale to the deposit's scale snapshot. If they're equal, the compounded deposit is given by d_t * P/P_t.
 * If it spans one scale change, it is given by d_t * P/(P_t * 1e9). If it spans more than one scale change, we define the compounded deposit
 * as 0, since it is now less than 1e-9'th of its initial value (e.g. a deposit of 1 billion LUSD has depleted to < 1 LUSD).
 *
 *
 *  --- TRACKING DEPOSITOR'S COLLATERAL GAIN OVER SCALE CHANGES AND EPOCHS ---
 *
 * In the current epoch, the latest value of S is stored upon each scale change, and the mapping (scale -> S) is stored for each epoch.
 *
 * This allows us to calculate a deposit's accumulated collateral gain, during the epoch in which the deposit was non-zero and earned collateral.
 *
 * We calculate the depositor's accumulated collateral gain for the scale at which they made the deposit, using the collateral gain formula:
 * e_1 = d_t * (S - S_t) / P_t
 *
 * and also for scale after, taking care to divide the latter by a factor of 1e9:
 * e_2 = d_t * S / (P_t * 1e9)
 *
 * The gain in the second scale will be full, as the starting point was in the previous scale, thus no need to subtract anything.
 * The deposit therefore was present for reward events from the beginning of that second scale.
 *
 *        S_i-S_t + S_{i+1}
 *      .<--------.------------>
 *      .         .
 *      . S_i     .   S_{i+1}
 *   <--.-------->.<----------->
 *   S_t.         .
 *   <->.         .
 *      t         .
 *  |---+---------|-------------|-----...
 *         i            i+1
 *
 * The sum of (e_1 + e_2) captures the depositor's total accumulated collateral gain, handling the case where their
 * deposit spanned one scale change. We only care about gains across one scale change, since the compounded
 * deposit is defined as being 0 once it has spanned more than one scale change.
 *
 *
 * --- UPDATING P WHEN A LIQUIDATION OCCURS ---
 *
 * Please see the implementation spec in the proof document, which closely follows on from the compounded deposit / collateral gain derivations:
 * https://github.com/liquity/liquity/blob/master/papers/Scalable_Reward_Distribution_with_Compounding_Stakes.pdf
 *
 *
 * --- LQTY ISSUANCE TO STABILITY POOL DEPOSITORS ---
 *
 * An LQTY issuance event occurs at every deposit operation, and every liquidation. All deposits earn a share of the issued LQTY
 * in proportion to the deposit as a share of total deposits.
 *
 * Please see the system Readme for an overview:
 * https://github.com/liquity/dev/blob/main/README.md#lqty-issuance-to-stability-providers
 *
 * We use the same mathematical product-sum approach to track LQTY gains for depositors, where 'G' is the sum corresponding to LQTY gains.
 * The product P (and snapshot P_t) is re-used, as the ratio P/P_t tracks a deposit's depletion due to liquidations.
 *
 */
contract StabilityPool is LiquityBase, Ownable, CheckContract, IStabilityPool {
    using LiquitySafeMath128 for uint128;
    using SafeERC20 for IERC20;

    string constant public NAME = "StabilityPool";

    IBorrowerOperations public borrowerOperations;

    ICollateralConfig public collateralConfig;

    ITroveManager public troveManager;

    ILUSDToken public lusdToken;

    address public lqtyTokenAddress;

    // Needed to check if there are pending liquidations
    ISortedTroves public sortedTroves;

    ICommunityIssuance public communityIssuance;

    mapping (address => uint256) internal collAmounts;  // deposited collateral tracker

    // Tracker for LUSD held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
    uint256 internal totalLUSDDeposits;

   // --- Data structures ---

    struct Deposit {
        uint initialValue;
    }

    struct Snapshots {
        mapping (address => uint) S;
        uint P;
        uint G;
        uint128 scale;
        uint128 epoch;
    }

    mapping (address => Deposit) public deposits;  // depositor address -> Deposit struct
    mapping (address => Snapshots) public depositSnapshots;  // depositor address -> snapshots struct

    /*  Product 'P': Running product by which to multiply an initial deposit, in order to find the current compounded deposit,
    * after a series of liquidations have occurred, each of which cancel some LUSD debt with the deposit.
    *
    * During its lifetime, a deposit's value evolves from d_t to d_t * P / P_t , where P_t
    * is the snapshot of P taken at the instant the deposit was made. 18-digit decimal.
    */
    uint public P = DECIMAL_PRECISION;

    uint public constant SCALE_FACTOR = 1e9;

    // Each time the scale of P shifts by SCALE_FACTOR, the scale is incremented by 1
    uint128 public currentScale;

    // With each offset that fully empties the Pool, the epoch is incremented by 1
    uint128 public currentEpoch;

    /* Collateral Gain sum 'S': During its lifetime, each deposit d_t earns a collateral gain of ( d_t * [S - S_t] )/P_t, where S_t
    * is the depositor's snapshot of S taken at the time t when the deposit was made.
    *
    * The 'S' sums are stored in a nested mapping (epoch => scale => collateral => sum):
    *
    * - The inner mapping records the sum S for each collateral
    * - The middle mapping records the (collateral => sum) mappings, at different scales.
    * - The outer mapping records the (scale => collateral => sum) mappings, for different epochs.
    */
    mapping (uint128 => mapping(uint128 => mapping (address => uint))) public epochToScaleToSum;

    /*
    * Similarly, the sum 'G' is used to calculate LQTY gains. During it's lifetime, each deposit d_t earns a LQTY gain of
    *  ( d_t * [G - G_t] )/P_t, where G_t is the depositor's snapshot of G taken at time t when  the deposit was made.
    *
    *  LQTY reward events occur are triggered by depositor operations (new deposit, topup, withdrawal), and liquidations.
    *  In each case, the LQTY reward is issued (i.e. G is updated), before other state changes are made.
    */
    mapping (uint128 => mapping(uint128 => uint)) public epochToScaleToG;

    // Error tracker for the error correction in the LQTY issuance calculation
    uint public lastLQTYError;
    // Error trackers for the error correction in the offset calculation
    mapping (address => uint) public lastCollateralError_Offset;
    uint public lastLUSDLossError_Offset;

    // --- Events ---

    event StabilityPoolCollateralBalanceUpdated(address _collateral, uint _newBalance);
    event StabilityPoolLUSDBalanceUpdated(uint _newBalance);

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event LUSDTokenAddressChanged(address _newLUSDTokenAddress);
    event SortedTrovesAddressChanged(address _newSortedTrovesAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event CommunityIssuanceAddressChanged(address _newCommunityIssuanceAddress);

    event P_Updated(uint _P);
    event S_Updated(address _collateral, uint _S, uint128 _epoch, uint128 _scale);
    event G_Updated(uint _G, uint128 _epoch, uint128 _scale);
    event EpochUpdated(uint128 _currentEpoch);
    event ScaleUpdated(uint128 _currentScale);

    event DepositSnapshotUpdated(address indexed _depositor, uint _P, address[] _assets, uint[] _amounts, uint _G);
    event UserDepositChanged(address indexed _depositor, uint _newDeposit);

    event CollateralGainWithdrawn(address indexed _depositor, address _collateral, uint _collAmount);
    event LQTYPaidToDepositor(address indexed _depositor, uint _LQTY);
    event CollateralSent(address _collateral, address _to, uint _amount);

    // --- Contract setters ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _collateralConfigAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _lusdTokenAddress,
        address _sortedTrovesAddress,
        address _priceFeedAddress,
        address _communityIssuanceAddress
    )
        external
        override
        onlyOwner
    {
        checkContract(_borrowerOperationsAddress);
        checkContract(_collateralConfigAddress);
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);
        checkContract(_lusdTokenAddress);
        checkContract(_sortedTrovesAddress);
        checkContract(_priceFeedAddress);
        checkContract(_communityIssuanceAddress);

        borrowerOperations = IBorrowerOperations(_borrowerOperationsAddress);
        collateralConfig = ICollateralConfig(_collateralConfigAddress);
        troveManager = ITroveManager(_troveManagerAddress);
        activePool = IActivePool(_activePoolAddress);
        lusdToken = ILUSDToken(_lusdTokenAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        communityIssuance = ICommunityIssuance(_communityIssuanceAddress);

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit LUSDTokenAddressChanged(_lusdTokenAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit CommunityIssuanceAddressChanged(_communityIssuanceAddress);

        renounceOwnership();
    }

    // --- Getters for public variables. Required by IPool interface ---

    function getCollateral(address _collateral) external view override returns (uint) {
        return collAmounts[_collateral];
    }

    function getTotalLUSDDeposits() external view override returns (uint) {
        return totalLUSDDeposits;
    }

    // --- External Depositor Functions ---

    /*  provideToSP():
    *
    * - Triggers a LQTY issuance, based on time passed since the last issuance. The LQTY issuance is shared between *all* depositors
    * - Sends depositor's accumulated gains to depositor
    * - Increases depositor's deposit, and takes new snapshot.
    */
    function provideToSP(uint _amount) external override {
        _requireNonZeroAmount(_amount);

        uint initialDeposit = deposits[msg.sender].initialValue;

        ICommunityIssuance communityIssuanceCached = communityIssuance;

        _triggerLQTYIssuance(communityIssuanceCached);

        (address[] memory assets, uint[] memory amounts) = getDepositorCollateralGain(msg.sender);
        uint compoundedLUSDDeposit = getCompoundedLUSDDeposit(msg.sender);

        /* TODO tess3rac7 unused var, but previously included in ETHGainWithdrawn event log.
         * Doesn't make a lot of sense to include in multiple CollateralGainWithdrawn logs.
         * If needed could create a separate event just to report this.
         */
        uint LUSDLoss = initialDeposit.sub(compoundedLUSDDeposit); // Needed only for event log

        // First pay out any LQTY gains
        _payOutLQTYGains(communityIssuanceCached, msg.sender);

        _sendLUSDtoStabilityPool(msg.sender, _amount);

        uint newDeposit = compoundedLUSDDeposit.add(_amount);
        _updateDepositAndSnapshots(msg.sender, newDeposit);
        emit UserDepositChanged(msg.sender, newDeposit);

        uint numCollaterals = assets.length;
        for (uint i = 0; i < numCollaterals; i++) {
            address collateral = assets[i];
            uint amount = amounts[i];
            emit CollateralGainWithdrawn(msg.sender, collateral, amount);
            _sendCollateralGainToDepositor(collateral, amount);
        }
     }

    /*  withdrawFromSP():
    *
    * - Triggers a LQTY issuance, based on time passed since the last issuance. The LQTY issuance is shared between *all* depositors
    * - Sends all depositor's accumulated gains to depositor
    * - Decreases depositor's deposit, and takes new snapshot.
    *
    * If _amount > userDeposit, the user withdraws all of their compounded deposit.
    */
    function withdrawFromSP(uint _amount) external override {
        if (_amount !=0) {_requireNoUnderCollateralizedTroves();}
        uint initialDeposit = deposits[msg.sender].initialValue;
        _requireUserHasDeposit(initialDeposit);

        ICommunityIssuance communityIssuanceCached = communityIssuance;

        _triggerLQTYIssuance(communityIssuanceCached);

        (address[] memory assets, uint[] memory amounts) = getDepositorCollateralGain(msg.sender);
        uint compoundedLUSDDeposit = getCompoundedLUSDDeposit(msg.sender);
        uint LUSDtoWithdraw = LiquityMath._min(_amount, compoundedLUSDDeposit);

        /* TODO tess3rac7 unused var, but previously included in ETHGainWithdrawn event log.
         * Doesn't make a lot of sense to include in multiple CollateralGainWithdrawn logs.
         * If needed could create a separate event just to report this.
         */
        uint LUSDLoss = initialDeposit.sub(compoundedLUSDDeposit); // Needed only for event log

        // First pay out any LQTY gains
        _payOutLQTYGains(communityIssuanceCached, msg.sender);
        
        _sendLUSDToDepositor(msg.sender, LUSDtoWithdraw);

        // Update deposit
        uint newDeposit = compoundedLUSDDeposit.sub(LUSDtoWithdraw);
        _updateDepositAndSnapshots(msg.sender, newDeposit);
        emit UserDepositChanged(msg.sender, newDeposit);

        uint numCollaterals = assets.length;
        for (uint i = 0; i < numCollaterals; i++) {
            address collateral = assets[i];
            uint amount = amounts[i];
            emit CollateralGainWithdrawn(msg.sender, collateral, amount);
            _sendCollateralGainToDepositor(collateral, amount);
        }
    }

    /*
     * A depositor's snapshot struct now contains a mapping for the running sum (S) for each collateral.
     * Mappings within a struct are not accessible via the auto-generated getters in the ABI, so we provide
     * this separate function that will return the specified depositor's "S" snapshot for the given collateral.
     */
    function depositSnapshots_S(address _depositor, address _collateral) external override view returns (uint) {
        return depositSnapshots[_depositor].S[_collateral];
    }

    // --- LQTY issuance functions ---

    function _triggerLQTYIssuance(ICommunityIssuance _communityIssuance) internal {
        uint LQTYIssuance = _communityIssuance.issueOath();
       _updateG(LQTYIssuance);
    }

    function _updateG(uint _LQTYIssuance) internal {
        uint totalLUSD = totalLUSDDeposits; // cached to save an SLOAD
        /*
        * When total deposits is 0, G is not updated. In this case, the LQTY issued can not be obtained by later
        * depositors - it is missed out on, and remains in the balanceof the CommunityIssuance contract.
        *
        */
        if (totalLUSD == 0 || _LQTYIssuance == 0) {return;}

        uint LQTYPerUnitStaked;
        LQTYPerUnitStaked =_computeLQTYPerUnitStaked(_LQTYIssuance, totalLUSD);

        uint marginalLQTYGain = LQTYPerUnitStaked.mul(P);
        epochToScaleToG[currentEpoch][currentScale] = epochToScaleToG[currentEpoch][currentScale].add(marginalLQTYGain);

        emit G_Updated(epochToScaleToG[currentEpoch][currentScale], currentEpoch, currentScale);
    }

    function _computeLQTYPerUnitStaked(uint _LQTYIssuance, uint _totalLUSDDeposits) internal returns (uint) {
        /*  
        * Calculate the LQTY-per-unit staked.  Division uses a "feedback" error correction, to keep the 
        * cumulative error low in the running total G:
        *
        * 1) Form a numerator which compensates for the floor division error that occurred the last time this 
        * function was called.  
        * 2) Calculate "per-unit-staked" ratio.
        * 3) Multiply the ratio back by its denominator, to reveal the current floor division error.
        * 4) Store this error for use in the next correction when this function is called.
        * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
        */
        uint LQTYNumerator = _LQTYIssuance.mul(DECIMAL_PRECISION).add(lastLQTYError);

        uint LQTYPerUnitStaked = LQTYNumerator.div(_totalLUSDDeposits);
        lastLQTYError = LQTYNumerator.sub(LQTYPerUnitStaked.mul(_totalLUSDDeposits));

        return LQTYPerUnitStaked;
    }

    // --- Liquidation functions ---

    /*
    * Cancels out the specified debt against the LUSD contained in the Stability Pool (as far as possible)
    * and transfers the Trove's collateral from ActivePool to StabilityPool.
    * Only called by liquidation functions in the TroveManager.
    */
    function offset(address _collateral, uint _debtToOffset, uint _collToAdd) external override {
        _requireCallerIsTroveManager();
        uint totalLUSD = totalLUSDDeposits; // cached to save an SLOAD
        if (totalLUSD == 0 || _debtToOffset == 0) { return; }

        _triggerLQTYIssuance(communityIssuance);

        (uint collGainPerUnitStaked,
            uint LUSDLossPerUnitStaked) = _computeRewardsPerUnitStaked(_collateral, _collToAdd, _debtToOffset, totalLUSD);

        _updateRewardSumAndProduct(_collateral, collGainPerUnitStaked, LUSDLossPerUnitStaked);  // updates S and P

        _moveOffsetCollAndDebt(_collateral, _collToAdd, _debtToOffset);
    }

    /*
    * Updates the reward sum for the specified collateral. A trimmed down version of "offset()" that doesn't
    * concern itself with any debt to offset or LUSD loss. Only called by ActivePool when distributing
    * yield farming rewards.
    */
    function updateRewardSum(address _collateral, uint _collToAdd) external override {
        _requireCallerIsActivePool();
        uint totalLUSD = totalLUSDDeposits; // cached to save an SLOAD
        if (totalLUSD == 0) { return; }

        _triggerLQTYIssuance(communityIssuance);

        (uint collGainPerUnitStaked, ) = _computeRewardsPerUnitStaked(_collateral, _collToAdd, 0, totalLUSD);

        _updateRewardSumAndProduct(_collateral, collGainPerUnitStaked, 0);  // updates S

        uint sum = collAmounts[_collateral].add(_collToAdd);
        collAmounts[_collateral] = sum;
        emit StabilityPoolCollateralBalanceUpdated(_collateral, sum);
    }

    // --- Offset helper functions ---

    function _computeRewardsPerUnitStaked(
        address _collateral,
        uint _collToAdd,
        uint _debtToOffset,
        uint _totalLUSDDeposits
    )
        internal
        returns (uint collGainPerUnitStaked, uint LUSDLossPerUnitStaked)
    {
        /*
        * Compute the LUSD and collateral rewards. Uses a "feedback" error correction, to keep
        * the cumulative error in the P and S state variables low:
        *
        * 1) Form numerators which compensate for the floor division errors that occurred the last time this 
        * function was called.  
        * 2) Calculate "per-unit-staked" ratios.
        * 3) Multiply each ratio back by its denominator, to reveal the current floor division error.
        * 4) Store these errors for use in the next correction when this function is called.
        * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
        */
        uint collNumerator = _collToAdd.mul(DECIMAL_PRECISION).add(lastCollateralError_Offset[_collateral]);

        assert(_debtToOffset <= _totalLUSDDeposits);
        if (_debtToOffset == _totalLUSDDeposits) {
            LUSDLossPerUnitStaked = DECIMAL_PRECISION;  // When the Pool depletes to 0, so does each deposit 
            lastLUSDLossError_Offset = 0;
        } else {
            uint LUSDLossNumerator = _debtToOffset.mul(DECIMAL_PRECISION).sub(lastLUSDLossError_Offset);
            /*
            * Add 1 to make error in quotient positive. We want "slightly too much" LUSD loss,
            * which ensures the error in any given compoundedLUSDDeposit favors the Stability Pool.
            */
            LUSDLossPerUnitStaked = (LUSDLossNumerator.div(_totalLUSDDeposits)).add(1);
            lastLUSDLossError_Offset = (LUSDLossPerUnitStaked.mul(_totalLUSDDeposits)).sub(LUSDLossNumerator);
        }

        collGainPerUnitStaked = collNumerator.div(_totalLUSDDeposits);
        lastCollateralError_Offset[_collateral] = collNumerator.sub(collGainPerUnitStaked.mul(_totalLUSDDeposits));

        return (collGainPerUnitStaked, LUSDLossPerUnitStaked);
    }

    // Update the Stability Pool reward sum S and product P
    function _updateRewardSumAndProduct(address _collateral, uint _collGainPerUnitStaked, uint _LUSDLossPerUnitStaked) internal {
        uint currentP = P;
        uint newP;

        assert(_LUSDLossPerUnitStaked <= DECIMAL_PRECISION);
        /*
        * The newProductFactor is the factor by which to change all deposits, due to the depletion of Stability Pool LUSD in the liquidation.
        * We make the product factor 0 if there was a pool-emptying. Otherwise, it is (1 - LUSDLossPerUnitStaked)
        */
        uint newProductFactor = uint(DECIMAL_PRECISION).sub(_LUSDLossPerUnitStaked);

        uint128 currentScaleCached = currentScale;
        uint128 currentEpochCached = currentEpoch;
        uint currentS = epochToScaleToSum[currentEpochCached][currentScaleCached][_collateral];

        /*
        * Calculate the new S first, before we update P.
        * The collateral gain for any given depositor from a liquidation depends on the value of their deposit
        * (and the value of totalDeposits) prior to the Stability being depleted by the debt in the liquidation.
        *
        * Since S corresponds to collateral gain, and P to deposit loss, we update S first.
        */
        uint marginalCollGain = _collGainPerUnitStaked.mul(currentP);
        uint newS = currentS.add(marginalCollGain);
        epochToScaleToSum[currentEpochCached][currentScaleCached][_collateral] = newS;
        emit S_Updated(_collateral, newS, currentEpochCached, currentScaleCached);

        // If the Stability Pool was emptied, increment the epoch, and reset the scale and product P
        if (newProductFactor == 0) {
            currentEpoch = currentEpochCached.add(1);
            emit EpochUpdated(currentEpoch);
            currentScale = 0;
            emit ScaleUpdated(currentScale);
            newP = DECIMAL_PRECISION;

        // If multiplying P by a non-zero product factor would reduce P below the scale boundary, increment the scale
        } else if (currentP.mul(newProductFactor).div(DECIMAL_PRECISION) < SCALE_FACTOR) {
            newP = currentP.mul(newProductFactor).mul(SCALE_FACTOR).div(DECIMAL_PRECISION); 
            currentScale = currentScaleCached.add(1);
            emit ScaleUpdated(currentScale);
        } else {
            newP = currentP.mul(newProductFactor).div(DECIMAL_PRECISION);
        }

        assert(newP > 0);
        P = newP;

        emit P_Updated(newP);
    }

    function _moveOffsetCollAndDebt(address _collateral, uint _collToAdd, uint _debtToOffset) internal {
        IActivePool activePoolCached = activePool;

        // Cancel the liquidated LUSD debt with the LUSD in the stability pool
        activePoolCached.decreaseLUSDDebt(_collateral, _debtToOffset);
        _decreaseLUSD(_debtToOffset);

        // Burn the debt that was successfully offset
        lusdToken.burn(address(this), _debtToOffset);

        activePoolCached.sendCollateral(_collateral, address(this), _collToAdd);
        uint sum = collAmounts[_collateral].add(_collToAdd);
        collAmounts[_collateral] = sum;
        emit StabilityPoolCollateralBalanceUpdated(_collateral, sum);
    }

    function _decreaseLUSD(uint _amount) internal {
        uint newTotalLUSDDeposits = totalLUSDDeposits.sub(_amount);
        totalLUSDDeposits = newTotalLUSDDeposits;
        emit StabilityPoolLUSDBalanceUpdated(newTotalLUSDDeposits);
    }

    // --- Reward calculator functions for depositor ---

    /* Calculates the collateral gain earned by the deposit since its last snapshots were taken.
    * Given by the formula:  E = d0 * (S - S(0))/P(0)
    * where S(0) and P(0) are the depositor's snapshots of the sum S and product P, respectively.
    * d0 is the last recorded deposit value.
    */
    function getDepositorCollateralGain(address _depositor) public view override returns (address[] memory assets, uint[] memory amounts) {
        uint initialDeposit = deposits[_depositor].initialValue;

        if (initialDeposit != 0) { 
            Snapshots storage snapshots = depositSnapshots[_depositor];

            return _getCollateralGainFromSnapshots(initialDeposit, snapshots);
        }

    }

    function _getCollateralGainFromSnapshots(uint initialDeposit, Snapshots storage snapshots) internal view returns (address[] memory assets, uint[] memory amounts) {
        assets = collateralConfig.getAllowedCollaterals();
        amounts = new uint[](assets.length);
        for (uint i = 0; i < assets.length; i++) {
            amounts[i] = _getSingularCollateralGain(initialDeposit, assets[i], snapshots);
        }
    }

    // Due to "stack too deep" error
    struct LocalVariables_getSingularCollateralGain {
        uint256 collDecimals;
        uint128 epochSnapshot;
        uint128 scaleSnapshot;
        uint P_Snapshot;
        uint S_Snapshot;
        uint firstPortion;
        uint secondPortion;
        uint gain;
    }

    function _getSingularCollateralGain(uint _initialDeposit, address _collateral, Snapshots storage _snapshots) internal view returns (uint) {
        /*
        * Grab the sum 'S' from the epoch at which the stake was made. The collateral gain may span up to one scale change.
        * If it does, the second portion of the collateral gain is scaled by 1e9.
        * If the gain spans no scale change, the second portion will be 0.
        */
        LocalVariables_getSingularCollateralGain memory vars;
        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.epochSnapshot = _snapshots.epoch;
        vars.scaleSnapshot = _snapshots.scale;
        vars.P_Snapshot = _snapshots.P;
        vars.S_Snapshot = _snapshots.S[_collateral];

        vars.firstPortion = epochToScaleToSum[vars.epochSnapshot][vars.scaleSnapshot][_collateral].sub(vars.S_Snapshot);
        vars.secondPortion = epochToScaleToSum[vars.epochSnapshot][vars.scaleSnapshot.add(1)][_collateral].div(SCALE_FACTOR);

        vars.gain = _initialDeposit.mul(vars.firstPortion.add(vars.secondPortion)).div(vars.P_Snapshot).div(DECIMAL_PRECISION);
        return vars.gain;
    }

    /*
    * Calculate the LQTY gain earned by a deposit since its last snapshots were taken.
    * Given by the formula:  LQTY = d0 * (G - G(0))/P(0)
    * where G(0) and P(0) are the depositor's snapshots of the sum G and product P, respectively.
    * d0 is the last recorded deposit value.
    */
    function getDepositorLQTYGain(address _depositor) public view override returns (uint) {
        uint initialDeposit = deposits[_depositor].initialValue;
        if (initialDeposit == 0) {return 0;}

        Snapshots memory snapshots = depositSnapshots[_depositor];
        uint LQTYGain = _getLQTYGainFromSnapshots(initialDeposit, snapshots);

        return LQTYGain;
    }

    function _getLQTYGainFromSnapshots(uint initialDeposit, Snapshots memory snapshots) internal view returns (uint) {
       /*
        * Grab the sum 'G' from the epoch at which the stake was made. The LQTY gain may span up to one scale change.
        * If it does, the second portion of the LQTY gain is scaled by 1e9.
        * If the gain spans no scale change, the second portion will be 0.
        */
        uint128 epochSnapshot = snapshots.epoch;
        uint128 scaleSnapshot = snapshots.scale;
        uint G_Snapshot = snapshots.G;
        uint P_Snapshot = snapshots.P;

        uint firstPortion = epochToScaleToG[epochSnapshot][scaleSnapshot].sub(G_Snapshot);
        uint secondPortion = epochToScaleToG[epochSnapshot][scaleSnapshot.add(1)].div(SCALE_FACTOR);

        uint LQTYGain = initialDeposit.mul(firstPortion.add(secondPortion)).div(P_Snapshot).div(DECIMAL_PRECISION);

        return LQTYGain;
    }

    // --- Compounded deposit ---

    /*
    * Return the user's compounded deposit. Given by the formula:  d = d0 * P/P(0)
    * where P(0) is the depositor's snapshot of the product P, taken when they last updated their deposit.
    */
    function getCompoundedLUSDDeposit(address _depositor) public view override returns (uint) {
        uint initialDeposit = deposits[_depositor].initialValue;
        if (initialDeposit == 0) { return 0; }

        Snapshots memory snapshots = depositSnapshots[_depositor];

        uint compoundedDeposit = _getCompoundedDepositFromSnapshots(initialDeposit, snapshots);
        return compoundedDeposit;
    }

    // Internal function, used to calculcate compounded deposits.
    function _getCompoundedDepositFromSnapshots(
        uint initialDeposit,
        Snapshots memory snapshots
    )
        internal
        view
        returns (uint)
    {
        uint snapshot_P = snapshots.P;
        uint128 scaleSnapshot = snapshots.scale;
        uint128 epochSnapshot = snapshots.epoch;

        // If deposit was made before a pool-emptying event, then it has been fully cancelled with debt -- so, return 0
        if (epochSnapshot < currentEpoch) { return 0; }

        uint compoundedDeposit;
        uint128 scaleDiff = currentScale.sub(scaleSnapshot);

        /* Compute the compounded deposit. If a scale change in P was made during the deposit's lifetime,
        * account for it. If more than one scale change was made, then the deposit has decreased by a factor of
        * at least 1e-9 -- so return 0.
        */
        if (scaleDiff == 0) {
            compoundedDeposit = initialDeposit.mul(P).div(snapshot_P);
        } else if (scaleDiff == 1) {
            compoundedDeposit = initialDeposit.mul(P).div(snapshot_P).div(SCALE_FACTOR);
        } else { // if scaleDiff >= 2
            compoundedDeposit = 0;
        }

        /*
        * If compounded deposit is less than a billionth of the initial deposit, return 0.
        *
        * NOTE: originally, this line was in place to stop rounding errors making the deposit too large. However, the error
        * corrections should ensure the error in P "favors the Pool", i.e. any given compounded deposit should slightly less
        * than it's theoretical value.
        *
        * Thus it's unclear whether this line is still really needed.
        */
        if (compoundedDeposit < initialDeposit.div(1e9)) {return 0;}

        return compoundedDeposit;
    }

    // --- Sender functions for LUSD deposit, ETH gains and LQTY gains ---

    // Transfer the LUSD tokens from the user to the Stability Pool's address, and update its recorded LUSD
    function _sendLUSDtoStabilityPool(address _address, uint _amount) internal {
        lusdToken.sendToPool(_address, address(this), _amount);
        uint newTotalLUSDDeposits = totalLUSDDeposits.add(_amount);
        totalLUSDDeposits = newTotalLUSDDeposits;
        emit StabilityPoolLUSDBalanceUpdated(newTotalLUSDDeposits);
    }

    function _sendCollateralGainToDepositor(address _collateral, uint _amount) internal {
        if (_amount == 0) {return;}
        uint newCollAmount = collAmounts[_collateral].sub(_amount);
        collAmounts[_collateral] = newCollAmount;
        emit StabilityPoolCollateralBalanceUpdated(_collateral, newCollAmount);
        emit CollateralSent(_collateral, msg.sender, _amount);

        IERC20(_collateral).safeTransfer(msg.sender, _amount);
    }

    // Send LUSD to user and decrease LUSD in Pool
    function _sendLUSDToDepositor(address _depositor, uint LUSDWithdrawal) internal {
        if (LUSDWithdrawal == 0) {return;}

        lusdToken.returnFromPool(address(this), _depositor, LUSDWithdrawal);
        _decreaseLUSD(LUSDWithdrawal);
    }

    // --- Stability Pool Deposit Functionality ---

    function _updateDepositAndSnapshots(address _depositor, uint _newValue) internal {
        deposits[_depositor].initialValue = _newValue;

        address[] memory collaterals = collateralConfig.getAllowedCollaterals();
        uint[] memory amounts = new uint[](collaterals.length);

        if (_newValue == 0) {
            for (uint i = 0; i < collaterals.length; i++) {
                delete depositSnapshots[_depositor].S[collaterals[i]];
            }
            delete depositSnapshots[_depositor];
            emit DepositSnapshotUpdated(_depositor, 0, collaterals, amounts, 0);
            return;
        }
        uint128 currentScaleCached = currentScale;
        uint128 currentEpochCached = currentEpoch;
        uint currentP = P;

        // Get G for the current epoch and current scale
        uint currentG = epochToScaleToG[currentEpochCached][currentScaleCached];

        // Record new snapshots of the latest running product P, and sum G, for the depositor
        depositSnapshots[_depositor].P = currentP;
        depositSnapshots[_depositor].G = currentG;
        depositSnapshots[_depositor].scale = currentScaleCached;
        depositSnapshots[_depositor].epoch = currentEpochCached;

        // Record new snapshots of the latest running sum S for all collaterals for the depositor
        for (uint i = 0; i < collaterals.length; i++) {
            address collateral = collaterals[i];
            uint currentS = epochToScaleToSum[currentEpochCached][currentScaleCached][collateral];
            depositSnapshots[_depositor].S[collateral] = currentS;
            amounts[i] = currentS;
        }
        emit DepositSnapshotUpdated(_depositor, currentP, collaterals, amounts, currentG);
    }

    function _payOutLQTYGains(ICommunityIssuance _communityIssuance, address _depositor) internal {
        uint depositorLQTYGain = getDepositorLQTYGain(_depositor);
        _communityIssuance.sendOath(_depositor, depositorLQTYGain);
        emit LQTYPaidToDepositor(_depositor, depositorLQTYGain);
    }

    // --- 'require' functions ---

    function _requireCallerIsActivePool() internal view {
        require( msg.sender == address(activePool), "StabilityPool: Caller is not ActivePool");
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == address(troveManager), "StabilityPool: Caller is not TroveManager");
    }

    function _requireNoUnderCollateralizedTroves() internal {
        address[] memory collaterals = collateralConfig.getAllowedCollaterals();
        uint numCollaterals = collaterals.length;
        for (uint i = 0; i < numCollaterals; i++) {
            address collateral = collaterals[i];
            uint price = priceFeed.fetchPrice(collateral);
            address lowestTrove = sortedTroves.getLast(collateral);
            uint256 collMCR = collateralConfig.getCollateralMCR(collateral);
            uint ICR = troveManager.getCurrentICR(lowestTrove, collateral, price);
            require(ICR >= collMCR, "StabilityPool: Cannot withdraw while there are troves with ICR < MCR");
        }
    }

    function _requireUserHasDeposit(uint _initialDeposit) internal pure {
        require(_initialDeposit > 0, 'StabilityPool: User must have a non-zero deposit');
    }

    function _requireNonZeroAmount(uint _amount) internal pure {
        require(_amount > 0, 'StabilityPool: Amount must be non-zero');
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../ActivePool.sol";

contract ActivePoolTester is ActivePool {
    
    function unprotectedIncreaseLUSDDebt(address _collateral, uint _amount) external {
        LUSDDebt[_collateral] = LUSDDebt[_collateral].add(_amount);
    }

    function unprotectedPullCollateral(address _collateral, uint _amount) external {
        collAmount[_collateral] = collAmount[_collateral].add(_amount);
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../BorrowerOperations.sol";

/* Tester contract inherits from BorrowerOperations, and provides external functions 
for testing the parent's internal functions. */
contract BorrowerOperationsTester is BorrowerOperations {

    function getNewICRFromTroveChange
    (
        uint _coll, 
        uint _debt, 
        uint _collChange, 
        bool isCollIncrease, 
        uint _debtChange, 
        bool isDebtIncrease, 
        uint _price,
        uint256 _collDecimals
    ) 
    external
    pure
    returns (uint)
    {
        return _getNewICRFromTroveChange(
            _coll,
            _debt,
            _collChange,
            isCollIncrease,
            _debtChange,
            isDebtIncrease,
            _price,
            _collDecimals
        );
    }

    function getNewTCRFromTroveChange
    (
        address _collateral,
        uint _collChange, 
        bool isCollIncrease,  
        uint _debtChange, 
        bool isDebtIncrease, 
        uint _price
    ) 
    external 
    view
    returns (uint) 
    {
        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        return _getNewTCRFromTroveChange(
            _collateral,
            _collChange,
            isCollIncrease,
            _debtChange,
            isDebtIncrease,
            _price,
            collDecimals
        );
    }

    function getUSDValue(uint _coll, uint _price, uint256 _collDecimals) external pure returns (uint) {
        return _getUSDValue(_coll, _price, _collDecimals);
    }

    function callInternalAdjustLoan
    (
        address _borrower,
        address _collateral,
        uint _collTopUp,
        uint _collWithdrawal, 
        uint _debtChange, 
        bool _isDebtIncrease, 
        address _upperHint,
        address _lowerHint)
        external 
    {
        _adjustTrove(_borrower, _collateral, _collTopUp, _collWithdrawal, _debtChange, _isDebtIncrease, _upperHint, _lowerHint, 0);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../TroveManager.sol";

/* Tester contract inherits from TroveManager, and provides external functions 
for testing the parent's internal functions. */

contract TroveManagerTester is TroveManager {

    function computeICR(uint _coll, uint _debt, uint _price, uint _collDecimals) external pure returns (uint) {
        return LiquityMath._computeCR(_coll, _debt, _price, _collDecimals);
    }

    function getCollGasCompensation(uint _coll) external pure returns (uint) {
        return _getCollGasCompensation(_coll);
    }

    function getLUSDGasCompensation() external pure returns (uint) {
        return LUSD_GAS_COMPENSATION;
    }

    function getCompositeDebt(uint _debt) external pure returns (uint) {
        return _getCompositeDebt(_debt);
    }

    function unprotectedDecayBaseRateFromBorrowing() external returns (uint) {
        baseRate = _calcDecayedBaseRate();
        assert(baseRate >= 0 && baseRate <= DECIMAL_PRECISION);
        
        _updateLastFeeOpTime();
        return baseRate;
    }

    function minutesPassedSinceLastFeeOp() external view returns (uint) {
        return _minutesPassedSinceLastFeeOp();
    }

    function setLastFeeOpTimeToNow() external {
        lastFeeOperationTime = block.timestamp;
    }

    function setBaseRate(uint _baseRate) external {
        baseRate = _baseRate;
    }

    function callGetRedemptionFee(uint _ETHDrawn) external view returns (uint) {
        getRedemptionFee(_ETHDrawn);
    }  

    function getActualDebtFromComposite(uint _debtVal) external pure returns (uint) {
        return _getNetDebt(_debtVal);
    }

    function callInternalRemoveTroveOwner(address _troveOwner, address _collateral) external {
        uint troveOwnersArrayLength = TroveOwners[_collateral].length;
        _removeTroveOwner(_troveOwner, _collateral, troveOwnersArrayLength);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../LQTY/CommunityIssuance.sol";

contract CommunityIssuanceTester is CommunityIssuance {
    function unprotectedIssueLQTY() external returns (uint issuance) {
        if (lastIssuanceTimestamp < lastDistributionTime) {
            uint256 endTimestamp = block.timestamp > lastDistributionTime ? lastDistributionTime : block.timestamp;
            uint256 timePassed = endTimestamp.sub(lastIssuanceTimestamp);
            issuance = timePassed.mul(rewardPerSecond);
            totalOATHIssued = totalOATHIssued.add(issuance);
        }

        lastIssuanceTimestamp = block.timestamp;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../DefaultPool.sol";

contract DefaultPoolTester is DefaultPool {
    
    function unprotectedIncreaseLUSDDebt(address _collateral, uint _amount) external {
        LUSDDebt[_collateral]  = LUSDDebt[_collateral].add(_amount);
    }

    function unprotectedPullCollateral(address _collateral, uint _amount) external {
        collAmount[_collateral] = collAmount[_collateral].add(_amount);
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../TroveManager.sol";
import "../BorrowerOperations.sol";
import "../StabilityPool.sol";
import "../LUSDToken.sol";
import "../Dependencies/SafeERC20.sol";

contract EchidnaProxy {
    using SafeERC20 for IERC20;

    TroveManager troveManager;
    BorrowerOperations borrowerOperations;
    StabilityPool stabilityPool;
    LUSDToken lusdToken;

    constructor(
        TroveManager _troveManager,
        BorrowerOperations _borrowerOperations,
        StabilityPool _stabilityPool,
        LUSDToken _lusdToken
    ) public {
        troveManager = _troveManager;
        borrowerOperations = _borrowerOperations;
        stabilityPool = _stabilityPool;
        lusdToken = _lusdToken;
    }

    // TroveManager

    function liquidatePrx(address _user, address _collateral) external {
        troveManager.liquidate(_user, _collateral);
    }

    function liquidateTrovesPrx(address _collateral, uint _n) external {
        troveManager.liquidateTroves(_collateral, _n);
    }

    function batchLiquidateTrovesPrx(address _collateral, address[] calldata _troveArray) external {
        troveManager.batchLiquidateTroves(_collateral, _troveArray);
    }

    function redeemCollateralPrx(
        address _collateral,
        uint _LUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFee
    ) external {
        troveManager.redeemCollateral(_collateral, _LUSDAmount, _firstRedemptionHint, _upperPartialRedemptionHint, _lowerPartialRedemptionHint, _partialRedemptionHintNICR, _maxIterations, _maxFee);
    }

    // Borrower Operations
    function openTrovePrx(address _collateral, uint _collAmount, uint _LUSDAmount, address _upperHint, address _lowerHint, uint _maxFee) external {
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collAmount);
        IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), _collAmount);
        borrowerOperations.openTrove(_collateral, _collAmount, _maxFee, _LUSDAmount, _upperHint, _lowerHint);
    }

    function addCollPrx(address _collateral, uint _collAmount, address _upperHint, address _lowerHint) external {
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collAmount);
        IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), _collAmount);
        borrowerOperations.addColl(_collateral, _collAmount, _upperHint, _lowerHint);
    }

    function withdrawCollPrx(address _collateral, uint _amount, address _upperHint, address _lowerHint) external {
        borrowerOperations.withdrawColl(_collateral, _amount, _upperHint, _lowerHint);
    }

    function withdrawLUSDPrx(address _collateral, uint _amount, address _upperHint, address _lowerHint, uint _maxFee) external {
        borrowerOperations.withdrawLUSD(_collateral, _maxFee, _amount, _upperHint, _lowerHint);
    }

    function repayLUSDPrx(address _collateral, uint _amount, address _upperHint, address _lowerHint) external {
        borrowerOperations.repayLUSD(_collateral, _amount, _upperHint, _lowerHint);
    }

    function closeTrovePrx(address _collateral) external {
        borrowerOperations.closeTrove(_collateral);
    }

    function adjustTrovePrx(address _collateral, uint _collTopUp, uint _collWithdrawal, uint _debtChange, bool _isDebtIncrease, address _upperHint, address _lowerHint, uint _maxFee) external {
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collTopUp);
        IERC20(_collateral).safeIncreaseAllowance(address(borrowerOperations), _collTopUp);
        borrowerOperations.adjustTrove(_collateral, _maxFee, _collTopUp, _collWithdrawal, _debtChange, _isDebtIncrease, _upperHint, _lowerHint);
    }

    // Pool Manager
    function provideToSPPrx(uint _amount) external {
        stabilityPool.provideToSP(_amount);
    }

    function withdrawFromSPPrx(uint _amount) external {
        stabilityPool.withdrawFromSP(_amount);
    }

    // LUSD Token

    function transferPrx(address recipient, uint256 amount) external returns (bool) {
        return lusdToken.transfer(recipient, amount);
    }

    function approvePrx(address spender, uint256 amount) external returns (bool) {
        return lusdToken.approve(spender, amount);
    }

    function transferFromPrx(address sender, address recipient, uint256 amount) external returns (bool) {
        return lusdToken.transferFrom(sender, recipient, amount);
    }

    function increaseAllowancePrx(address spender, uint256 addedValue) external returns (bool) {
        return lusdToken.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowancePrx(address spender, uint256 subtractedValue) external returns (bool) {
        return lusdToken.decreaseAllowance(spender, subtractedValue);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../CollateralConfig.sol";
import "../TroveManager.sol";
import "../RedemptionHelper.sol";
import "../BorrowerOperations.sol";
import "../ActivePool.sol";
import "../DefaultPool.sol";
import "../StabilityPool.sol";
import "../GasPool.sol";
import "../CollSurplusPool.sol";
import "../LUSDToken.sol";
import "./PriceFeedTestnet.sol";
import "../SortedTroves.sol";
import "./EchidnaProxy.sol";
import "../Dependencies/SafeERC20.sol";
//import "../Dependencies/console.sol";

// Run with:
// rm -f fuzzTests/corpus/* # (optional)
// ~/.local/bin/echidna-test contracts/TestContracts/EchidnaTester.sol --contract EchidnaTester --config fuzzTests/echidna_config.yaml

contract EchidnaTester {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    uint constant private NUMBER_OF_ACTORS = 100;
    uint constant private INITIAL_BALANCE = 1e24;
    uint private MCR;
    uint private CCR;
    uint private LUSD_GAS_COMPENSATION;

    CollateralConfig public collateralConfig;
    TroveManager public troveManager;
    RedemptionHelper public redemptionHelper;
    BorrowerOperations public borrowerOperations;
    ActivePool public activePool;
    DefaultPool public defaultPool;
    StabilityPool public stabilityPool;
    GasPool public gasPool;
    CollSurplusPool public collSurplusPool;
    LUSDToken public lusdToken;
    PriceFeedTestnet priceFeedTestnet;
    SortedTroves sortedTroves;
    address[] collaterals;
    address[] erc4626vaults;

    EchidnaProxy[NUMBER_OF_ACTORS] public echidnaProxies;

    uint private numberOfTroves;

    constructor(
        address _treasuryAddress,
        address _collateral,
        address _erc4626vault,
        address _governance,
        address _guardian
    ) public {
        collateralConfig = new CollateralConfig();
        troveManager = new TroveManager();
        redemptionHelper = new RedemptionHelper();
        borrowerOperations = new BorrowerOperations();
        activePool = new ActivePool();
        defaultPool = new DefaultPool();
        stabilityPool = new StabilityPool();
        gasPool = new GasPool();
        lusdToken = new LUSDToken(
            address(troveManager),
            address(stabilityPool),
            address(borrowerOperations),
            _governance,
            _guardian
        );

        collSurplusPool = new CollSurplusPool();
        priceFeedTestnet = new PriceFeedTestnet();

        sortedTroves = new SortedTroves();
        collaterals.push(_collateral);
        erc4626vaults.push(_erc4626vault);

        uint256[] memory MCRs = new uint256[](1);
        MCRs[0] = collateralConfig.MIN_ALLOWED_MCR();

        uint256[] memory CCRs = new uint256[](1);
        CCRs[0] = collateralConfig.MIN_ALLOWED_CCR();

        collateralConfig.initialize(collaterals, MCRs, CCRs);

        troveManager.setAddresses(address(borrowerOperations), address(collateralConfig),
            address(activePool), address(defaultPool), 
            address(stabilityPool), address(gasPool), address(collSurplusPool),
            address(priceFeedTestnet), address(lusdToken), 
            address(sortedTroves), address(0), address(0), address(redemptionHelper));
       
        borrowerOperations.setAddresses(address(collateralConfig), address(troveManager), 
            address(activePool), address(defaultPool), 
            address(stabilityPool), address(gasPool), address(collSurplusPool),
            address(priceFeedTestnet), address(sortedTroves), 
            address(lusdToken), address(0));

        activePool.setAddresses(address(collateralConfig), address(borrowerOperations),
            address(troveManager), address(stabilityPool), address(defaultPool), address(collSurplusPool),
            _treasuryAddress, address(0), erc4626vaults);

        defaultPool.setAddresses(address(collateralConfig), address(troveManager), address(activePool));
        
        stabilityPool.setAddresses(address(borrowerOperations), address(collateralConfig),
            address(troveManager), address(activePool), address(lusdToken), 
            address(sortedTroves), address(priceFeedTestnet), address(0));

        collSurplusPool.setAddresses(address(collateralConfig), address(borrowerOperations), 
             address(troveManager), address(activePool));
    
        sortedTroves.setParams(address(troveManager), address(borrowerOperations));

        for (uint i = 0; i < NUMBER_OF_ACTORS; i++) {
            echidnaProxies[i] = new EchidnaProxy(troveManager, borrowerOperations, stabilityPool, lusdToken);
            // TODO tess3rac7 will need another way of sending initial ERC20 balances
            // (bool success, ) = address(echidnaProxies[i]).call{value: INITIAL_BALANCE}("");
            // require(success);
        }

        MCR = collateralConfig.MIN_ALLOWED_MCR();
        CCR = collateralConfig.MIN_ALLOWED_CCR();
        LUSD_GAS_COMPENSATION = borrowerOperations.LUSD_GAS_COMPENSATION();
        require(MCR > 0);
        require(CCR > 0);

        // TODO:
        priceFeedTestnet.setPrice(_collateral, 1e22);
    }

    // TroveManager

    function liquidateExt(uint _i, address _user) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].liquidatePrx(_user, collaterals[0]);
    }

    function liquidateTrovesExt(uint _i, uint _n) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].liquidateTrovesPrx(collaterals[0], _n);
    }

    function batchLiquidateTrovesExt(uint _i, address[] calldata _troveArray) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].batchLiquidateTrovesPrx(collaterals[0], _troveArray);
    }

    function redeemCollateralExt(
        uint _i,
        uint _LUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR
    ) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].redeemCollateralPrx(collaterals[0], _LUSDAmount, _firstRedemptionHint, _upperPartialRedemptionHint, _lowerPartialRedemptionHint, _partialRedemptionHintNICR, 0, 0);
    }

    // Borrower Operations

    function getAdjustedColl(uint actorBalance, uint _collAmount, uint ratio) internal view returns (uint) {
        uint price = priceFeedTestnet.getPrice(collaterals[0]);
        require(price > 0);
        uint minColl = ratio.mul(LUSD_GAS_COMPENSATION).div(price);
        require(actorBalance > minColl);
        uint coll = minColl + _collAmount % (actorBalance - minColl);
        return coll;
    }

    function getAdjustedLUSD(uint collAmount, uint _LUSDAmount, uint ratio) internal view returns (uint) {
        uint price = priceFeedTestnet.getPrice(collaterals[0]);
        uint LUSDAmount = _LUSDAmount;
        uint compositeDebt = LUSDAmount.add(LUSD_GAS_COMPENSATION);
        uint256 collDecimals = collateralConfig.getCollateralDecimals(collaterals[0]);
        uint ICR = LiquityMath._computeCR(collAmount, compositeDebt, price, collDecimals);
        if (ICR < ratio) {
            compositeDebt = collAmount.mul(price).div(ratio);
            LUSDAmount = compositeDebt.sub(LUSD_GAS_COMPENSATION);
        }
        return LUSDAmount;
    }

    function openTroveExt(uint _i, uint _collAmount, uint _LUSDAmount) public {
        uint actor = _i % NUMBER_OF_ACTORS;
        EchidnaProxy echidnaProxy = echidnaProxies[actor];
        uint actorBalance = IERC20(collaterals[0]).balanceOf(address(echidnaProxy));

        // we pass in CCR instead of MCR in case it’s the first one
        uint collAmount = getAdjustedColl(actorBalance, _collAmount, CCR);
        uint LUSDAmount = getAdjustedLUSD(collAmount, _LUSDAmount, CCR);

        //console.log('ETH', ETH);
        //console.log('LUSDAmount', LUSDAmount);

        echidnaProxy.openTrovePrx(collaterals[0], collAmount, LUSDAmount, address(0), address(0), 0);

        numberOfTroves = troveManager.getTroveOwnersCount(collaterals[0]);
        assert(numberOfTroves > 0);
        // canary
        //assert(numberOfTroves == 0);
    }

    function openTroveRawExt(uint _i, uint _collAmount, uint _LUSDAmount, address _upperHint, address _lowerHint, uint _maxFee) public {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].openTrovePrx(collaterals[0], _collAmount, _LUSDAmount, _upperHint, _lowerHint, _maxFee);
    }

    function addCollExt(uint _i, uint _collAmount) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        EchidnaProxy echidnaProxy = echidnaProxies[actor];
        uint actorBalance = IERC20(collaterals[0]).balanceOf(address(echidnaProxy));

        uint collAmount = getAdjustedColl(actorBalance, _collAmount, MCR);

        echidnaProxy.addCollPrx(collaterals[0], collAmount, address(0), address(0));
    }

    function addCollRawExt(uint _i, uint _collAmount, address _upperHint, address _lowerHint) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].addCollPrx(collaterals[0], _collAmount, _upperHint, _lowerHint);
    }

    function withdrawCollExt(uint _i, uint _amount, address _upperHint, address _lowerHint) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].withdrawCollPrx(collaterals[0], _amount, _upperHint, _lowerHint);
    }

    function withdrawLUSDExt(uint _i, uint _amount, address _upperHint, address _lowerHint, uint _maxFee) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].withdrawLUSDPrx(collaterals[0], _amount, _upperHint, _lowerHint, _maxFee);
    }

    function repayLUSDExt(uint _i, uint _amount, address _upperHint, address _lowerHint) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].repayLUSDPrx(collaterals[0], _amount, _upperHint, _lowerHint);
    }

    function closeTroveExt(uint _i) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].closeTrovePrx(collaterals[0]);
    }

    function adjustTroveExt(uint _i, uint _collTopUp, uint _collWithdrawal, uint _debtChange, bool _isDebtIncrease) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        EchidnaProxy echidnaProxy = echidnaProxies[actor];
        uint actorBalance = IERC20(collaterals[0]).balanceOf(address(echidnaProxy));

        uint collAmount = getAdjustedColl(actorBalance, _collTopUp, MCR);
        uint debtChange = _debtChange;
        if (_isDebtIncrease) {
            // TODO: add current amount already withdrawn:
            debtChange = getAdjustedLUSD(collAmount, uint(_debtChange), MCR);
        }
        // TODO: collWithdrawal, debtChange
        echidnaProxy.adjustTrovePrx(collaterals[0], collAmount, _collWithdrawal, debtChange, _isDebtIncrease, address(0), address(0), 0);
    }

    function adjustTroveRawExt(uint _i, uint _collTopUp, uint _collWithdrawal, uint _debtChange, bool _isDebtIncrease, address _upperHint, address _lowerHint, uint _maxFee) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].adjustTrovePrx(collaterals[0], _collTopUp, _collWithdrawal, _debtChange, _isDebtIncrease, _upperHint, _lowerHint, _maxFee);
    }

    // Pool Manager

    function provideToSPExt(uint _i, uint _amount) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].provideToSPPrx(_amount);
    }

    function withdrawFromSPExt(uint _i, uint _amount) external {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].withdrawFromSPPrx(_amount);
    }

    // LUSD Token

    function transferExt(uint _i, address recipient, uint256 amount) external returns (bool) {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].transferPrx(recipient, amount);
    }

    function approveExt(uint _i, address spender, uint256 amount) external returns (bool) {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].approvePrx(spender, amount);
    }

    function transferFromExt(uint _i, address sender, address recipient, uint256 amount) external returns (bool) {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].transferFromPrx(sender, recipient, amount);
    }

    function increaseAllowanceExt(uint _i, address spender, uint256 addedValue) external returns (bool) {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].increaseAllowancePrx(spender, addedValue);
    }

    function decreaseAllowanceExt(uint _i, address spender, uint256 subtractedValue) external returns (bool) {
        uint actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].decreaseAllowancePrx(spender, subtractedValue);
    }

    // PriceFeed

    function setPriceExt(uint256 _price) external {
        bool result = priceFeedTestnet.setPrice(collaterals[0], _price);
        assert(result);
    }

    // --------------------------
    // Invariants and properties
    // --------------------------

    function echidna_canary_number_of_troves() public view returns(bool) {
        if (numberOfTroves > 20) {
            return false;
        }

        return true;
    }

    function echidna_canary_active_pool_balance() public view returns(bool) {
        if (IERC20(collaterals[0]).balanceOf(address(activePool)) > 0) {
            return false;
        }
        return true;
    }

    function echidna_troves_order() external view returns(bool) {
        address currentTrove = sortedTroves.getFirst(collaterals[0]);
        address nextTrove = sortedTroves.getNext(collaterals[0], currentTrove);

        while (currentTrove != address(0) && nextTrove != address(0)) {
            if (troveManager.getNominalICR(nextTrove, collaterals[0]) > troveManager.getNominalICR(currentTrove, collaterals[0])) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            currentTrove = nextTrove;
            nextTrove = sortedTroves.getNext(collaterals[0], currentTrove);
        }

        return true;
    }

    /**
     * Status
     * Minimum debt (gas compensation)
     * Stake > 0
     */
    function echidna_trove_properties() public view returns(bool) {
        address currentTrove = sortedTroves.getFirst(collaterals[0]);
        while (currentTrove != address(0)) {
            // Status
            if (TroveManager.Status(troveManager.getTroveStatus(currentTrove, collaterals[0])) != TroveManager.Status.active) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            // Minimum debt (gas compensation)
            if (troveManager.getTroveDebt(currentTrove, collaterals[0]) < LUSD_GAS_COMPENSATION) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            // Stake > 0
            if (troveManager.getTroveStake(currentTrove, collaterals[0]) == 0) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            currentTrove = sortedTroves.getNext(collaterals[0], currentTrove);
        }
        return true;
    }

    function echidna_ETH_balances() public view returns(bool) {
        if (IERC20(collaterals[0]).balanceOf(address(troveManager)) > 0) {
            return false;
        }

        if (IERC20(collaterals[0]).balanceOf(address(borrowerOperations)) > 0) {
            return false;
        }

        if (IERC20(collaterals[0]).balanceOf(address(activePool)) != activePool.getCollateral(collaterals[0])) {
            return false;
        }

        if (IERC20(collaterals[0]).balanceOf(address(defaultPool)) != defaultPool.getCollateral(collaterals[0])) {
            return false;
        }

        if (IERC20(collaterals[0]).balanceOf(address(stabilityPool)) != stabilityPool.getCollateral(collaterals[0])) {
            return false;
        }

        if (IERC20(collaterals[0]).balanceOf(address(lusdToken)) > 0) {
            return false;
        }
    
        if (IERC20(collaterals[0]).balanceOf(address(priceFeedTestnet)) > 0) {
            return false;
        }
        
        if (IERC20(collaterals[0]).balanceOf(address(sortedTroves)) > 0) {
            return false;
        }

        return true;
    }

    // TODO: What should we do with this? Should it be allowed? Should it be a canary?
    function echidna_price() public view returns(bool) {
        uint price = priceFeedTestnet.getPrice(collaterals[0]);
        
        if (price == 0) {
            return false;
        }
        // Uncomment to check that the condition is meaningful
        //else return false;

        return true;
    }

    // Total LUSD matches
    function echidna_LUSD_global_balances() public view returns(bool) {
        uint totalSupply = lusdToken.totalSupply();
        uint gasPoolBalance = lusdToken.balanceOf(address(gasPool));

        uint activePoolBalance = activePool.getLUSDDebt(collaterals[0]);
        uint defaultPoolBalance = defaultPool.getLUSDDebt(collaterals[0]);
        if (totalSupply != activePoolBalance + defaultPoolBalance) {
            return false;
        }

        uint stabilityPoolBalance = stabilityPool.getTotalLUSDDeposits();
        address currentTrove = sortedTroves.getFirst(collaterals[0]);
        uint trovesBalance;
        while (currentTrove != address(0)) {
            trovesBalance += lusdToken.balanceOf(address(currentTrove));
            currentTrove = sortedTroves.getNext(collaterals[0], currentTrove);
        }
        // we cannot state equality because tranfers are made to external addresses too
        if (totalSupply <= stabilityPoolBalance + trovesBalance + gasPoolBalance) {
            return false;
        }

        return true;
    }

    /*
    function echidna_test() public view returns(bool) {
        return true;
    }
    */
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import '../Interfaces/ITroveManager.sol';
import '../Interfaces/ISortedTroves.sol';
import '../Interfaces/IPriceFeed.sol';
import '../Dependencies/LiquityMath.sol';

/* Wrapper contract - used for calculating gas of read-only and internal functions. 
Not part of the Liquity application. */
contract FunctionCaller {

    ITroveManager troveManager;
    address public troveManagerAddress;

    ISortedTroves sortedTroves;
    address public sortedTrovesAddress;

    IPriceFeed priceFeed;
    address public priceFeedAddress;

    // --- Dependency setters ---

    function setTroveManagerAddress(address _troveManagerAddress) external {
        troveManagerAddress = _troveManagerAddress;
        troveManager = ITroveManager(_troveManagerAddress);
    }
    
    function setSortedTrovesAddress(address _sortedTrovesAddress) external {
        troveManagerAddress = _sortedTrovesAddress;
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
    }

     function setPriceFeedAddress(address _priceFeedAddress) external {
        priceFeedAddress = _priceFeedAddress;
        priceFeed = IPriceFeed(_priceFeedAddress);
    }

    // --- Non-view wrapper functions used for calculating gas ---
    
    function troveManager_getCurrentICR(
        address _address,
        address _collateral,
        uint _price
    ) external view returns (uint) {
        return troveManager.getCurrentICR(_address, _collateral, _price);
    }

    function sortedTroves_findInsertPosition(address _collateral, uint _NICR, address _prevId, address _nextId) external view returns (address, address) {
        return sortedTroves.findInsertPosition(_collateral, _NICR, _prevId, _nextId);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/LiquityMath.sol";

/* Tester contract for math functions in Math.sol library. */

contract LiquityMathTester {

    function callMax(uint _a, uint _b) external pure returns (uint) {
        return LiquityMath._max(_a, _b);
    }

    // Non-view wrapper for gas test
    function callDecPowTx(uint _base, uint _n) external pure returns (uint) {
        return LiquityMath._decPow(_base, _n);
    }

    // External wrapper
    function callDecPow(uint _base, uint _n) external pure returns (uint) {
        return LiquityMath._decPow(_base, _n);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/LiquitySafeMath128.sol";

/* Tester contract for math functions in LiquitySafeMath128.sol library. */

contract LiquitySafeMath128Tester {
    using LiquitySafeMath128 for uint128;

    function add(uint128 a, uint128 b) external pure returns (uint128) {
        return a.add(b);
    }

    function sub(uint128 a, uint128 b) external pure returns (uint128) {
        return a.sub(b);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../LQTY/LQTYStaking.sol";


contract LQTYStakingTester is LQTYStaking {
    function requireCallerIsTroveManager() external view {
        _requireCallerIsTroveManagerOrActivePool();
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Interfaces/ILUSDToken.sol";

contract LUSDTokenCaller {
    ILUSDToken LUSD;

    function setLUSD(ILUSDToken _LUSD) external {
        LUSD = _LUSD;
    }

    function lusdMint(address _account, uint _amount) external {
        LUSD.mint(_account, _amount);
    }

    function lusdBurn(address _account, uint _amount) external {
        LUSD.burn(_account, _amount);
    }

    function lusdSendToPool(address _sender,  address _poolAddress, uint256 _amount) external {
        LUSD.sendToPool(_sender, _poolAddress, _amount);
    }

    function lusdReturnFromPool(address _poolAddress, address _receiver, uint256 _amount ) external {
        LUSD.returnFromPool(_poolAddress, _receiver, _amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../LUSDToken.sol";

contract LUSDTokenTester is LUSDToken {
    
    bytes32 private immutable _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    
    constructor( 
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress,
        address _governanceAddress,
        address _guardianAddress
    ) public LUSDToken(_troveManagerAddress,
                      _stabilityPoolAddress,
                      _borrowerOperationsAddress,
                      _governanceAddress,
                      _guardianAddress) {}
    
    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here

        _mint(_account, _amount);
    }

    function unprotectedBurn(address _account, uint _amount) external {
        // No check on caller here
        
        _burn(_account, _amount);
    }

    function unprotectedSendToPool(address _sender,  address _poolAddress, uint256 _amount) external {
        // No check on caller here

        _transfer(_sender, _poolAddress, _amount);
    }

    function unprotectedReturnFromPool(address _poolAddress, address _receiver, uint256 _amount ) external {
        // No check on caller here

        _transfer(_poolAddress, _receiver, _amount);
    }

    function callInternalApprove(address owner, address spender, uint256 amount) external returns (bool) {
        _approve(owner, spender, amount);
    }

    function getChainId() external pure returns (uint256 chainID) {
        //return _chainID(); // it’s private
        assembly {
            chainID := chainid()
        }
    }

    function getDigest(address owner, address spender, uint amount, uint nonce, uint deadline) external view returns (bytes32) {
        return keccak256(abi.encodePacked(
                uint16(0x1901),
                domainSeparator(),
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
            )
        );
    }

    function recoverAddress(bytes32 digest, uint8 v, bytes32 r, bytes32 s) external pure returns (address) {
        return ecrecover(digest, v, r, s);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Dependencies/AggregatorV3Interface.sol";
import "../Dependencies/console.sol";

contract MockAggregator is AggregatorV3Interface {
    
    // storage variables to hold the mock data
    uint8 private decimalsVal = 8;
    int private price;
    int private prevPrice;
    uint private updateTime;
    uint private prevUpdateTime;

    uint80 private latestRoundId;
    uint80 private prevRoundId;

    bool latestRevert;
    bool prevRevert;
    bool decimalsRevert;

    // --- Functions ---

    function setDecimals(uint8 _decimals) external {
        decimalsVal = _decimals;
    }

    function setPrice(int _price) external {
        price = _price;
    }

    function setPrevPrice(int _prevPrice) external {
        prevPrice = _prevPrice;
    }

    function setPrevUpdateTime(uint _prevUpdateTime) external {
        prevUpdateTime = _prevUpdateTime;
    }

    function setUpdateTime(uint _updateTime) external  {
        updateTime = _updateTime;
    }

    function setLatestRevert() external  {
        latestRevert = !latestRevert;
    }

    function setPrevRevert() external  {
        prevRevert = !prevRevert;
    }

    function setDecimalsRevert() external {
        decimalsRevert = !decimalsRevert;
    }

    function setLatestRoundId(uint80 _latestRoundId) external {
        latestRoundId = _latestRoundId;
    }

      function setPrevRoundId(uint80 _prevRoundId) external {
        prevRoundId = _prevRoundId;
    }
    

    // --- Getters that adhere to the AggregatorV3 interface ---

    function decimals() external override view returns (uint8) {
        if (decimalsRevert) {require(1== 0, "decimals reverted");}

        return decimalsVal;
    }

    function latestRoundData()
        external
        override
        view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) 
    {    
        if (latestRevert) { require(1== 0, "latestRoundData reverted");}

        return (latestRoundId, price, 0, updateTime, 0); 
    }

    function getRoundData(uint80)
    external
    override 
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
        if (prevRevert) {require( 1== 0, "getRoundData reverted");}

        return (prevRoundId, prevPrice, 0, updateTime, 0);
    }

    function description() external override view returns (string memory) {
        return "";
    }
    function version() external override view returns (uint256) {
        return 1;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../PriceFeed.sol";

contract PriceFeedTester is PriceFeed {

    function setLastGoodPrice(address _collateral, uint _lastGoodPrice) external {
        lastGoodPrice[_collateral] = _lastGoodPrice;
    }

    function setStatus(address _collateral, Status _status) external {
        status[_collateral] = _status;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Interfaces/IPriceFeed.sol";

/*
* PriceFeed placeholder for testnet and development. The price is simply set manually and saved in a state 
* variable. The contract does not connect to a live Chainlink price feed. 
*/
contract PriceFeedTestnet is IPriceFeed {
    
    mapping (address => uint256) private _price;

    // --- Functions ---

    // View price getter for simplicity in tests
    function getPrice(address _collateral) external view returns (uint256) {
        return _price[_collateral];
    }

    function fetchPrice(address _collateral) external override returns (uint256) {
        // Fire an event just like the mainnet version would.
        // This lets the subgraph rely on events to get the latest price even when developing locally.
        emit LastGoodPriceUpdated(_collateral, _price[_collateral]);
        return _price[_collateral];
    }

    // Manual external price setter.
    function setPrice(address _collateral, uint256 price) external returns (bool) {
        _price[_collateral] = price;
        return true;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../Interfaces/ISortedTroves.sol";


contract SortedTrovesTester {
    ISortedTroves sortedTroves;

    function setSortedTroves(address _sortedTrovesAddress) external {
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
    }

    function insert(address _collateral, address _id, uint256 _NICR, address _prevId, address _nextId) external {
        sortedTroves.insert(_collateral, _id, _NICR, _prevId, _nextId);
    }

    function remove(address _collateral, address _id) external {
        sortedTroves.remove(_collateral, _id);
    }

    function reInsert(address _id, address _collateral, uint256 _newNICR, address _prevId, address _nextId) external {
        sortedTroves.reInsert(_id, _collateral, _newNICR, _prevId, _nextId);
    }

    function getNominalICR(address, address) external pure returns (uint) {
        return 1;
    }

    function getCurrentICR(address, address, uint) external pure returns (uint) {
        return 1;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "../StabilityPool.sol";

contract StabilityPoolTester is StabilityPool {
    
    function unprotectedPullCollateral(address _collateral, uint _amount) external {
        collAmounts[_collateral] = collAmounts[_collateral].add(_amount);
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function setCurrentScale(uint128 _currentScale) external {
        currentScale = _currentScale;
    }

    function setTotalDeposits(uint _totalLUSDDeposits) external {
        totalLUSDDeposits = _totalLUSDDeposits;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.6.11;

import "./Interfaces/ICollateralConfig.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IStabilityPool.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Interfaces/ILQTYStaking.sol";
import "./Interfaces/IRedemptionHelper.sol";
import "./Dependencies/LiquityBase.sol";
// import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/IERC20.sol";

contract TroveManager is LiquityBase, /*Ownable,*/ CheckContract, ITroveManager {
    // string constant public NAME = "TroveManager";

    address public owner;

    // --- Connected contract declarations ---

    address public borrowerOperationsAddress;

    ICollateralConfig public collateralConfig;

    IStabilityPool public override stabilityPool;

    address gasPoolAddress;

    ICollSurplusPool collSurplusPool;

    ILUSDToken public override lusdToken;

    IERC20 public override lqtyToken;

    ILQTYStaking public override lqtyStaking;

    // A doubly linked list of Troves, sorted by their sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    IRedemptionHelper public override redemptionHelper;

    // --- Data structures ---

    uint constant public SECONDS_IN_ONE_MINUTE = 60;
    /*
     * Half-life of 12h. 12h = 720 min
     * (1/2) = d^720 => d = (1/2)^(1/720)
     */
    uint constant public MINUTE_DECAY_FACTOR = 999037758833783000;
    uint constant public override REDEMPTION_FEE_FLOOR = DECIMAL_PRECISION / 1000 * 5; // 0.5%
    uint constant public MAX_BORROWING_FEE = DECIMAL_PRECISION / 100 * 5; // 5%

    /*
    * BETA: 18 digit decimal. Parameter by which to divide the redeemed fraction, in order to calc the new base rate from a redemption.
    * Corresponds to (1 / ALPHA) in the white paper.
    */
    uint constant public BETA = 2;

    uint public baseRate;

    // The timestamp of the latest fee operation (redemption or new LUSD issuance)
    uint public lastFeeOperationTime;

    enum Status {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        closedByRedemption
    }

    // Store the necessary data for a trove
    struct Trove {
        uint debt;
        uint coll;
        uint stake;
        Status status;
        uint128 arrayIndex;
    }

    // user => (collateral type => trove)
    mapping (address => mapping (address => Trove)) public Troves;

    mapping (address => uint) public totalStakes;

    // Snapshot of the value of totalStakes for each collateral, taken immediately after the latest liquidation
    mapping (address => uint) public totalStakesSnapshot;

    // Snapshot of the total collateral across the ActivePool and DefaultPool, immediately after the latest liquidation.
    mapping (address => uint) public totalCollateralSnapshot;

    /*
    * L_Collateral and L_LUSDDebt track the sums of accumulated liquidation rewards per unit staked. During its lifetime, each stake earns:
    *
    * A collateral gain of ( stake * [L_Collateral - L_Collateral(0)] )
    * A LUSDDebt increase  of ( stake * [L_LUSDDebt - L_LUSDDebt(0)] )
    *
    * Where L_Collateral(0) and L_LUSDDebt(0) are snapshots of L_Collateral and L_LUSDDebt for the active Trove taken at the instant the stake was made
    */
    mapping (address => uint) public L_Collateral;
    mapping (address => uint) public L_LUSDDebt;

    // Map addresses with active troves to their RewardSnapshot
    // user => (collateral type => reward snapshot))
    mapping (address => mapping (address => RewardSnapshot)) public rewardSnapshots;

    // Object containing the Collateral and LUSD snapshots for a given active trove
    struct RewardSnapshot { uint collAmount; uint LUSDDebt;}

    // Array of all active trove addresses - used to to compute an approximate hint off-chain, for the sorted list insertion
    // collateral type => array of trove owners
    mapping (address => address[]) public TroveOwners;

    // Error trackers for the trove redistribution calculation
    mapping (address => uint) public lastCollateralError_Redistribution;
    mapping (address => uint) public lastLUSDDebtError_Redistribution;

    /*
    * --- Variable container structs for liquidations ---
    *
    * These structs are used to hold, return and assign variables inside the liquidation functions,
    * in order to avoid the error: "CompilerError: Stack too deep".
    **/

    struct LocalVariables_OuterLiquidationFunction {
        uint256 collDecimals;
        uint256 collCCR;
        uint256 collMCR;
        uint price;
        uint LUSDInStabPool;
        bool recoveryModeAtStart;
        uint liquidatedDebt;
        uint liquidatedColl;
    }

    struct LocalVariables_InnerSingleLiquidateFunction {
        uint collToLiquidate;
        uint pendingDebtReward;
        uint pendingCollReward;
    }

    struct LocalVariables_LiquidationSequence {
        uint remainingLUSDInStabPool;
        uint i;
        uint ICR;
        uint TCR;
        address user;
        bool backToNormalMode;
        uint entireSystemDebt;
        uint entireSystemColl;
        uint256 collDecimals;
        uint256 collCCR;
        uint256 collMCR;
    }

    struct LiquidationValues {
        uint entireTroveDebt;
        uint entireTroveColl;
        uint collGasCompensation;
        uint LUSDGasCompensation;
        uint debtToOffset;
        uint collToSendToSP;
        uint debtToRedistribute;
        uint collToRedistribute;
        uint collSurplus;
    }

    struct LiquidationTotals {
        uint totalCollInSequence;
        uint totalDebtInSequence;
        uint totalCollGasCompensation;
        uint totalLUSDGasCompensation;
        uint totalDebtToOffset;
        uint totalCollToSendToSP;
        uint totalDebtToRedistribute;
        uint totalCollToRedistribute;
        uint totalCollSurplus;
    }

    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event CollateralConfigAddressChanged(address _newCollateralConfigAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event LUSDTokenAddressChanged(address _newLUSDTokenAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event LQTYTokenAddressChanged(address _lqtyTokenAddress);
    event LQTYStakingAddressChanged(address _lqtyStakingAddress);
    event RedemptionHelperAddressChanged(address _redemptionHelperAddress);

    event Liquidation(address _collateral, uint _liquidatedDebt, uint _liquidatedColl, uint _collGasCompensation, uint _LUSDGasCompensation);
    event TroveUpdated(address indexed _borrower, address _collateral, uint _debt, uint _coll, uint _stake, TroveManagerOperation _operation);
    event TroveLiquidated(address indexed _borrower, address _collateral, uint _debt, uint _coll, TroveManagerOperation _operation);
    event BaseRateUpdated(uint _baseRate);
    event LastFeeOpTimeUpdated(uint _lastFeeOpTime);
    event TotalStakesUpdated(address _collateral, uint _newTotalStakes);
    event SystemSnapshotsUpdated(address _collateral, uint _totalStakesSnapshot, uint _totalCollateralSnapshot);
    event LTermsUpdated(address _collateral, uint _L_Collateral, uint _L_LUSDDebt);
    event TroveSnapshotsUpdated(address _collateral, uint _L_Collateral, uint _L_LUSDDebt);
    event TroveIndexUpdated(address _borrower, address _collateral, uint _newIndex);
    event Redemption(
        address _collateral,
        uint _attemptedLUSDAmount,
        uint _actualLUSDAmount,
        uint _collSent,
        uint _collFee
    );

     enum TroveManagerOperation {
        applyPendingRewards,
        liquidateInNormalMode,
        liquidateInRecoveryMode,
        redeemCollateral
    }

    constructor() public {
        // makeshift ownable implementation to circumvent contract size limit
        owner = msg.sender;
    }

    // --- Dependency setter ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _collateralConfigAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _lusdTokenAddress,
        address _sortedTrovesAddress,
        address _lqtyTokenAddress,
        address _lqtyStakingAddress,
        address _redemptionHelperAddress
    )
        external
        override
    {
        require(msg.sender == owner);

        checkContract(_borrowerOperationsAddress);
        checkContract(_collateralConfigAddress);
        checkContract(_activePoolAddress);
        checkContract(_defaultPoolAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_gasPoolAddress);
        checkContract(_collSurplusPoolAddress);
        checkContract(_priceFeedAddress);
        checkContract(_lusdTokenAddress);
        checkContract(_sortedTrovesAddress);
        checkContract(_lqtyTokenAddress);
        checkContract(_lqtyStakingAddress);
        checkContract(_redemptionHelperAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        collateralConfig = ICollateralConfig(_collateralConfigAddress);
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        stabilityPool = IStabilityPool(_stabilityPoolAddress);
        gasPoolAddress = _gasPoolAddress;
        collSurplusPool = ICollSurplusPool(_collSurplusPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        lusdToken = ILUSDToken(_lusdTokenAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        lqtyToken = IERC20(_lqtyTokenAddress);
        lqtyStaking = ILQTYStaking(_lqtyStakingAddress);
        redemptionHelper = IRedemptionHelper(_redemptionHelperAddress);

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit CollateralConfigAddressChanged(_collateralConfigAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit CollSurplusPoolAddressChanged(_collSurplusPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit LUSDTokenAddressChanged(_lusdTokenAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit LQTYTokenAddressChanged(_lqtyTokenAddress);
        emit LQTYStakingAddressChanged(_lqtyStakingAddress);
        emit RedemptionHelperAddressChanged(_redemptionHelperAddress);

        owner = address(0);
    }

    // --- Getters ---

    function getTroveOwnersCount(address _collateral) external view override returns (uint) {
        return TroveOwners[_collateral].length;
    }

    function getTroveFromTroveOwnersArray(address _collateral, uint _index) external view override returns (address) {
        return TroveOwners[_collateral][_index];
    }

    // --- Trove Liquidation functions ---

    // Single liquidation function. Closes the trove if its ICR is lower than the minimum collateral ratio.
    function liquidate(address _borrower, address _collateral) external override {
        _requireTroveIsActive(_borrower, _collateral);

        address[] memory borrowers = new address[](1);
        borrowers[0] = _borrower;
        batchLiquidateTroves(_collateral, borrowers);
    }

    // --- Inner single liquidation functions ---

    // Liquidate one trove, in Normal Mode.
    function _liquidateNormalMode(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _collateral,
        address _borrower,
        uint _LUSDInStabPool
    )
        internal
        returns (LiquidationValues memory singleLiquidation)
    {
        LocalVariables_InnerSingleLiquidateFunction memory vars;

        (singleLiquidation.entireTroveDebt,
        singleLiquidation.entireTroveColl,
        vars.pendingDebtReward,
        vars.pendingCollReward) = getEntireDebtAndColl(_borrower, _collateral);

        _movePendingTroveRewardsToActivePool(_activePool, _defaultPool, _collateral, vars.pendingDebtReward, vars.pendingCollReward);
        _removeStake(_borrower, _collateral);

        singleLiquidation.collGasCompensation = _getCollGasCompensation(singleLiquidation.entireTroveColl);
        singleLiquidation.LUSDGasCompensation = LUSD_GAS_COMPENSATION;
        uint collToLiquidate = singleLiquidation.entireTroveColl.sub(singleLiquidation.collGasCompensation);

        (singleLiquidation.debtToOffset,
        singleLiquidation.collToSendToSP,
        singleLiquidation.debtToRedistribute,
        singleLiquidation.collToRedistribute) = _getOffsetAndRedistributionVals(singleLiquidation.entireTroveDebt, collToLiquidate, _LUSDInStabPool);

        _closeTrove(_borrower, _collateral, Status.closedByLiquidation);
        emit TroveLiquidated(_borrower, _collateral, singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl, TroveManagerOperation.liquidateInNormalMode);
        emit TroveUpdated(_borrower, _collateral, 0, 0, 0, TroveManagerOperation.liquidateInNormalMode);
        return singleLiquidation;
    }

    // Liquidate one trove, in Recovery Mode.
    function _liquidateRecoveryMode(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _collateral,
        address _borrower,
        uint _ICR,
        uint _LUSDInStabPool,
        uint _TCR,
        uint _price,
        uint256 _MCR
    )
        internal
        returns (LiquidationValues memory singleLiquidation)
    {
        LocalVariables_InnerSingleLiquidateFunction memory vars;
        if (TroveOwners[_collateral].length <= 1) {return singleLiquidation;} // don't liquidate if last trove
        (singleLiquidation.entireTroveDebt,
        singleLiquidation.entireTroveColl,
        vars.pendingDebtReward,
        vars.pendingCollReward) = getEntireDebtAndColl(_borrower, _collateral);

        singleLiquidation.collGasCompensation = _getCollGasCompensation(singleLiquidation.entireTroveColl);
        singleLiquidation.LUSDGasCompensation = LUSD_GAS_COMPENSATION;
        vars.collToLiquidate = singleLiquidation.entireTroveColl.sub(singleLiquidation.collGasCompensation);

        // If ICR <= 100%, purely redistribute the Trove across all active Troves
        if (_ICR <= _100pct) {
            _movePendingTroveRewardsToActivePool(_activePool, _defaultPool, _collateral, vars.pendingDebtReward, vars.pendingCollReward);
            _removeStake(_borrower, _collateral);
           
            singleLiquidation.debtToOffset = 0;
            singleLiquidation.collToSendToSP = 0;
            singleLiquidation.debtToRedistribute = singleLiquidation.entireTroveDebt;
            singleLiquidation.collToRedistribute = vars.collToLiquidate;

            _closeTrove(_borrower, _collateral, Status.closedByLiquidation);
            emit TroveLiquidated(_borrower, _collateral, singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl, TroveManagerOperation.liquidateInRecoveryMode);
            emit TroveUpdated(_borrower, _collateral, 0, 0, 0, TroveManagerOperation.liquidateInRecoveryMode);
            
        // If 100% < ICR < MCR, offset as much as possible, and redistribute the remainder
        } else if ((_ICR > _100pct) && (_ICR < _MCR)) {
             _movePendingTroveRewardsToActivePool(_activePool, _defaultPool, _collateral, vars.pendingDebtReward, vars.pendingCollReward);
            _removeStake(_borrower, _collateral);

            (singleLiquidation.debtToOffset,
            singleLiquidation.collToSendToSP,
            singleLiquidation.debtToRedistribute,
            singleLiquidation.collToRedistribute) = _getOffsetAndRedistributionVals(singleLiquidation.entireTroveDebt, vars.collToLiquidate, _LUSDInStabPool);

            _closeTrove(_borrower, _collateral, Status.closedByLiquidation);
            emit TroveLiquidated(_borrower, _collateral, singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl, TroveManagerOperation.liquidateInRecoveryMode);
            emit TroveUpdated(_borrower, _collateral, 0, 0, 0, TroveManagerOperation.liquidateInRecoveryMode);
        /*
        * If MCR <= ICR < current TCR (accounting for the preceding liquidations in the current sequence)
        * and there is LUSD in the Stability Pool, only offset, with no redistribution,
        * but at a capped rate of MCR and only if the whole debt can be liquidated.
        * The remainder due to the capped rate will be claimable as collateral surplus.
        */
        } else if ((_ICR >= _MCR) && (_ICR < _TCR) && (singleLiquidation.entireTroveDebt <= _LUSDInStabPool)) {
            _movePendingTroveRewardsToActivePool(_activePool, _defaultPool, _collateral, vars.pendingDebtReward, vars.pendingCollReward);
            assert(_LUSDInStabPool != 0);

            _removeStake(_borrower, _collateral);
            uint collDecimals = collateralConfig.getCollateralDecimals(_collateral);
            singleLiquidation = _getCappedOffsetVals(singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl, _price, _MCR, collDecimals);

            _closeTrove(_borrower, _collateral, Status.closedByLiquidation);
            if (singleLiquidation.collSurplus > 0) {
                collSurplusPool.accountSurplus(_borrower, _collateral, singleLiquidation.collSurplus);
            }

            emit TroveLiquidated(_borrower, _collateral, singleLiquidation.entireTroveDebt, singleLiquidation.collToSendToSP, TroveManagerOperation.liquidateInRecoveryMode);
            emit TroveUpdated(_borrower, _collateral, 0, 0, 0, TroveManagerOperation.liquidateInRecoveryMode);

        } else { // if (_ICR >= _MCR && ( _ICR >= _TCR || singleLiquidation.entireTroveDebt > _LUSDInStabPool))
            LiquidationValues memory zeroVals;
            return zeroVals;
        }

        return singleLiquidation;
    }

    /* In a full liquidation, returns the values for a trove's coll and debt to be offset, and coll and debt to be
    * redistributed to active troves.
    */
    function _getOffsetAndRedistributionVals
    (
        uint _debt,
        uint _coll,
        uint _LUSDInStabPool
    )
        internal
        pure
        returns (uint debtToOffset, uint collToSendToSP, uint debtToRedistribute, uint collToRedistribute)
    {
        if (_LUSDInStabPool > 0) {
        /*
        * Offset as much debt & collateral as possible against the Stability Pool, and redistribute the remainder
        * between all active troves.
        *
        *  If the trove's debt is larger than the deposited LUSD in the Stability Pool:
        *
        *  - Offset an amount of the trove's debt equal to the LUSD in the Stability Pool
        *  - Send a fraction of the trove's collateral to the Stability Pool, equal to the fraction of its offset debt
        *
        */
            debtToOffset = LiquityMath._min(_debt, _LUSDInStabPool);
            collToSendToSP = _coll.mul(debtToOffset).div(_debt);
            debtToRedistribute = _debt.sub(debtToOffset);
            collToRedistribute = _coll.sub(collToSendToSP);
        } else {
            debtToOffset = 0;
            collToSendToSP = 0;
            debtToRedistribute = _debt;
            collToRedistribute = _coll;
        }
    }

    /*
    *  Get its offset coll/debt and ETH gas comp, and close the trove.
    */
    function _getCappedOffsetVals
    (
        uint _entireTroveDebt,
        uint _entireTroveColl,
        uint _price,
        uint256 _MCR,
        uint _collDecimals
    )
        internal
        pure
        returns (LiquidationValues memory singleLiquidation)
    {
        singleLiquidation.entireTroveDebt = _entireTroveDebt;
        singleLiquidation.entireTroveColl = _entireTroveColl;
        uint cappedCollPortion = _entireTroveDebt.mul(_MCR).div(_price);
        if (_collDecimals < LiquityMath.CR_CALCULATION_DECIMALS) {
            cappedCollPortion = cappedCollPortion.div(10 ** (LiquityMath.CR_CALCULATION_DECIMALS - _collDecimals));
        } else if (_collDecimals > LiquityMath.CR_CALCULATION_DECIMALS) {
            cappedCollPortion = cappedCollPortion.mul(10 ** (_collDecimals - LiquityMath.CR_CALCULATION_DECIMALS));
        }

        singleLiquidation.collGasCompensation = _getCollGasCompensation(cappedCollPortion);
        singleLiquidation.LUSDGasCompensation = LUSD_GAS_COMPENSATION;

        singleLiquidation.debtToOffset = _entireTroveDebt;
        singleLiquidation.collToSendToSP = cappedCollPortion.sub(singleLiquidation.collGasCompensation);
        singleLiquidation.collSurplus = _entireTroveColl.sub(cappedCollPortion);
        singleLiquidation.debtToRedistribute = 0;
        singleLiquidation.collToRedistribute = 0;
    }

    /*
    * Liquidate a sequence of troves. Closes a maximum number of n under-collateralized Troves,
    * starting from the one with the lowest collateral ratio in the system, and moving upwards
    */
    function liquidateTroves(address _collateral, uint _n) external override {
        IActivePool activePoolCached = activePool;
        IDefaultPool defaultPoolCached = defaultPool;
        IStabilityPool stabilityPoolCached = stabilityPool;

        LocalVariables_OuterLiquidationFunction memory vars;
        LiquidationTotals memory totals;

        vars.collCCR = collateralConfig.getCollateralCCR(_collateral);
        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        vars.price = priceFeed.fetchPrice(_collateral);
        vars.LUSDInStabPool = stabilityPoolCached.getTotalLUSDDeposits();
        vars.recoveryModeAtStart = _checkRecoveryMode(_collateral, vars.price, vars.collCCR, vars.collDecimals);

        // Perform the appropriate liquidation sequence - tally the values, and obtain their totals
        if (vars.recoveryModeAtStart) {
            totals = _getTotalsFromLiquidateTrovesSequence_RecoveryMode(
                activePoolCached,
                defaultPoolCached,
                sortedTroves,
                _collateral,
                vars.price,
                vars.LUSDInStabPool,
                _n
            );
        } else { // if !vars.recoveryModeAtStart
            totals = _getTotalsFromLiquidateTrovesSequence_NormalMode(
                activePoolCached,
                defaultPoolCached,
                _collateral,
                vars.price,
                vars.collMCR,
                vars.LUSDInStabPool,
                _n
            );
        }

        require(totals.totalDebtInSequence > 0);

        // Move liquidated collateral and LUSD to the appropriate pools
        stabilityPoolCached.offset(_collateral, totals.totalDebtToOffset, totals.totalCollToSendToSP);
        _redistributeDebtAndColl(
            activePoolCached,
            defaultPoolCached,
            _collateral,
            totals.totalDebtToRedistribute,
            totals.totalCollToRedistribute,
            vars.collDecimals
        );
        if (totals.totalCollSurplus > 0) {
            activePoolCached.sendCollateral(_collateral, address(collSurplusPool), totals.totalCollSurplus);
        }

        // Update system snapshots
        _updateSystemSnapshots_excludeCollRemainder(activePoolCached, _collateral, totals.totalCollGasCompensation);

        vars.liquidatedDebt = totals.totalDebtInSequence;
        vars.liquidatedColl = totals.totalCollInSequence.sub(totals.totalCollGasCompensation).sub(totals.totalCollSurplus);
        emit Liquidation(_collateral, vars.liquidatedDebt, vars.liquidatedColl, totals.totalCollGasCompensation, totals.totalLUSDGasCompensation);

        // Send gas compensation to caller
        _sendGasCompensation(activePoolCached, _collateral, msg.sender, totals.totalLUSDGasCompensation, totals.totalCollGasCompensation);
    }

    /*
    * This function is used when the liquidateTroves sequence starts during Recovery Mode. However, it
    * handle the case where the system *leaves* Recovery Mode, part way through the liquidation sequence
    */
    function _getTotalsFromLiquidateTrovesSequence_RecoveryMode
    (
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        ISortedTroves _sortedTroves,
        address _collateral,
        uint _price,
        uint _LUSDInStabPool,
        uint _n
    )
        internal
        returns(LiquidationTotals memory totals)
    {
        LocalVariables_LiquidationSequence memory vars;
        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.collCCR = collateralConfig.getCollateralCCR(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        LiquidationValues memory singleLiquidation;

        vars.remainingLUSDInStabPool = _LUSDInStabPool;
        vars.backToNormalMode = false;
        vars.entireSystemDebt = getEntireSystemDebt(_collateral);
        vars.entireSystemColl = getEntireSystemColl(_collateral);

        vars.user = _sortedTroves.getLast(_collateral);
        address firstUser = _sortedTroves.getFirst(_collateral);
        for (vars.i = 0; vars.i < _n && vars.user != firstUser; vars.i++) {
            // we need to cache it, because current user is likely going to be deleted
            address nextUser = _sortedTroves.getPrev(_collateral, vars.user);

            vars.ICR = getCurrentICR(vars.user, _collateral, _price);

            if (!vars.backToNormalMode) {
                // Break the loop if ICR is greater than MCR and Stability Pool is empty
                if (vars.ICR >= vars.collMCR && vars.remainingLUSDInStabPool == 0) { break; }

                vars.TCR = LiquityMath._computeCR(vars.entireSystemColl, vars.entireSystemDebt, _price, vars.collDecimals);

                singleLiquidation = _liquidateRecoveryMode(
                    _activePool,
                    _defaultPool,
                    _collateral,
                    vars.user,
                    vars.ICR,
                    vars.remainingLUSDInStabPool,
                    vars.TCR,
                    _price,
                    vars.collMCR
                );

                // Update aggregate trackers
                vars.remainingLUSDInStabPool = vars.remainingLUSDInStabPool.sub(singleLiquidation.debtToOffset);
                vars.entireSystemDebt = vars.entireSystemDebt.sub(singleLiquidation.debtToOffset);
                vars.entireSystemColl = vars.entireSystemColl.
                    sub(singleLiquidation.collToSendToSP).
                    sub(singleLiquidation.collGasCompensation).
                    sub(singleLiquidation.collSurplus);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);

                vars.backToNormalMode = !_checkPotentialRecoveryMode(
                    vars.entireSystemColl,
                    vars.entireSystemDebt,
                    _price,
                    vars.collDecimals,
                    vars.collCCR
                );
            }
            else if (vars.backToNormalMode && vars.ICR < vars.collMCR) {
                singleLiquidation = _liquidateNormalMode(
                    _activePool,
                    _defaultPool,
                    _collateral,
                    vars.user,
                    vars.remainingLUSDInStabPool
                );

                vars.remainingLUSDInStabPool = vars.remainingLUSDInStabPool.sub(singleLiquidation.debtToOffset);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);

            }  else break;  // break if the loop reaches a Trove with ICR >= MCR

            vars.user = nextUser;
        }
    }

    function _getTotalsFromLiquidateTrovesSequence_NormalMode
    (
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _collateral,
        uint _price,
        uint256 _MCR,
        uint _LUSDInStabPool,
        uint _n
    )
        internal
        returns(LiquidationTotals memory totals)
    {
        LocalVariables_LiquidationSequence memory vars;
        LiquidationValues memory singleLiquidation;
        ISortedTroves sortedTrovesCached = sortedTroves;

        vars.remainingLUSDInStabPool = _LUSDInStabPool;

        for (vars.i = 0; vars.i < _n; vars.i++) {
            vars.user = sortedTrovesCached.getLast(_collateral);
            vars.ICR = getCurrentICR(vars.user, _collateral, _price);

            if (vars.ICR < _MCR) {
                singleLiquidation = _liquidateNormalMode(
                    _activePool,
                    _defaultPool,
                    _collateral,
                    vars.user,
                    vars.remainingLUSDInStabPool
                );

                vars.remainingLUSDInStabPool = vars.remainingLUSDInStabPool.sub(singleLiquidation.debtToOffset);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);

            } else break;  // break if the loop reaches a Trove with ICR >= MCR
        }
    }

    /*
    * Attempt to liquidate a custom list of troves (for the specified collateral) provided by the caller.
    */
    function batchLiquidateTroves(address _collateral, address[] memory _troveArray) public override {
        require(_troveArray.length != 0);

        IActivePool activePoolCached = activePool;
        IDefaultPool defaultPoolCached = defaultPool;
        IStabilityPool stabilityPoolCached = stabilityPool;

        LocalVariables_OuterLiquidationFunction memory vars;
        LiquidationTotals memory totals;

        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.collCCR = collateralConfig.getCollateralCCR(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        vars.price = priceFeed.fetchPrice(_collateral);
        vars.LUSDInStabPool = stabilityPoolCached.getTotalLUSDDeposits();
        vars.recoveryModeAtStart = _checkRecoveryMode(_collateral, vars.price, vars.collCCR, vars.collDecimals);

        // Perform the appropriate liquidation sequence - tally values and obtain their totals.
        if (vars.recoveryModeAtStart) {
            totals = _getTotalFromBatchLiquidate_RecoveryMode(
                activePoolCached,
                defaultPoolCached,
                _collateral,
                vars.price,
                vars.LUSDInStabPool,
                _troveArray
            );
        } else {  //  if !vars.recoveryModeAtStart
            totals = _getTotalsFromBatchLiquidate_NormalMode(
                activePoolCached,
                defaultPoolCached,
                _collateral,
                vars.price,
                vars.collMCR,
                vars.LUSDInStabPool,
                _troveArray
            );
        }

        require(totals.totalDebtInSequence > 0);

        // Move liquidated collateral and LUSD to the appropriate pools
        stabilityPoolCached.offset(_collateral, totals.totalDebtToOffset, totals.totalCollToSendToSP);
        _redistributeDebtAndColl(
            activePoolCached,
            defaultPoolCached,
            _collateral,
            totals.totalDebtToRedistribute,
            totals.totalCollToRedistribute,
            vars.collDecimals
        );
        if (totals.totalCollSurplus > 0) {
            activePoolCached.sendCollateral(_collateral, address(collSurplusPool), totals.totalCollSurplus);
        }

        // Update system snapshots
        _updateSystemSnapshots_excludeCollRemainder(activePoolCached, _collateral, totals.totalCollGasCompensation);

        vars.liquidatedDebt = totals.totalDebtInSequence;
        vars.liquidatedColl = totals.totalCollInSequence.sub(totals.totalCollGasCompensation).sub(totals.totalCollSurplus);
        emit Liquidation(_collateral, vars.liquidatedDebt, vars.liquidatedColl, totals.totalCollGasCompensation, totals.totalLUSDGasCompensation);

        // Send gas compensation to caller
        _sendGasCompensation(activePoolCached, _collateral, msg.sender, totals.totalLUSDGasCompensation, totals.totalCollGasCompensation);
    }

    /*
    * This function is used when the batch liquidation sequence starts during Recovery Mode. However, it
    * handle the case where the system *leaves* Recovery Mode, part way through the liquidation sequence
    */
    function _getTotalFromBatchLiquidate_RecoveryMode
    (
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _collateral,
        uint _price,
        uint _LUSDInStabPool,
        address[] memory _troveArray
    )
        internal
        returns(LiquidationTotals memory totals)
    {
        LocalVariables_LiquidationSequence memory vars;
        vars.collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        vars.collCCR = collateralConfig.getCollateralCCR(_collateral);
        vars.collMCR = collateralConfig.getCollateralMCR(_collateral);
        LiquidationValues memory singleLiquidation;

        vars.remainingLUSDInStabPool = _LUSDInStabPool;
        vars.backToNormalMode = false;
        vars.entireSystemDebt = getEntireSystemDebt(_collateral);
        vars.entireSystemColl = getEntireSystemColl(_collateral);

        for (vars.i = 0; vars.i < _troveArray.length; vars.i++) {
            vars.user = _troveArray[vars.i];
            // Skip non-active troves
            if (Troves[vars.user][_collateral].status != Status.active) { continue; }
            vars.ICR = getCurrentICR(vars.user, _collateral, _price);

            if (!vars.backToNormalMode) {

                // Skip this trove if ICR is greater than MCR and Stability Pool is empty
                if (vars.ICR >= vars.collMCR && vars.remainingLUSDInStabPool == 0) { continue; }

                uint TCR = LiquityMath._computeCR(vars.entireSystemColl, vars.entireSystemDebt, _price, vars.collDecimals);

                singleLiquidation = _liquidateRecoveryMode(
                    _activePool,
                    _defaultPool,
                    _collateral,
                    vars.user,
                    vars.ICR,
                    vars.remainingLUSDInStabPool,
                    TCR,
                    _price,
                    vars.collMCR
                );

                // Update aggregate trackers
                vars.remainingLUSDInStabPool = vars.remainingLUSDInStabPool.sub(singleLiquidation.debtToOffset);
                vars.entireSystemDebt = vars.entireSystemDebt.sub(singleLiquidation.debtToOffset);
                vars.entireSystemColl = vars.entireSystemColl.
                    sub(singleLiquidation.collToSendToSP).
                    sub(singleLiquidation.collGasCompensation).
                    sub(singleLiquidation.collSurplus);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);

                vars.backToNormalMode = !_checkPotentialRecoveryMode(
                    vars.entireSystemColl,
                    vars.entireSystemDebt,
                    _price,
                    vars.collDecimals,
                    vars.collCCR
                );
            }

            else if (vars.backToNormalMode && vars.ICR < vars.collMCR) {
                singleLiquidation = _liquidateNormalMode(_activePool, _defaultPool, _collateral, vars.user, vars.remainingLUSDInStabPool);
                vars.remainingLUSDInStabPool = vars.remainingLUSDInStabPool.sub(singleLiquidation.debtToOffset);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);

            } else continue; // In Normal Mode skip troves with ICR >= MCR
        }
    }

    function _getTotalsFromBatchLiquidate_NormalMode
    (
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _collateral,
        uint _price,
        uint256 _MCR,
        uint _LUSDInStabPool,
        address[] memory _troveArray
    )
        internal
        returns(LiquidationTotals memory totals)
    {
        LocalVariables_LiquidationSequence memory vars;
        LiquidationValues memory singleLiquidation;

        vars.remainingLUSDInStabPool = _LUSDInStabPool;

        for (vars.i = 0; vars.i < _troveArray.length; vars.i++) {
            vars.user = _troveArray[vars.i];
            vars.ICR = getCurrentICR(vars.user, _collateral, _price);

            if (vars.ICR < _MCR) {
                singleLiquidation = _liquidateNormalMode(_activePool, _defaultPool, _collateral, vars.user, vars.remainingLUSDInStabPool);
                vars.remainingLUSDInStabPool = vars.remainingLUSDInStabPool.sub(singleLiquidation.debtToOffset);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);
            }
        }
    }

    // --- Liquidation helper functions ---

    function _addLiquidationValuesToTotals(LiquidationTotals memory oldTotals, LiquidationValues memory singleLiquidation)
    internal pure returns(LiquidationTotals memory newTotals) {

        // Tally all the values with their respective running totals
        newTotals.totalCollGasCompensation = oldTotals.totalCollGasCompensation.add(singleLiquidation.collGasCompensation);
        newTotals.totalLUSDGasCompensation = oldTotals.totalLUSDGasCompensation.add(singleLiquidation.LUSDGasCompensation);
        newTotals.totalDebtInSequence = oldTotals.totalDebtInSequence.add(singleLiquidation.entireTroveDebt);
        newTotals.totalCollInSequence = oldTotals.totalCollInSequence.add(singleLiquidation.entireTroveColl);
        newTotals.totalDebtToOffset = oldTotals.totalDebtToOffset.add(singleLiquidation.debtToOffset);
        newTotals.totalCollToSendToSP = oldTotals.totalCollToSendToSP.add(singleLiquidation.collToSendToSP);
        newTotals.totalDebtToRedistribute = oldTotals.totalDebtToRedistribute.add(singleLiquidation.debtToRedistribute);
        newTotals.totalCollToRedistribute = oldTotals.totalCollToRedistribute.add(singleLiquidation.collToRedistribute);
        newTotals.totalCollSurplus = oldTotals.totalCollSurplus.add(singleLiquidation.collSurplus);

        return newTotals;
    }

    function _sendGasCompensation(IActivePool _activePool, address _collateral, address _liquidator, uint _LUSD, uint _collAmount) internal {
        if (_LUSD > 0) {
            lusdToken.returnFromPool(gasPoolAddress, _liquidator, _LUSD);
        }

        if (_collAmount > 0) {
            _activePool.sendCollateral(_collateral, _liquidator, _collAmount);
        }
    }

    // Move a Trove's pending debt and collateral rewards from distributions, from the Default Pool to the Active Pool
    function _movePendingTroveRewardsToActivePool(IActivePool _activePool, IDefaultPool _defaultPool, address _collateral, uint _LUSD, uint _collAmount) internal {
        _defaultPool.decreaseLUSDDebt(_collateral, _LUSD);
        _activePool.increaseLUSDDebt(_collateral, _LUSD);
        _defaultPool.sendCollateralToActivePool(_collateral, _collAmount);
    }

    /*
    * Called when a full redemption occurs, and closes the trove.
    * The redeemer swaps (debt - liquidation reserve) LUSD for (debt - liquidation reserve) worth of collateral, so the LUSD liquidation reserve left corresponds to the remaining debt.
    * In order to close the trove, the LUSD liquidation reserve is burned, and the corresponding debt is removed from the active pool.
    * The debt recorded on the trove's struct is zero'd elswhere, in _closeTrove.
    * Any surplus collateral left in the trove, is sent to the Coll surplus pool, and can be later claimed by the borrower.
    */
    function redeemCloseTrove(
        address _borrower,
        address _collateral,
        uint256 _LUSD,
        uint256 _collAmount
    ) external override {
        _requireCallerIsRedemptionHelper();
        lusdToken.burn(gasPoolAddress, _LUSD);
        // Update Active Pool LUSD, and send ETH to account
        activePool.decreaseLUSDDebt(_collateral, _LUSD);

        // send ETH from Active Pool to CollSurplus Pool
        collSurplusPool.accountSurplus(_borrower, _collateral, _collAmount);
        activePool.sendCollateral(_collateral, address(collSurplusPool), _collAmount);

        emit TroveUpdated(_borrower, _collateral, 0, 0, 0, TroveManagerOperation.redeemCollateral);
    }

    function reInsert(address _id, address _collateral, uint256 _newNICR, address _prevId, address _nextId) external override {
        _requireCallerIsRedemptionHelper();
        sortedTroves.reInsert(_id, _collateral, _newNICR, _prevId, _nextId);
    }

    function updateDebtAndCollAndStakesPostRedemption(
        address _borrower,
        address _collateral,
        uint256 _newDebt,
        uint256 _newColl
    ) external override {
        _requireCallerIsRedemptionHelper();
        Troves[_borrower][_collateral].debt = _newDebt;
        Troves[_borrower][_collateral].coll = _newColl;
        _updateStakeAndTotalStakes(_borrower, _collateral);

        emit TroveUpdated(
            _borrower,
            _collateral,
            _newDebt, _newColl,
            Troves[_borrower][_collateral].stake,
            TroveManagerOperation.redeemCollateral
        );
    }

    function burnLUSDAndEmitRedemptionEvent(
        address _redeemer,
        address _collateral,
        uint _attemptedLUSDAmount,
        uint _actualLUSDAmount,
        uint _collSent,
        uint _collFee
    ) external override {
        _requireCallerIsRedemptionHelper();
        lusdToken.burn(_redeemer, _actualLUSDAmount);
        emit Redemption(_collateral, _attemptedLUSDAmount, _actualLUSDAmount, _collSent, _collFee);
    }

    /* Send _LUSDamount LUSD to the system and redeem the corresponding amount of collateral from as many Troves as are needed to fill the redemption
    * request.  Applies pending rewards to a Trove before reducing its debt and coll.
    *
    * Note that if _amount is very large, this function can run out of gas, specially if traversed troves are small. This can be easily avoided by
    * splitting the total _amount in appropriate chunks and calling the function multiple times.
    *
    * Param `_maxIterations` can also be provided, so the loop through Troves is capped (if it’s zero, it will be ignored).This makes it easier to
    * avoid OOG for the frontend, as only knowing approximately the average cost of an iteration is enough, without needing to know the “topology”
    * of the trove list. It also avoids the need to set the cap in stone in the contract, nor doing gas calculations, as both gas price and opcode
    * costs can vary.
    *
    * All Troves that are redeemed from -- with the likely exception of the last one -- will end up with no debt left, therefore they will be closed.
    * If the last Trove does have some remaining debt, it has a finite ICR, and the reinsertion could be anywhere in the list, therefore it requires a hint.
    * A frontend should use getRedemptionHints() to calculate what the ICR of this Trove will be after redemption, and pass a hint for its position
    * in the sortedTroves list along with the ICR value that the hint was found for.
    *
    * If another transaction modifies the list between calling getRedemptionHints() and passing the hints to redeemCollateral(), it
    * is very likely that the last (partially) redeemed Trove would end up with a different ICR than what the hint is for. In this case the
    * redemption will stop after the last completely redeemed Trove and the sender will keep the remaining LUSD amount, which they can attempt
    * to redeem later.
    */
    function redeemCollateral(
        address _collateral,
        uint _LUSDamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFeePercentage
    )
        external
        override
    {
        redemptionHelper.redeemCollateral(
            _collateral,
            msg.sender,
            _LUSDamount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFeePercentage
        );
    }

    // --- Helper functions ---

    // Return the nominal collateral ratio (ICR) of a given Trove, without the price. Takes a trove's pending coll and debt rewards from redistributions into account.
    function getNominalICR(address _borrower, address _collateral) public view override returns (uint) {
        (uint currentCollateral, uint currentLUSDDebt) = _getCurrentTroveAmounts(_borrower, _collateral);

        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        uint NICR = LiquityMath._computeNominalCR(currentCollateral, currentLUSDDebt, collDecimals);
        return NICR;
    }

    // Return the current collateral ratio (ICR) of a given Trove. Takes a trove's pending coll and debt rewards from redistributions into account.
    function getCurrentICR(
        address _borrower,
        address _collateral,
        uint _price
    ) public view override returns (uint) {
        (uint currentCollateral, uint currentLUSDDebt) = _getCurrentTroveAmounts(_borrower, _collateral);

        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        uint ICR = LiquityMath._computeCR(currentCollateral, currentLUSDDebt, _price, collDecimals);
        return ICR;
    }

    function _getCurrentTroveAmounts(address _borrower, address _collateral) internal view returns (uint, uint) {
        uint pendingCollateralReward = getPendingCollateralReward(_borrower, _collateral);
        uint pendingLUSDDebtReward = getPendingLUSDDebtReward(_borrower, _collateral);

        uint currentCollateral = Troves[_borrower][_collateral].coll.add(pendingCollateralReward);
        uint currentLUSDDebt = Troves[_borrower][_collateral].debt.add(pendingLUSDDebtReward);

        return (currentCollateral, currentLUSDDebt);
    }

    function applyPendingRewards(address _borrower, address _collateral) external override {
        _requireCallerIsBorrowerOperationsOrRedemptionHelper();
        return _applyPendingRewards(activePool, defaultPool, _borrower, _collateral);
    }

    // Add the borrowers's coll and debt rewards earned from redistributions, to their Trove
    function _applyPendingRewards(IActivePool _activePool, IDefaultPool _defaultPool, address _borrower, address _collateral) internal {
        if (hasPendingRewards(_borrower, _collateral)) {
            _requireTroveIsActive(_borrower, _collateral);

            // Compute pending rewards
            uint pendingCollateralReward = getPendingCollateralReward(_borrower, _collateral);
            uint pendingLUSDDebtReward = getPendingLUSDDebtReward(_borrower, _collateral);

            // Apply pending rewards to trove's state
            Troves[_borrower][_collateral].coll = Troves[_borrower][_collateral].coll.add(pendingCollateralReward);
            Troves[_borrower][_collateral].debt = Troves[_borrower][_collateral].debt.add(pendingLUSDDebtReward);

            _updateTroveRewardSnapshots(_borrower, _collateral);

            // Transfer from DefaultPool to ActivePool
            _movePendingTroveRewardsToActivePool(_activePool, _defaultPool, _collateral, pendingLUSDDebtReward, pendingCollateralReward);

            emit TroveUpdated(
                _borrower,
                _collateral,
                Troves[_borrower][_collateral].debt,
                Troves[_borrower][_collateral].coll,
                Troves[_borrower][_collateral].stake,
                TroveManagerOperation.applyPendingRewards
            );
        }
    }

    // Update borrower's snapshots of L_Collateral and L_LUSDDebt to reflect the current values
    function updateTroveRewardSnapshots(address _borrower, address _collateral) external override {
        _requireCallerIsBorrowerOperations();
       return _updateTroveRewardSnapshots(_borrower, _collateral);
    }

    function _updateTroveRewardSnapshots(address _borrower, address _collateral) internal {
        rewardSnapshots[_borrower][_collateral].collAmount = L_Collateral[_collateral];
        rewardSnapshots[_borrower][_collateral].LUSDDebt = L_LUSDDebt[_collateral];
        emit TroveSnapshotsUpdated(_collateral, L_Collateral[_collateral], L_LUSDDebt[_collateral]);
    }

    // Get the borrower's pending accumulated collateral reward, earned by their stake
    function getPendingCollateralReward(address _borrower, address _collateral) public view override returns (uint) {
        uint snapshotCollateral = rewardSnapshots[_borrower][_collateral].collAmount;
        uint rewardPerUnitStaked = L_Collateral[_collateral].sub(snapshotCollateral);

        if ( rewardPerUnitStaked == 0 || Troves[_borrower][_collateral].status != Status.active) { return 0; }

        uint stake = Troves[_borrower][_collateral].stake;

        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        uint pendingCollateralReward = stake.mul(rewardPerUnitStaked).div(10**collDecimals);

        return pendingCollateralReward;
    }
    
    // Get the borrower's pending accumulated LUSD reward, earned by their stake
    function getPendingLUSDDebtReward(address _borrower, address _collateral) public view override returns (uint) {
        uint snapshotLUSDDebt = rewardSnapshots[_borrower][_collateral].LUSDDebt;
        uint rewardPerUnitStaked = L_LUSDDebt[_collateral].sub(snapshotLUSDDebt);

        if ( rewardPerUnitStaked == 0 || Troves[_borrower][_collateral].status != Status.active) { return 0; }

        uint stake = Troves[_borrower][_collateral].stake;

        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        uint pendingLUSDDebtReward = stake.mul(rewardPerUnitStaked).div(10**collDecimals);

        return pendingLUSDDebtReward;
    }

    function hasPendingRewards(address _borrower, address _collateral) public view override returns (bool) {
        /*
        * A Trove has pending rewards if its snapshot is less than the current rewards per-unit-staked sum:
        * this indicates that rewards have occured since the snapshot was made, and the user therefore has
        * pending rewards
        */
        if (Troves[_borrower][_collateral].status != Status.active) {return false;}
       
        return (rewardSnapshots[_borrower][_collateral].collAmount < L_Collateral[_collateral]);
    }

    // Return the Troves entire debt and coll, including pending rewards from redistributions.
    function getEntireDebtAndColl(
        address _borrower,
        address _collateral
    )
        public
        view
        override
        returns (uint debt, uint coll, uint pendingLUSDDebtReward, uint pendingCollateralReward)
    {
        debt = Troves[_borrower][_collateral].debt;
        coll = Troves[_borrower][_collateral].coll;

        pendingLUSDDebtReward = getPendingLUSDDebtReward(_borrower, _collateral);
        pendingCollateralReward = getPendingCollateralReward(_borrower, _collateral);

        debt = debt.add(pendingLUSDDebtReward);
        coll = coll.add(pendingCollateralReward);
    }

    function removeStake(address _borrower, address _collateral) external override {
        _requireCallerIsBorrowerOperationsOrRedemptionHelper();
        return _removeStake(_borrower, _collateral);
    }

    // Remove borrower's stake from the totalStakes sum, and set their stake to 0
    function _removeStake(address _borrower, address _collateral) internal {
        uint stake = Troves[_borrower][_collateral].stake;
        totalStakes[_collateral] = totalStakes[_collateral].sub(stake);
        Troves[_borrower][_collateral].stake = 0;
    }

    function updateStakeAndTotalStakes(address _borrower, address _collateral) external override returns (uint) {
        _requireCallerIsBorrowerOperations();
        return _updateStakeAndTotalStakes(_borrower, _collateral);
    }

    // Update borrower's stake based on their latest collateral value
    function _updateStakeAndTotalStakes(address _borrower, address _collateral) internal returns (uint) {
        uint newStake = _computeNewStake(_collateral, Troves[_borrower][_collateral].coll);
        uint oldStake = Troves[_borrower][_collateral].stake;
        Troves[_borrower][_collateral].stake = newStake;

        totalStakes[_collateral] = totalStakes[_collateral].sub(oldStake).add(newStake);
        emit TotalStakesUpdated(_collateral, totalStakes[_collateral]);

        return newStake;
    }

    // Calculate a new stake based on the snapshots of the totalStakes and totalCollateral taken at the last liquidation
    function _computeNewStake(address _collateral, uint _coll) internal view returns (uint) {
        uint stake;
        if (totalCollateralSnapshot[_collateral] == 0) {
            stake = _coll;
        } else {
            /*
            * The following assert() holds true because:
            * - The system always contains >= 1 trove
            * - When we close or liquidate a trove, we redistribute the pending rewards, so if all troves were closed/liquidated,
            * rewards would’ve been emptied and totalCollateralSnapshot would be zero too.
            */
            assert(totalStakesSnapshot[_collateral] > 0);
            stake = _coll.mul(totalStakesSnapshot[_collateral]).div(totalCollateralSnapshot[_collateral]);
        }
        return stake;
    }

    function _redistributeDebtAndColl(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _collateral,
        uint _debt,
        uint _coll,
        uint256 _collDecimals
    ) internal {
        if (_debt == 0) { return; }

        /*
        * Add distributed coll and debt rewards-per-unit-staked to the running totals. Division uses a "feedback"
        * error correction, to keep the cumulative error low in the running totals L_Collateral and L_LUSDDebt:
        *
        * 1) Form numerators which compensate for the floor division errors that occurred the last time this
        * function was called.
        * 2) Calculate "per-unit-staked" ratios.
        * 3) Multiply each ratio back by its denominator, to reveal the current floor division error.
        * 4) Store these errors for use in the next correction when this function is called.
        * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
        */
        uint collateralNumerator = _coll.mul(10**_collDecimals).add(lastCollateralError_Redistribution[_collateral]);
        uint LUSDDebtNumerator = _debt.mul(10**_collDecimals).add(lastLUSDDebtError_Redistribution[_collateral]);

        // Get the per-unit-staked terms
        uint collateralRewardPerUnitStaked = collateralNumerator.div(totalStakes[_collateral]);
        uint LUSDDebtRewardPerUnitStaked = LUSDDebtNumerator.div(totalStakes[_collateral]);

        lastCollateralError_Redistribution[_collateral] = collateralNumerator.sub(collateralRewardPerUnitStaked.mul(totalStakes[_collateral]));
        lastLUSDDebtError_Redistribution[_collateral] = LUSDDebtNumerator.sub(LUSDDebtRewardPerUnitStaked.mul(totalStakes[_collateral]));

        // Add per-unit-staked terms to the running totals
        L_Collateral[_collateral] = L_Collateral[_collateral].add(collateralRewardPerUnitStaked);
        L_LUSDDebt[_collateral] = L_LUSDDebt[_collateral].add(LUSDDebtRewardPerUnitStaked);

        emit LTermsUpdated(_collateral, L_Collateral[_collateral], L_LUSDDebt[_collateral]);

        // Transfer coll and debt from ActivePool to DefaultPool
        _activePool.decreaseLUSDDebt(_collateral, _debt);
        _defaultPool.increaseLUSDDebt(_collateral, _debt);
        _activePool.sendCollateral(_collateral, address(_defaultPool), _coll);
    }

    function closeTrove(address _borrower, address _collateral, uint256 _closedStatusNum) external override {
        _requireCallerIsBorrowerOperationsOrRedemptionHelper();
        return _closeTrove(_borrower, _collateral, Status(_closedStatusNum));
    }

    function _closeTrove(address _borrower, address _collateral, Status closedStatus) internal {
        assert(closedStatus != Status.nonExistent && closedStatus != Status.active);

        uint TroveOwnersArrayLength = TroveOwners[_collateral].length;
        _requireMoreThanOneTroveInSystem(TroveOwnersArrayLength, _collateral);

        Troves[_borrower][_collateral].status = closedStatus;
        Troves[_borrower][_collateral].coll = 0;
        Troves[_borrower][_collateral].debt = 0;

        rewardSnapshots[_borrower][_collateral].collAmount = 0;
        rewardSnapshots[_borrower][_collateral].LUSDDebt = 0;

        _removeTroveOwner(_borrower, _collateral, TroveOwnersArrayLength);
        sortedTroves.remove(_collateral, _borrower);
    }

    /*
    * Updates snapshots of system total stakes and total collateral, excluding a given collateral remainder from the calculation.
    * Used in a liquidation sequence.
    *
    * The calculation excludes a portion of collateral that is in the ActivePool:
    *
    * the total collateral gas compensation from the liquidation sequence
    *
    * The collateral as compensation must be excluded as it is always sent out at the very end of the liquidation sequence.
    */
    function _updateSystemSnapshots_excludeCollRemainder(IActivePool _activePool, address _collateral, uint _collRemainder) internal {
        totalStakesSnapshot[_collateral] = totalStakes[_collateral];

        uint activeColl = _activePool.getCollateral(_collateral);
        uint liquidatedColl = defaultPool.getCollateral(_collateral);
        totalCollateralSnapshot[_collateral] = activeColl.sub(_collRemainder).add(liquidatedColl);

        emit SystemSnapshotsUpdated(_collateral, totalStakesSnapshot[_collateral], totalCollateralSnapshot[_collateral]);
    }

    // Push the owner's address to the Trove owners list, and record the corresponding array index on the Trove struct
    function addTroveOwnerToArray(address _borrower, address _collateral) external override returns (uint index) {
        _requireCallerIsBorrowerOperations();
        return _addTroveOwnerToArray(_borrower, _collateral);
    }

    function _addTroveOwnerToArray(address _borrower, address _collateral) internal returns (uint128 index) {
        /* Max array size is 2**128 - 1, i.e. ~3e30 troves. No risk of overflow, since troves have minimum LUSD
        debt of liquidation reserve plus MIN_NET_DEBT. 3e30 LUSD dwarfs the value of all wealth in the world ( which is < 1e15 USD). */

        // Push the Troveowner to the array
        TroveOwners[_collateral].push(_borrower);

        // Record the index of the new Troveowner on their Trove struct
        index = uint128(TroveOwners[_collateral].length.sub(1));
        Troves[_borrower][_collateral].arrayIndex = index;

        return index;
    }

    /*
    * Remove a Trove owner from the TroveOwners array, not preserving array order. Removing owner 'B' does the following:
    * [A B C D E] => [A E C D], and updates E's Trove struct to point to its new array index.
    */
    function _removeTroveOwner(address _borrower, address _collateral, uint TroveOwnersArrayLength) internal {
        Status troveStatus = Troves[_borrower][_collateral].status;
        // It’s set in caller function `_closeTrove`
        assert(troveStatus != Status.nonExistent && troveStatus != Status.active);

        uint128 index = Troves[_borrower][_collateral].arrayIndex;
        uint length = TroveOwnersArrayLength;
        uint idxLast = length.sub(1);

        assert(index <= idxLast);

        address addressToMove = TroveOwners[_collateral][idxLast];

        TroveOwners[_collateral][index] = addressToMove;
        Troves[addressToMove][_collateral].arrayIndex = index;
        emit TroveIndexUpdated(addressToMove, _collateral, index);

        TroveOwners[_collateral].pop();
    }

    // --- Recovery Mode and TCR functions ---

    function getTCR(address _collateral, uint _price) external view override returns (uint) {
        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        return _getTCR(_collateral, _price, collDecimals);
    }

    function checkRecoveryMode(address _collateral, uint _price) external view override returns (bool) {
        uint256 collCCR = collateralConfig.getCollateralCCR(_collateral);
        uint256 collDecimals = collateralConfig.getCollateralDecimals(_collateral);
        return _checkRecoveryMode(_collateral, _price, collCCR, collDecimals);
    }

    // Check whether or not the system *would be* in Recovery Mode, given an ETH:USD price, and the entire system coll and debt.
    function _checkPotentialRecoveryMode(
        uint _entireSystemColl,
        uint _entireSystemDebt,
        uint _price,
        uint256 _collDecimals,
        uint256 _CCR
    )
        internal
        pure
    returns (bool)
    {
        uint TCR = LiquityMath._computeCR(_entireSystemColl, _entireSystemDebt, _price, _collDecimals);

        return TCR < _CCR;
    }

    // --- Redemption fee functions ---

    /*
    * This function has two impacts on the baseRate state variable:
    * 1) decays the baseRate based on time passed since last redemption or LUSD borrowing operation.
    * then,
    * 2) increases the baseRate based on the amount redeemed, as a proportion of total supply
    */
    function updateBaseRateFromRedemption(
        uint _collateralDrawn,
        uint _price,
        uint256 _collDecimals,
        uint _totalLUSDSupply
    ) external override returns (uint) {
        _requireCallerIsRedemptionHelper();
        uint decayedBaseRate = _calcDecayedBaseRate();

        /* Convert the drawn collateral back to LUSD at face value rate (1 LUSD:1 USD), in order to get
        * the fraction of total supply that was redeemed at face value. */
        uint redeemedLUSDFraction = 
            LiquityMath._getScaledCollAmount(_collateralDrawn, _collDecimals).mul(_price).div(_totalLUSDSupply);

        uint newBaseRate = decayedBaseRate.add(redeemedLUSDFraction.div(BETA));
        newBaseRate = LiquityMath._min(newBaseRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%
        //assert(newBaseRate <= DECIMAL_PRECISION); // This is already enforced in the line above
        assert(newBaseRate > 0); // Base rate is always non-zero after redemption

        // Update the baseRate state variable
        baseRate = newBaseRate;
        emit BaseRateUpdated(newBaseRate);
        
        _updateLastFeeOpTime();

        return newBaseRate;
    }

    function getRedemptionRate() public view override returns (uint) {
        return _calcRedemptionRate(baseRate);
    }

    function getRedemptionRateWithDecay() public view override returns (uint) {
        return _calcRedemptionRate(_calcDecayedBaseRate());
    }

    function _calcRedemptionRate(uint _baseRate) internal pure returns (uint) {
        return LiquityMath._min(
            REDEMPTION_FEE_FLOOR.add(_baseRate),
            DECIMAL_PRECISION // cap at a maximum of 100%
        );
    }

    function getRedemptionFee(uint _collateralDrawn) public view override returns (uint) {
        return _calcRedemptionFee(getRedemptionRate(), _collateralDrawn);
    }

    function getRedemptionFeeWithDecay(uint _collateralDrawn) external view override returns (uint) {
        return _calcRedemptionFee(getRedemptionRateWithDecay(), _collateralDrawn);
    }

    function _calcRedemptionFee(uint _redemptionRate, uint _collateralDrawn) internal pure returns (uint) {
        uint redemptionFee = _redemptionRate.mul(_collateralDrawn).div(DECIMAL_PRECISION);
        require(redemptionFee < _collateralDrawn);
        return redemptionFee;
    }

    // --- Borrowing fee functions ---

    function getBorrowingRate() public view override returns (uint) {
        return _calcBorrowingRate(baseRate);
    }

    function getBorrowingRateWithDecay() public view override returns (uint) {
        return _calcBorrowingRate(_calcDecayedBaseRate());
    }

    function _calcBorrowingRate(uint _baseRate) internal pure returns (uint) {
        return LiquityMath._min(
            BORROWING_FEE_FLOOR.add(_baseRate),
            MAX_BORROWING_FEE
        );
    }

    function getBorrowingFee(uint _LUSDDebt) external view override returns (uint) {
        return _calcBorrowingFee(getBorrowingRate(), _LUSDDebt);
    }

    function getBorrowingFeeWithDecay(uint _LUSDDebt) external view override returns (uint) {
        return _calcBorrowingFee(getBorrowingRateWithDecay(), _LUSDDebt);
    }

    function _calcBorrowingFee(uint _borrowingRate, uint _LUSDDebt) internal pure returns (uint) {
        return _borrowingRate.mul(_LUSDDebt).div(DECIMAL_PRECISION);
    }


    // Updates the baseRate state variable based on time elapsed since the last redemption or LUSD borrowing operation.
    function decayBaseRateFromBorrowing() external override {
        _requireCallerIsBorrowerOperations();

        uint decayedBaseRate = _calcDecayedBaseRate();
        assert(decayedBaseRate <= DECIMAL_PRECISION);  // The baseRate can decay to 0

        baseRate = decayedBaseRate;
        emit BaseRateUpdated(decayedBaseRate);

        _updateLastFeeOpTime();
    }

    // --- Internal fee functions ---

    // Update the last fee operation time only if time passed >= decay interval. This prevents base rate griefing.
    function _updateLastFeeOpTime() internal {
        uint timePassed = block.timestamp.sub(lastFeeOperationTime);

        if (timePassed >= SECONDS_IN_ONE_MINUTE) {
            lastFeeOperationTime = block.timestamp;
            emit LastFeeOpTimeUpdated(block.timestamp);
        }
    }

    function _calcDecayedBaseRate() internal view returns (uint) {
        uint minutesPassed = _minutesPassedSinceLastFeeOp();
        uint decayFactor = LiquityMath._decPow(MINUTE_DECAY_FACTOR, minutesPassed);

        return baseRate.mul(decayFactor).div(DECIMAL_PRECISION);
    }

    function _minutesPassedSinceLastFeeOp() internal view returns (uint) {
        return (block.timestamp.sub(lastFeeOperationTime)).div(SECONDS_IN_ONE_MINUTE);
    }

    // --- 'require' wrapper functions ---

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress);
    }

    function _requireCallerIsRedemptionHelper() internal view {
        require(msg.sender == address(redemptionHelper));
    }

    function _requireCallerIsBorrowerOperationsOrRedemptionHelper() internal view {
        require(msg.sender == borrowerOperationsAddress || msg.sender == address(redemptionHelper));
    }

    function _requireTroveIsActive(address _borrower, address _collateral) internal view {
        require(Troves[_borrower][_collateral].status == Status.active);
    }

    function _requireMoreThanOneTroveInSystem(uint TroveOwnersArrayLength, address _collateral) internal view {
        require (TroveOwnersArrayLength > 1 && sortedTroves.getSize(_collateral) > 1);
    }

    // --- Trove property getters ---

    function getTroveStatus(address _borrower, address _collateral) external view override returns (uint) {
        return uint(Troves[_borrower][_collateral].status);
    }

    function getTroveStake(address _borrower, address _collateral) external view override returns (uint) {
        return Troves[_borrower][_collateral].stake;
    }

    function getTroveDebt(address _borrower, address _collateral) external view override returns (uint) {
        return Troves[_borrower][_collateral].debt;
    }

    function getTroveColl(address _borrower, address _collateral) external view override returns (uint) {
        return Troves[_borrower][_collateral].coll;
    }

    // --- Trove property setters, called by BorrowerOperations ---

    function setTroveStatus(address _borrower, address _collateral, uint _num) external override {
        _requireCallerIsBorrowerOperations();
        Troves[_borrower][_collateral].status = Status(_num);
    }

    function increaseTroveColl(address _borrower, address _collateral, uint _collIncrease) external override returns (uint) {
        _requireCallerIsBorrowerOperations();
        uint newColl = Troves[_borrower][_collateral].coll.add(_collIncrease);
        Troves[_borrower][_collateral].coll = newColl;
        return newColl;
    }

    function decreaseTroveColl(address _borrower, address _collateral, uint _collDecrease) external override returns (uint) {
        _requireCallerIsBorrowerOperations();
        uint newColl = Troves[_borrower][_collateral].coll.sub(_collDecrease);
        Troves[_borrower][_collateral].coll = newColl;
        return newColl;
    }

    function increaseTroveDebt(address _borrower, address _collateral, uint _debtIncrease) external override returns (uint) {
        _requireCallerIsBorrowerOperations();
        uint newDebt = Troves[_borrower][_collateral].debt.add(_debtIncrease);
        Troves[_borrower][_collateral].debt = newDebt;
        return newDebt;
    }

    function decreaseTroveDebt(address _borrower, address _collateral, uint _debtDecrease) external override returns (uint) {
        _requireCallerIsBorrowerOperations();
        uint newDebt = Troves[_borrower][_collateral].debt.sub(_debtDecrease);
        Troves[_borrower][_collateral].debt = newDebt;
        return newDebt;
    }
}