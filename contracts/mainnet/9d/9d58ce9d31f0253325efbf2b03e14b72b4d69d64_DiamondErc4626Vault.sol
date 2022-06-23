// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from  "@openzeppelin/contracts/math/Math.sol";
import {IERC20Detailed} from "../interfaces/IERC20Detailed.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {StrategyParams} from "../interfaces/StrategyParams.sol";
import {ERC4626} from "../library/ERC4626.sol";

/**
 * @notice The vault hold an ERC20 asset and earn yield through multiple strategies.
 * @dev The vault is ERC-4626 compatible and it inherits the design of Yearn Vault v2.
 */
contract DiamondErc4626Vault is ERC4626, ReentrancyGuardUpgradeable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20Detailed;

  /// @dev want asset address
  address public asset;

  /// @dev vault admin
  address public governance;

  /// @dev vault management which has the Keeper permission of strategies
  address public management;

  /// @dev performanceFee & managementFee receiver
  address public feeRecipient;

  /// @dev withdraw queue for vault
  address[MAXIMUM_STRATEGIES] public withdrawalQueue;

  /// @dev pending replacement for governance
  address pendingGovernance;

  /// @dev guardian of vault which has the Keeper permission of strategies
  address public guardian;

  /// @dev dispense rate of relase locked profit per report. 
  ///      example: 7500 means release 25% of locked profit per report
  ///      example: 0 means there is no profit will be locked
  uint256 public dispenseRate = 0;

  /// @dev 1 year = 365 days
  uint256 constant ONE_YEAR = 365 days;

  /// @dev 100% or 10k points
  uint256 constant MAX_BPS = 10_000;

  /// @dev max number of strategy
  uint256 constant MAXIMUM_STRATEGIES = 20;

  /// @dev default 10% of profit (per strategy)
  uint256 public performanceFee = 1000;

  /// @dev default 2% per year
  uint256 public managementFee = 200;

  /// @dev maximum deposit amount of asset
  uint256 public depositLimit;

  /// @dev total debt amount
  uint256 public totalDebt;

  /// @dev total debt ratio
  uint256 public debtRatio;

  /// @dev how much profit is locked and can't be withdrawn
  uint256 public lockedProfit;

  /// @dev emergency shutdown switcher
  bool public emergencyShutdown;

  /// @dev strategies settings
  mapping(address => StrategyParams) public strategies;

  /*=====================
   *       Events       *
   *====================*/

  event EmergencyShutdown(bool active);
  event UpdateGovernance(address indexed governance);
  event UpdateManagement(address indexed management);
  event UpdateGuardian(address indexed guardian);
  event UpdateFeeRecipient(address indexed feeRecipient);
  event UpdateDepositLimit(uint256 depositLimit);
  event UpdatePerformanceFee(uint256 performanceFee);
  event UpdateManagementFee(uint256 managementFee);
  event StrategyReported(
    address indexed strategy, uint256 gain, uint256 loss, uint256 debtPayment,
    uint256 strategyTotalGain, uint256 strategyTotalLoss, uint256 totalDebt,
    uint256 credit, uint256 strategyDebtRatio
  );

  event StrategyAdded(address indexed strategy, uint256 debtRatio, uint256 minDebtPerHarvest, uint256 maxDebtPerHarvest, uint256 performanceFee);
  event StrategyRevoked(address indexed strategy);
  event StrategyUpdateDebtRatio(address indexed strategy, uint256 newDebtRatio);
  event StrategyUpdateMinDebtPerHarvest(address indexed strategy, uint256 minDebtPerHarvest);
  event StrategyUpdateMaxDebtPerHarvest(address indexed strategy, uint256 maxDebtPerHarvest);
  event StrategyUpdatePerformanceFee(address indexed strategy, uint256 performanceFee);
  event StrategyAddedToQueue(address indexed strategy);
  event StrategyRemovedFromQueue(address indexed strategy);

  /*=================
   *   Initialize   *
   *================*/

  /**
   * @notice init function for the vault
   * @param _asset The asset that this vault will manage. Cannot be changed after initializing.
   * @param _governance governace address
   * @param _management management address (manage strategy / strategies store)
   * @param _feeRecipient The address to which all the fees will be sent.
   * @param _tokenName name of the share token given to depositors of this vault
   * @param _tokenSymbol symbol of the share token given to depositors of this vault
   */
  function initialize(
    address _asset,
    address _governance,
    address _management,
    address _feeRecipient,
    string memory _tokenName,
    string memory _tokenSymbol
  ) public initializer {
    require(
      _asset != address(0) &&
      _governance != address(0) &&
      _management != address(0) &&
      _feeRecipient != address(0), '14'
    );
    asset = _asset;
    governance = _governance;
    management = _management;
    feeRecipient = _feeRecipient;
    __ReentrancyGuard_init();
    __ERC20_init(_tokenName, _tokenSymbol);
    _setupDecimals(IERC20Detailed(asset).decimals());
  }

  /*========================
   *   ERC-4626 Functions  *
   *=======================*/

  /**
   * @notice deposit asset into vault
   * @param assets asset amount
   * @param receiver shares recevier address
   * @dev ERC-4626 compatible
   */
  function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
    shares = convertToShares(assets);
    // do condition check on mint
    mint(shares, receiver);
    return shares;
  }

  /**
   * @notice withdraw asset from vault
   * @param assets asset amount
   * @param receiver asset receiver address
   * @param owner will spend owner's shares 
   * @dev ERC-4626 compatible
   */
  function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
    shares = convertToShares(assets);
    _checkWithdraw(shares, msg.sender, owner);
    // nonReentrant
    _withdraw(assets, shares, receiver, owner);
    return shares;
  }

  /**
   * @notice deposit by shares amount
   * @param shares mint shares amount
   * @param receiver shares reciver address
   * @dev ERC-4626 compatible
   */
  function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256 assets) {
    // check mint
    require(
      !emergencyShutdown &&
      shares <= maxMint(receiver) &&
      receiver != address(this) &&
      receiver != address(0), '2');
    assets = convertToAssets(shares);
    // Mint new shares
    _assetSafeTransferFrom(msg.sender, address(this), assets);
    _mint(receiver, shares);
    // afterDeposit(assets, shares);

    emit Deposit(msg.sender, receiver, assets, shares);
    return assets;
  }

  /**
   * @notice withdraw by shares amount
   * @param shares shares amount
   * @param receiver assets receiver address
   * @param owner will spend owner's shares 
   * @dev ERC-4626 compatible
   */
  function redeem(uint256 shares, address receiver, address owner ) public override returns (uint256 assets) {
    _checkWithdraw(shares, msg.sender, owner);
    assets = convertToAssets(shares);
    // nonReentrant
    _withdraw(assets, shares, receiver, owner);
    return assets;
  }

  /**
   * @notice convert from shares to assets
   * @param _shares shares amount
   * @dev ERC-4626 compatible. Converter between shares and assets
   */
  function convertToAssets(uint256 _shares) public view override returns (uint256) {
    return totalSupply() <= 0 ? _shares : _shares.mul(freeTotalAssets()).div(totalSupply());
  }

  /**
   * @notice convert from assets to shares
   * @param assets assets amount
   * @dev ERC-4626 compatible. Converter between shares and assets
   */
  function convertToShares(uint256 assets) public view override returns (uint256) {
    return totalSupply() <= 0 ? assets : assets.mul(totalSupply()).div(freeTotalAssets());
  }

  /**
   * @notice total asset amount in the vault
   * @dev ERC-4626 compatible. Vault's asset amount + totalDebt in strategies
   */
  function totalAssets() public view override returns (uint256) {
    return _assetBalanceOf(address(this)).add(totalDebt);
  }

  /**
   * @notice estimate max deposit amount
   * @param receiver shares receiver address
   * @dev ERC-4626 compatible
   */
  function maxDeposit(address receiver) public view override returns (uint256 assets) {
    // when emergencyShutdown on, will reject any deposit
    return emergencyShutdown ? 0 : depositLimit.sub(totalAssets());
  }

  /**
   * @notice estimate max mint amount
   * @param receiver shares receiver address
   * @dev ERC-4626 compatible
   */
  function maxMint(address receiver) public view override returns (uint256 shares) {
    // when emergencyShutdown on, will reject any mint
    return emergencyShutdown ? 0 : convertToShares(maxDeposit(receiver));
  }

  /**
   * @notice estimate max withdraw amount
   * @param owner will spend owner's shares
   * @dev ERC-4626 compatible
   */
  function maxWithdraw(address owner) public view override returns (uint256 assets) {
    assets = convertToAssets(balanceOf(owner));
    // when emergencyShutdown on, will reject any withdraw
    if (emergencyShutdown) {
      assets = 0;
    } else if (assets > _assetBalanceOf(address(this))) {
      // only can withdraw assets free amount on vault
      assets = _assetBalanceOf(address(this));
    }
    return assets;
  }

  /**
   * @notice estimate max redeem amount
   * @param owner will spend owner's shares
   * @dev ERC-4626 compatible
   */
  function maxRedeem(address owner) public view override returns (uint256 shares) {
    shares = balanceOf(owner);
    uint256 availRedeem = convertToShares(_assetBalanceOf(address(this)));
    // when emergencyShutdown on, will reject any redeem
    if (emergencyShutdown) {
      shares = 0;
    } else if (shares > availRedeem) {
      // only can withdraw shares free amount worth on vault
      shares = availRedeem;
    }
    return shares;
  }

  /**
   * @notice preview receive shares amount after deposit
   * @param assets deposit assets amount
   * @dev ERC-4626 compatible
   */
  function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
    return convertToShares(assets);
  }

  /**
   * @notice preview spent assets amount for mint
   * @param shares mint shares amount
   * @dev ERC-4626 compatible
   */
  function previewMint(uint256 shares) public view override returns (uint256 assets) {
    return convertToAssets(shares);
  }

  /**
   * @notice preview spent shares amount for withdraw
   * @param assets withdraw assets amount
   * @dev ERC-4626 compatible
   *   a. when emergencyShutdown is on, will reject any withdraw
   *   b. only can withdraw free assets in the vault
   */
  function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
    shares = convertToShares(assets);
    // if greater than it, will got revert.
    if (emergencyShutdown || assets > _assetBalanceOf(address(this))) {
      shares = 0;
    }
    return shares;
  }

  /**
   * @notice preview receive assets amount after redeem
   * @param shares shares amount
   * @dev ERC-4626 compatible
   *   a. when emergencyShutdown is on, will reject any redeem
   *   b. only can withdraw free shares (convert to assets) in the vault
   */
  function previewRedeem(uint256 shares) public view override returns (uint256 assets) {
    assets = convertToAssets(shares);
    // if greater than, will got revert.
    if (emergencyShutdown || assets > _assetBalanceOf(address(this))) {
      assets = 0;
    }
    return assets;
  }

  /*=======================
   *  External Functions  *
   *======================*/

  /*--- Start of Vault Management ---*/
  /**
   * @notice Removes tokens from this vault that are not the vault managed asset (token)
   * @param _token token address
   * @param amount token amount
   */
  function sweep(address _token, uint256 amount) external {
    _govOnly();
    // Can't be used to steal what this Vault is protecting
    assert(_token != asset);
    IERC20Detailed(_token).safeTransfer(governance, amount);
  }

  /**
   * @notice withdraw larger asset amount from vault
   * @param assets estimate withdraw amount
   * @param receiver assets receiver
   * @param owner will spend owner's shares
   * @param maxLoss max acceptable loss
   * @dev We need to go get some from our strategies in the withdrawal queue
   *   NOTE: This performs forced withdrawals from each Strategy. During
   *         forced withdrawal, a Strategy may realize a loss. That loss
   *         is reported back to the Vault, and the will affect the amount
   *         of tokens that the withdrawer receives for their shares. They
   *         can optionally specify the maximum acceptable loss (in BPS)
   *         to prevent excessive losses on their withdrawals (which may
   *         happen in certain edge cases where Strategies realize a loss)
   */
  function withdraw(uint256 assets, address receiver, address owner, uint maxLoss) external returns (uint256 shares) {
    //ex uint256 maxLoss = 100; // 1% [BPS]
    shares = convertToShares(assets);
    uint256 originalAssets = assets;
    _checkWithdraw(shares, receiver, owner);
    if (assets > _assetBalanceOf(address(this))) {
      uint256 _totalLoss = 0;
      for (uint8 i = 0; i < MAXIMUM_STRATEGIES; i++) {
        address _strategy = withdrawalQueue[i];
        if (_strategy == address(0)) {
          break;  // We've exhausted the queue
        }
        uint256 _vault_balance = _assetBalanceOf(address(this));
        if (assets <= _vault_balance){
          break;
        }

        uint256 _amountNeeded = assets.sub(_vault_balance);

        // NOTE: Don't withdraw more than the debt so that Strategy can still
        //       continue to work based on the profits it has
        // NOTE: This means that user will lose out on any profits that each
        //       Strategy in the queue would return on next harvest, benefiting others
        _amountNeeded = Math.min(_amountNeeded, strategies[_strategy].totalDebt);

        if (_amountNeeded <= 0) {
          continue; // Nothing to withdraw from this Strategy, try the next one
        }

        // Force withdraw amount from each Strategy in the order set by governance
        uint256 _loss = IStrategy(_strategy).withdraw(_amountNeeded);
        uint256 _withdrawn = _assetBalanceOf(address(this)).sub(_vault_balance);

        if(_loss > 0){
          assets = assets.sub(_loss);
          _totalLoss = _totalLoss.add(_loss);
          _reportLoss(_strategy, _loss);
        }

        // Reduce the Strategy's debt by the amount withdrawn ("realized returns")
        // NOTE: This doesn't add to returns as it's not earned by "normal means"
        _updateStrategyTotalDebt(
          _strategy, strategies[_strategy].totalDebt.sub(_withdrawn)
        );
        totalDebt = totalDebt.sub(_withdrawn);
      }
      // withdrawn everything possible out of the withdrawal queue.
      // withdrawn should very close to withdraw assets amount, otherwise will revert here.
      require( assets <= _assetBalanceOf(address(this)), '10');
      require(_totalLoss <= maxLoss.mul(originalAssets).div(MAX_BPS), '9');
    }
    // nonReentrant
    _withdraw(assets, shares, receiver, owner);
    return shares;
  }

  /**
    @notice
        Reports the amount of assets the calling Strategy has free (usually in
        terms of ROI).

        The performance fee is determined here, off of the strategy's profits
        (if any), and sent to governance.

        The strategist's fee is also determined here (off of profits), to be
        handled according to the strategist on the next harvest.

        This may only be called by a Strategy managed by this Vault.
    @dev
        For approved strategies, this is the most efficient behavior.
        The Strategy reports back what it has free, then Vault "decides"
        whether to take some back or give it more. Note that the most it can
        take is `gain + _debtPayment`, and the most it can give is all of the
        remaining reserves. Anything outside of those bounds is abnormal behavior.

        All approved strategies must have increased diligence around
        calling this function, as abnormal behavior could become catastrophic.
    @param gain Amount Strategy has realized as a gain on it's investment since its
        last report, and is free to be given back to Vault as earnings
    @param loss Amount Strategy has realized as a loss on it's investment since its
        last report, and should be accounted for on the Vault's balance sheet.
        The loss will reduce the debtRatio. The next time the strategy will harvest,
        it will pay back the debt in an attempt to adjust to the new debt limit.
    @param _debtPayment Amount Strategy has made available to cover outstanding debt
    @return Amount of debt outstanding (if totalDebt > debtLimit or emergency shutdown).
    */
  function report(uint256 gain, uint256 loss, uint256 _debtPayment) external returns (uint256) {

    // Only approved strategies can call this function
    require(strategies[msg.sender].activation > 0, '11');
    // No lying about total available to withdraw!
    require(_assetBalanceOf(msg.sender) >= gain.add(_debtPayment), '12');
    
    // We have a loss to report, do it before the rest of the calculactions
    if (loss > 0) {
      _reportLoss(msg.sender, loss);
    }

    // Assess both management fee and performance fee, and issue both as shares of the vault
    uint256 totalFees = _assessFees(msg.sender, gain);

    if (dispenseRate > 0 ) {
      // release fess profit immediately
      uint256 _lockedProfit = lockedProfit.add(gain).sub(totalFees);
      if (_lockedProfit > loss) {
        _lockedProfit = _lockedProfit.sub(loss);
        if (_lockedProfit > MAX_BPS) { // skip tiny amount
          // release dispense rate locked profit and apply new gain to lockedProfit
          lockedProfit = _lockedProfit.div(MAX_BPS).mul(dispenseRate);
        }
      } else {
        lockedProfit = 0;
      }
    } else { // when dispenseRate is zero, free all locked profit
      lockedProfit = 0;
    }

    // Returns are always "realized gains"
    _updateStrategyTotalGain(
      msg.sender, strategies[msg.sender].totalGain.add(gain)
    );

    // Compute the line of credit the Vault is able to offer the Strategy (if any)
    uint256 credit = creditAvailable(msg.sender);

    // Outstanding debt the Strategy wants to take back from the Vault (if any)
    // NOTE: debtOutstanding <= StrategyParams.totalDebt
    uint256 debt = debtOutstanding(msg.sender);
    uint256 debtPayment = Math.min(_debtPayment, debt);

    if (debtPayment > 0) {
      _updateStrategyTotalDebt(
        msg.sender, strategies[msg.sender].totalDebt.sub(debtPayment)
      );
      totalDebt = totalDebt.sub(debtPayment);
      debt = debt.sub(debtPayment);
      // NOTE: `debt` is being tracked for later
    }

    // Update the actual debt based on the full credit we are extending to the Strategy
    // or the returns if we are taking funds back
    // NOTE: credit + self.strategies[msg.sender].totalDebt is always < self.debtLimit
    // NOTE: At least one of `credit` or `debt` is always 0 (both can be 0)
    if (credit > 0){
      _updateStrategyTotalDebt(
        msg.sender, strategies[msg.sender].totalDebt.add(credit)
      );
      totalDebt = totalDebt.add(credit);
    }

    // Give/take balance to Strategy, based on the difference between the reported gains
    // (if any), the debt payment (if any), the credit increase we are offering (if any),
    // and the debt needed to be paid off (if any)
    // NOTE: This is just used to adjust the balance of tokens between the Strategy and
    //       the Vault based on the Strategy's debt limit (as well as the Vault's).
    uint256 totalAvail = gain.add(debtPayment);
    if (totalAvail < credit) { // credit surplus, give to Strategy
      _assetSafeTransfer(msg.sender, credit.sub(totalAvail));
    } else if (totalAvail > credit) { // credit deficit, take from Strategy
      _assetSafeTransferFrom(msg.sender, address(this), totalAvail.sub(credit));
    }
    // else, don't do anything because it is balanced
    _updateStrategyLastReport(msg.sender);

    emit StrategyReported(
      msg.sender,
      gain,
      loss,
      debtPayment,
      strategies[msg.sender].totalGain,
      strategies[msg.sender].totalLoss,
      strategies[msg.sender].totalDebt,
      credit,
      strategies[msg.sender].debtRatio
    );

    if (strategies[msg.sender].debtRatio == 0 || emergencyShutdown) {
      return IStrategy(msg.sender).estimatedTotalAssets();
    } else {
      return debt;
    }
  }

  /**
   * @notice update maxmium vault deposit amount
   * @param _limit new maxmium deposit amount
   */
  function setDepositLimit(uint256 _limit) external {
    _govOnly();
    depositLimit = _limit;
    emit UpdateDepositLimit(depositLimit);
  }

  /**
   * @notice pause vault for security or operational issues
   * @param _active on/off switcher
   */
  function setEmergencyShutdown(bool _active) external {
    _govOnly();
    emergencyShutdown = _active;
    emit EmergencyShutdown(_active);
  }

  /**
   * @notice update management fee
   * @param _managementFee percenetage of MAX_BPS
   * @dev e.g. 1000 = 1%
   */
  function setManagementFee(uint256 _managementFee) external {
    require(_managementFee <= MAX_BPS, "15");
    _govOnly();
    managementFee = _managementFee;
    emit UpdateManagementFee(managementFee);
  }

  /**
   * @notice update performance fee
   * @param _performanceFee percenetage of MAX_BPS
   * @dev e.g. 1000 = 1%
   */
  function setPerfromanceFee(uint256 _performanceFee) external {
    require(_performanceFee <= MAX_BPS, "16");
    _govOnly();
    performanceFee = _performanceFee;
    emit UpdatePerformanceFee(performanceFee);
  }

  /**
   * @notice update governance address
   * @param _newgov new governance address
   * @dev after this, then call acceptGovernance to commit changes
   */
  function setGovernance(address _newgov) external {
    _govOnly();
    pendingGovernance = _newgov;
  }

  /**
   * @notice commit pendingGovernance
   * @dev call this function using new governance address
   */
  function acceptGovernance() external {
    require(msg.sender == pendingGovernance, '13');
    governance = pendingGovernance;
    emit UpdateGovernance(governance);
  }

  /**
   * @notice update management address
   * @param _newman new management address
   */
  function setManagement(address _newman) external {
    require(_newman != address(0), '17');
    _govOnly();
    management = _newman;
    emit UpdateManagement(management);
  }

  /**
   * @notice update guardian address
   * @param _newGuardian new guardian address
   */
  function setGuardian(address _newGuardian) external {
    // accept current guardian can do this action
    if (msg.sender != guardian) {
      _govOnly();
    }
    guardian = _newGuardian;
    emit UpdateGuardian(guardian);
  }

  /**
   * @notice update fee recipient address
   * @param _feeReceipt new recipient address
   */
  function setFeeRecipient(address _feeReceipt) external {
    require(_feeReceipt != address(0), '18');
    _govOnly();
    feeRecipient = _feeReceipt;
    emit UpdateFeeRecipient(feeRecipient);
  }

  /**
   * @notice update dispense rate of locked profit
   * @param _dispenseRate new rate of dispenseRate
   */
  function setDispenseRate(uint256 _dispenseRate) external {
    _govOnly();
    require(_dispenseRate < MAX_BPS, "20");
    dispenseRate = _dispenseRate;
  }
  /*--- End of Vault Management ---*/

  /*--- Start of Strategy Management ---*/
  /**
   * @notice Add `strategy` to `withdrawalQueue`.
   * @param strategy The Strategy to add.
   * @dev The Strategy will be appended to `withdrawalQueue`
   * 
   * This may only be called by governance.
   */
  function addStrategyToQueue(address strategy) public {
    _governances();
    require(strategies[strategy].activation > 0, '3');

    uint256 last_idx = 0;
    for (uint8 i = 0; i < withdrawalQueue.length; i++) {
      address s = withdrawalQueue[i];
      if (s == address(0)){
        break;
      }
      // Can't already be in the queue
      require(s != strategy, '4');
      last_idx += 1;
    }
    // Check if queue is full
    require(last_idx < MAXIMUM_STRATEGIES, '5');

    // fill empty slot of withdrawalQueue
    withdrawalQueue[last_idx] = strategy;
    emit StrategyAddedToQueue(strategy);
  }

  /**
   * @notice insert `strategy` posistion to `withdrawalQueue`.
   * @param strategy The Strategy to insert.
   * @param index index of withdrawalQueue
   * @dev The Strategy will be insert to `withdrawalQueue`.
   *      will delete the same insert strategy in the queue first, then
   *      add it into the index directly, 
   *      (if there any other strategy exists, it will shift into the following index)
   * 
   * This may only be called by governance or management.
   */
  function insertStrategyToQueue(address strategy, uint8 index) external {
    _governances();
    require(index < MAXIMUM_STRATEGIES, "23");
    require(strategies[strategy].activation > 0, '3');

    // clone current queue
    address[MAXIMUM_STRATEGIES] memory cloneQueue = withdrawalQueue;
    for (uint8 i = 0; i < withdrawalQueue.length; i++) {
      address s = withdrawalQueue[i];
      if (s == strategy){
        // delete same strategy if exisit
        withdrawalQueue[i] = address(0);
      }
      if (i == index) {
        // replace strategy in queue
        if (withdrawalQueue[i] != address(0)) {
          emit StrategyRemovedFromQueue(withdrawalQueue[i]);
        }
        withdrawalQueue[i] = strategy;
      } else if (i > index) {
        // skip same strategy
        if (cloneQueue[i-1] != strategy) {
          withdrawalQueue[i] = cloneQueue[i-1];
        }
      }
    }
    // Remove gaps in withdrawal queue
    _organizeWithdrawalQueue();
    emit StrategyAddedToQueue(strategy);
  }

  /**
   * @notice Change the quantity of assets `strategy` may manage.
   * @param _strategy strategy to update.
   * @param _newDebtRatio debtRatio The quantity of assets `strategy` may now manage.
   * @dev This may only be called by governance.
   */
  function updateStrategyDebtRatio(address _strategy, uint256 _newDebtRatio) public {
    _governances();
    _updateStrategyDebtRatio(_strategy, _newDebtRatio);
  }

  /**
   * @notice Remove `strategy` from `withdrawalQueue`
   * @param strategy The strategy to remove.
   * @dev We don't do this with revokeStrategy because it should still
   *   be possible to withdraw from the Strategy if it's unwinding.
   * 
   * This may only be called by governance.
   */
  function removeStrategyFromQueue(address strategy) external {
    _governances();
    for (uint8 i = 0; i < withdrawalQueue.length; i++) {
      if (withdrawalQueue[i] == strategy){
        withdrawalQueue[i] = address(0);
        _organizeWithdrawalQueue();
        emit StrategyRemovedFromQueue(strategy);
      }
    }
  }

  /**
   * @notice Add a Strategy to the Vault
   * @param _strategy The address of the Strategy to add
   * @param _debtRatio The share of the total assets in the `vault that the `strategy` has access to
   * @param _minDebtPerHarvest Lower limit on the increase of debt since last harvest
   * @param _maxDebtPerHarvest Upper limit on the increase of debt since last harvest
   * @param _performanceFee The fee the strategist will receive based on this Vault's performance
   * @dev The Strategy will be appended to `withdrawalQueue`
   * 
   * This may only be called by governance.
   */
  function addStrategy(
    address _strategy,
    uint256 _debtRatio,
    uint256 _minDebtPerHarvest,
    uint256 _maxDebtPerHarvest,
    uint256 _performanceFee) external {
    _governances();
    // vault address check
    require(_strategy != address(0), '7');
    // Check strategy configuration
    require(asset == IStrategy(_strategy).want(), '9');
    require(address(this) == IStrategy(_strategy).vault(), '5');
    // Check calling conditions
    require(!emergencyShutdown, '6');


    // Check strategy parameters
    require(_minDebtPerHarvest <= _maxDebtPerHarvest, '10');
    // performance fee can not greater than 50%
    require(_performanceFee <= MAX_BPS / 2, '11');
    require(debtRatio.add(_debtRatio) <= MAX_BPS, '12');

    // Add strategy to approved strategies
    strategies[_strategy] = StrategyParams({
        performanceFee: _performanceFee,
        activation: block.timestamp,
        debtRatio: _debtRatio,
        minDebtPerHarvest: _minDebtPerHarvest,
        maxDebtPerHarvest: _maxDebtPerHarvest,
        lastReport: block.timestamp,
        totalDebt: 0,
        totalGain: 0,
        totalLoss: 0
    });

    // Update Vault parameters
    _updateDebtRatio(
      debtRatio.add(_debtRatio)
    );

    addStrategyToQueue(_strategy);
    emit StrategyAdded(_strategy, _debtRatio, _minDebtPerHarvest, _maxDebtPerHarvest, _performanceFee);
  }

  /**
   * @notice Revoke a Strategy, should change debt limit to 0 in advance.
   *   This function should only be used in the scenario where the Strategy is
   *   being retired , or in the extreme scenario that the Strategy needs to be
   *   put into "Emergency Exit" mode in order for it to exit as quickly as possible.
   *
   *   The latter scenario could be for any reason that is considered "critical"
   *   that the Strategy exits its position as fast as possible, such as a sudden
   *   change in market conditions leading to losses, or an imminent failure
   *   in an external dependency.
   * @param strategy The Strategy to revoke.
   * @dev should change debt limit to 0 in advance and call harvest to return fund
   *   back to vault.
   *
   * This may only be called by governance.
   */
  function revokeStrategy(address strategy) external {
    // accpet emergencExit callback from strategy self
    if (msg.sender != strategy) {
      _governances();
    }
    require(strategies[strategy].debtRatio == 0, '13'); // only zero debtRation can revoke
    strategies[strategy].activation = 0;
    emit StrategyRevoked(strategy);
  }

  /**
   * @notice Change the fee the strategist will receive based on this Vault's
   *   performance.
   * @param _strategy strategy to update.
   * @param _performanceFee The new fee the strategist will receive.
   * @dev This may only be called by governance.
   */
  function updateStrategyPerformanceFee(address _strategy, uint256 _performanceFee) external {
    _governances();
    require(strategies[_strategy].activation > 0, '14');
    // performance fee can not greater than 50%
    require(_performanceFee <= MAX_BPS / 2, '24');
    strategies[_strategy].performanceFee = _performanceFee;
    emit StrategyUpdatePerformanceFee(_strategy, _performanceFee);
  }

  /**
   * @notice Change the assets amount per block this Vault may deposit to or
   *   withdraw from `strategy`.
   * @param _strategy The strategy to update.
   * @param _minDebtPerHarvest Lower limit on the increase of debt since last harvest
   * @dev This may only be called by governance.
   */
  function updateStrategyMinDebtPerHarvest(address _strategy, uint256 _minDebtPerHarvest) external {
    _governances();
    require(strategies[_strategy].activation > 0, '16');
    require(strategies[_strategy].maxDebtPerHarvest >= _minDebtPerHarvest, '17');
    strategies[_strategy].minDebtPerHarvest = _minDebtPerHarvest;
    emit StrategyUpdateMinDebtPerHarvest(_strategy, _minDebtPerHarvest);
  }

  /**
   * @notice Change the assets amount per block this Vault may deposit to or
   *   withdraw from `strategy`.
   * @param _strategy The strategy to update.
   * @param _maxDebtPerHarvest Upper limit on the increase of debt since last harvest
   * @dev This may only be called by governance.
   */
  function updateStrategyMaxDebtPerHarvest(address _strategy, uint256 _maxDebtPerHarvest) external {
    _governances();
    require(strategies[_strategy].activation > 0, '18');
    require(strategies[_strategy].minDebtPerHarvest <= _maxDebtPerHarvest, '19');
    strategies[_strategy].maxDebtPerHarvest = _maxDebtPerHarvest;
    emit StrategyUpdateMaxDebtPerHarvest(_strategy, _maxDebtPerHarvest);
  }
  /*--- End of Strategy Management ---*/

  /*===================
   *  View Functions  *
   *==================*/

  /**
    @notice
        Amount of tokens in Vault a Strategy has access to as a credit line.

        This will check the Strategy's debt limit, as well as the tokens
        available in the Vault, and determine the maximum amount of tokens
        (if any) the Strategy may draw on.

        In the rare case the Vault is in emergency shutdown this will return 0.
    @param _strategy The Strategy to check. Defaults to caller.
    @return The quantity of tokens available for the Strategy to draw on.
    */
  function creditAvailable(address _strategy) public view returns (uint256) {
    if (emergencyShutdown) {
      return 0;
    }

    uint256 vaultTotalAssets = totalAssets();
    uint256 vaultDebtLimit = debtRatio.mul(vaultTotalAssets).div(MAX_BPS);
    uint256 vaultTotalDebt = totalDebt;
    uint256 strategyDebtLimit = strategies[_strategy].debtRatio.mul(vaultTotalAssets).div(MAX_BPS);
    uint256 strategyTotalDebt = strategies[_strategy].totalDebt;
    uint256 strategyMinDebtPerHarvest = strategies[_strategy].minDebtPerHarvest;
    uint256 strategyMaxDebtPerHarvest = strategies[_strategy].maxDebtPerHarvest;

    // Exhausted credit line
    if (strategyDebtLimit <= strategyTotalDebt ||
      vaultDebtLimit <= vaultTotalDebt){
      return 0;
    }

    // Start with debt limit left for the Strategy
    uint256 available = strategyDebtLimit.sub(strategyTotalDebt);

    // Adjust by the global debt limit left
    available = Math.min(available, vaultDebtLimit.sub(vaultTotalDebt));

    // Can only borrow up to what the contract has in reserve
    // NOTE: Running near 100% is discouraged
    available = Math.min(available, _assetBalanceOf(address(this)));

    // Adjust by min and max borrow limits (per harvest)
    // NOTE: min increase can be used to ensure that if a strategy has a minimum
    //       amount of capital needed to purchase a position, it's not given capital
    //       it can't make use of yet.
    // NOTE: max increase is used to make sure each harvest isn't bigger than what
    //       is authorized. This combined with adjusting min and max periods in
    //       `BaseStrategy` can be used to effect a "rate limit" on capital increase.
    if (available < strategyMinDebtPerHarvest) {
      return 0;
    } else {
      return Math.min(available, strategyMaxDebtPerHarvest);
    }
  }

  /** 
    @notice
        Determines if `strategy` is past its debt limit and if any tokens
        should be withdrawn to the Vault.
    @param _strategy The Strategy to check. Defaults to the caller.
    @return The quantity of tokens to withdraw.
  */
  function debtOutstanding(address _strategy) public view returns (uint256) {
    if (debtRatio == 0){
      return strategies[_strategy].totalDebt;
    }

    uint256 strategyDebtLimit = strategies[_strategy].debtRatio.mul(totalAssets()).div(MAX_BPS);

    uint256 strategyTotalDebt = strategies[_strategy].totalDebt;

    if (emergencyShutdown) {
      return strategyTotalDebt;
    } else if (strategyTotalDebt <= strategyDebtLimit) {
      return 0;
    } else {
      return strategyTotalDebt.sub(strategyDebtLimit);
    }
  }

  /**
   * @notice calculate free funds can withdrawn
   */
  function  freeTotalAssets() public view returns (uint256) {
    return totalAssets().sub(lockedProfit);
  }

  /**
    @notice
        Determines the maximum quantity of shares this Vault can facilitate a
        withdrawal for, factoring in assets currently residing in the Vault,
        as well as those deployed to strategies on the Vault's balance sheet.
    @dev
        Regarding how shares are calculated, see dev note on `deposit`.

        If you want to calculated the maximum a user could withdraw up to,
        you want to use this function.

        Note that the amount provided by this function is the theoretical
        maximum possible from withdrawing, the real amount depends on the
        realized losses incurred during withdrawal.
    @return The total quantity of shares this Vault can provide.
    */
  function maxAvailableShares() external view returns(uint256) {
    uint256 _shares = convertToShares(_assetBalanceOf(address(this)));
    for (uint8 idx = 0; idx < MAXIMUM_STRATEGIES; idx++) {
      address _strategy = withdrawalQueue[idx];
      if (_strategy == address(0)) {
        break;
      }
      _shares = _shares.add(convertToShares(strategies[_strategy].totalDebt));
    }
    return _shares;
  }

  /**
   * @notice 1 asset price per share
   * @dev 1 shares to asset value
   */
  function pricePerShare() external view returns (uint256) {
    return convertToAssets(10 ** decimals());
  }

  /**
   * @notice return token wants
   * @dev a helper function for strategy API
   */
  function token() external view returns (address) {
    return asset;
  }

  /*=======================
   *  Internal Functions  *
   *======================*/

  /**
   * @notice internal function for checking permission
   * @dev for saving contract size
   */
  function _govOnly() internal {
    require(msg.sender == governance, '1');
  }

  /**
   * @notice internal function for checking permission
   * @dev Only governance, management have permission
   */
  function _governances() internal {
    require(
      msg.sender == governance || 
      msg.sender == management,
    '1');
  }

  /**
   * @notice calculate fee for a strategy when report
   * @param strategy strategy address
   * @param gain gain asset amount
   */
  function _assessFees(address strategy, uint256 gain) internal returns (uint256) {
    // Issue new shares to cover fees
    // NOTE: In effect, this reduces overall share price by the combined fee
    // NOTE: may throw if Vault.totalAssets() > 1e64, or not called for more than a year
    uint256 duration = block.timestamp.sub(strategies[strategy].lastReport);
    require(duration != 0, '6'); // can't assessFees twice within the same block
    if(gain == 0) {
      // NOTE: The fees are not charged if there hasn't been any gains reported
      return 0;
    }

    uint256 _managementFee = (
      (
        (strategies[strategy].totalDebt)
        .mul(duration)
        .mul(managementFee)
      ).div(MAX_BPS).div(ONE_YEAR)
    );

    // NOTE: Applies if Strategy is not shutting down, or it is but all debt paid off
    // NOTE: No fee is taken when a Strategy is unwinding it's position, until all debt is paid
    uint256 _strategistFee = gain.mul(strategies[strategy].performanceFee).div(MAX_BPS);


    // NOTE: Unlikely to throw unless strategy reports >1e72 harvest profit
    uint256 _performanceFee = gain.mul(performanceFee).div(MAX_BPS);

    // NOTE: This must be called prior to taking new collateral,
    //       or the calculation will be wrong!
    // NOTE: This must be done at the same time, to ensure the relative
    //       ratio of governance_fee : _strategistFee is kept intact
    uint256 _totalFee = _performanceFee.add(_strategistFee).add(_managementFee);
    // ensure _totalFee is not more than gain
    if (_totalFee > gain){
      _totalFee = gain;
    }

    if (_totalFee > 0) {  // NOTE: If mgmt fee is 0% and no gains were realized, skip
      uint256 reward = convertToShares(_totalFee);
      _mint(address(this), reward);
      // Send the rewards out as new shares in this Vault
      if (_strategistFee > 0) {  // NOTE: Guard against DIV/0 fault
        // NOTE: Unlikely to throw unless sqrt(reward) >>> 1e39
        uint256 _strategistReward = _strategistFee.mul(reward).div(_totalFee);
        _transfer(address(this), strategy, _strategistReward);
        // NOTE: Strategy distributes rewards at the end of harvest()
      }
      // NOTE: Governance earns any dust leftover from flooring math above
      if (balanceOf(address(this)) > 0){
        _transfer(address(this), feeRecipient, balanceOf(address(this)));
      }
    }
    return _totalFee;
  }

  /**
   * @notice safe transfer assets
   * @param to receiver address
   * @param amount recevier amount
   * @dev for saving gas and contract size
   */
  function _assetSafeTransfer(address to, uint256 amount) internal {
    IERC20Detailed(asset).safeTransfer(to, amount);
  }

  /**
   * @notice safe transfer assets by allowance
   * @param from sender address
   * @param to receiver address
   * @param amount recevier amount
   * @dev for saving gas and contract size
   */
  function _assetSafeTransferFrom(address from, address to, uint256 amount) internal {
    IERC20Detailed(asset).safeTransferFrom(from, to, amount);
  }

  /**
   * @notice internal helper function for checking requirements before withdraw fund
   * @param shares withdraw shares amount
   * @param receiver asserts recevier
   * @param owner will spend owner's shares
   * @dev common function for checking before withdraw fund
   */
  function _checkWithdraw(uint256 shares, address receiver, address owner) internal {
    // check fund available with flag
    require(
      !emergencyShutdown &&
      shares > 0 &&
      receiver != address(0) &&
      receiver != address(this) &&
      msg.sender != owner ?  allowance(owner, msg.sender) >= shares : balanceOf(msg.sender) >= shares
      , '15');
  }

  /**
   * @notice report loss of strategy
   * @param _strategy strategy address
   * @param _loss loss amount
   */
  function _reportLoss(address _strategy, uint256 _loss) internal {
    // Loss can only be up the amount of debt issued to strategy
    uint256 _totalDebt = strategies[_strategy].totalDebt;
    require(_totalDebt >= _loss, '3');

    if (debtRatio != 0) {
      uint256 ratio_change = Math.min(
        _loss.mul(debtRatio).div(totalDebt),
        strategies[_strategy].debtRatio
      );
      // strategies[_strategy].debtRatio -= ratio_change;
      // will also do debtRatio -= ratio_change;
      _updateStrategyDebtRatio(
        _strategy, strategies[_strategy].debtRatio.sub(ratio_change)
      );
    }
    // Finally, adjust our strategy's parameters by the loss
    _updateStrategyTotalLoss(
      _strategy, strategies[_strategy].totalLoss.add(_loss)
    );
    // update totalDebt amount (subtract loss) for strategy
    _updateStrategyTotalDebt(_strategy, _totalDebt.sub(_loss));
    // update totalDebt amount (subtract loss) for vault
    totalDebt = totalDebt.sub(_loss);
  }

  /**
   * @notice execute withdraw
   * @param assets withdraw amount (price value equals shares)
   * @param shares withdraw shares amount (price value equals assets)
   * @param receiver assets receiver address
   * @param owner will spend owner's shares
   */
  function _withdraw(uint256 assets, uint256 shares, address receiver, address owner) internal nonReentrant {
    if (msg.sender != owner) {
      uint256 allowed = allowance(owner, msg.sender);
      // save gas for unlimited approvals
      if (allowed < type(uint256).max) {
        _approve(owner, msg.sender, allowed.sub(shares)); // update approve amount
      }
    }
    // beforeWithdraw(assets, shares);
    _burn(owner, shares);
    _assetSafeTransfer(receiver, assets);
    emit Withdraw(msg.sender, receiver, owner, assets, shares);
  }

  /**
   * @notice query balance of ERC20 token
   * @param target ERC20 owner address
   * @dev for saving contract size
   */
  function _assetBalanceOf(address target) internal view returns (uint256) {
    return IERC20Detailed(asset).balanceOf(target);
  }

  /*--- Start of Strategy Management ---*/
  /**
   * @notice Change the quantity of assets `strategy` may manage.
   * @param _strategy strategy to update.
   * @param _newDebtRatio debtRatio The quantity of assets `strategy` may now manage.
   * @dev call from contract inside.
   */
  function _updateStrategyDebtRatio(address _strategy, uint256 _newDebtRatio) internal {
    uint256 strategiesDebRatio = strategies[_strategy].debtRatio;
    uint256 _debtRatio = debtRatio;
    if (_newDebtRatio > strategiesDebRatio) {
      _debtRatio = _debtRatio.add(
        _newDebtRatio.sub(strategies[_strategy].debtRatio)
      );
    } else if (_newDebtRatio < strategiesDebRatio) {
      _debtRatio = _debtRatio.sub(
        strategies[_strategy].debtRatio.sub(_newDebtRatio)
      );
    }
    require(_debtRatio <= MAX_BPS, '15');
    strategies[_strategy].debtRatio = _newDebtRatio;
    _updateDebtRatio(_debtRatio);
    emit StrategyUpdateDebtRatio(_strategy, _newDebtRatio);
  }

  /**
   * @notice accpet stategiesStore callback to update total debtRatio
   * @param _debtRatio update value for debtRatio
   * @dev call from contract inside.
   */
  function _updateDebtRatio(uint256 _debtRatio) internal {
    require(_debtRatio <= MAX_BPS, '5');
    debtRatio = _debtRatio;
  }

  /**
   * @notice Change totalDebt amount for strategy, vault will use this to 
   *   estimate total gain amount of this strategy.
   * @param _strategy The Strategy to update.
   * @param _totalGain The asset amount want update.
   * @dev call from contract inside.
   */
  function _updateStrategyTotalGain(address _strategy, uint256 _totalGain) internal {
    require(strategies[_strategy].activation > 0, '21');
    strategies[_strategy].totalGain = _totalGain;
  }

  /**
   * @notice Change totalDebt amount for strategy, vault will use this to 
   *   estimate debtation amount of this strategy.
   * @param _strategy The Strategy to update.
   * @param _totalDebt The asset amount want to update.
   * @dev call from contract inside.
   */
  function _updateStrategyTotalDebt(address _strategy, uint256 _totalDebt) internal {
    require(strategies[_strategy].activation > 0, '20');
    strategies[_strategy].totalDebt = _totalDebt;
  }

  /**
   * @notice Change totalDebt amount for strategy, vault will use this to 
   *   estimate debtation amount of this strategy.
   * @param _strategy The Strategy to update.
   * @param _totalLoss The asset amount want to update.
   * @dev call from contract inside.
   */
  function _updateStrategyTotalLoss(address _strategy, uint256 _totalLoss) internal {
    require(strategies[_strategy].activation > 0, '22');
    strategies[_strategy].totalLoss = _totalLoss;
  }

  /**
   * @notice Change lastReport timestamp, Vault will based timestamp to
   *   calculate management fee
   * @param _strategy The strategy to update.
   * @dev call from contract inside.
   */
  function _updateStrategyLastReport(address _strategy) internal {
    strategies[_strategy].lastReport = block.timestamp;
  }

  /**
   * @notice Reorganize `withdrawalQueue` based on premise that if there is an
   *   empty value between two actual values, then the empty value should be
   *   replaced by the later value.
   */
  function _organizeWithdrawalQueue() internal {
    uint256 offset = 0;
    for (uint8 idx = 0; idx < MAXIMUM_STRATEGIES; idx++) {
        address strategy = withdrawalQueue[idx];
        if (strategy == address(0)) {
          offset += 1;  // how many values we need to shift, always `<= idx`
        } else if ( offset > 0 ) {
          withdrawalQueue[idx - offset] = strategy;
          withdrawalQueue[idx] = address(0);
        }
    }
  }
  /*--- End of Strategy Management ---*/
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

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
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
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
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
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
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
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
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Detailed is IERC20 {
  function decimals() external view returns (uint8);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;

interface IStrategy {
    function want() external view returns (address);
    function vault() external view returns (address);
    function isActive() external view returns (bool);
    function delegatedAssets() external view returns (uint256);
    function estimatedTotalAssets() external view returns (uint256);
    function withdraw(uint256) external returns (uint256);
    function migrate(address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;
pragma experimental ABIEncoderV2;

struct StrategyParams {
    uint256 performanceFee; // Strategist's fee (basis points)
    uint256 activation; // Activation block.timestamp
    uint256 debtRatio; // Maximum borrow amount (in BPS of total assets)
    uint256 minDebtPerHarvest; // Lower limit on the increase of debt since last harvest
    uint256 maxDebtPerHarvest; // Upper limit on the increase of debt since last harvest
    uint256 lastReport; // block.timestamp of the last time a report occured
    uint256 totalDebt; // Total outstanding debt that Strategy has
    uint256 totalGain; // Total returns that Strategy has realized for Vault
    uint256 totalLoss; // Total losses that Strategy has realized for Vault
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

abstract contract ERC4626 is ERC20Upgradeable {

  /*///////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

  event Withdraw(
    address indexed caller,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares
  );

  /*///////////////////////////////////////////////////////////////
                      DEPOSIT/WITHDRAWAL LOGIC
  //////////////////////////////////////////////////////////////*/

  function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {}

  function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {}

  function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {}

  function redeem( uint256 shares, address receiver, address owner ) public virtual returns (uint256 assets) {}

  /*///////////////////////////////////////////////////////////////
                          ACCOUNTING LOGIC
  //////////////////////////////////////////////////////////////*/

  function totalAssets() public view virtual returns (uint256);

  function convertToShares(uint256 assets) public view virtual returns (uint256) {}

  function convertToAssets(uint256 shares) public view virtual returns (uint256) {}

  function previewDeposit(uint256 assets) public view virtual returns (uint256) {}

  function previewMint(uint256 shares) public view virtual returns (uint256) {}

  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {}

  function previewRedeem(uint256 shares) public view virtual returns (uint256) {}

  /*///////////////////////////////////////////////////////////////
                    DEPOSIT/WITHDRAWAL LIMIT LOGIC
  //////////////////////////////////////////////////////////////*/

  function maxDeposit(address receiver) public view virtual returns (uint256) {}
  function maxMint(address receiver) public view virtual returns (uint256) {}
  function maxWithdraw(address owner) public view virtual returns (uint256) {}
  function maxRedeem(address owner) public view virtual returns (uint256) {}

  /*///////////////////////////////////////////////////////////////
                        INTERNAL HOOKS LOGIC
  //////////////////////////////////////////////////////////////*/

  function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}
  function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/ContextUpgradeable.sol";
import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../proxy/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable {
    using SafeMathUpgradeable for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

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
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
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
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
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
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
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
        require(b > 0, errorMessage);
        return a % b;
    }
}