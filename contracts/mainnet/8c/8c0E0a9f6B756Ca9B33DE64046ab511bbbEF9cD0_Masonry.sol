// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IERC20.sol";
import "./SafeERC20.sol";

import "./ContractGuard.sol";
import "./IBasisAsset.sol";
import "./ITreasury.sol";

contract ShareWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public sshare;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        sshare.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        uint256 masonShare = _balances[msg.sender];
        require(
            masonShare >= amount,
            "Masonry: withdraw request greater than staked amount"
        );
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = masonShare.sub(amount);
        sshare.safeTransfer(msg.sender, amount);
    }
}

/*
   _____ ________________  _____   ________
  / ___// ____/ ____/ __ \/  _/ | / / ____/
  \__ \/ __/ / __/ / / / // //  |/ / / __  
 ___/ / /___/ /___/ /_/ // // /|  / /_/ /  
/____/_____/_____/_____/___/_/ |_/\____/   
*/
contract Masonry is ShareWrapper, ContractGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== DATA STRUCTURES ========== */

    struct Masonseat {
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
        uint256 epochTimerStart;
    }

    struct MasonrySnapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerShare;
    }

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // flags
    bool public initialized = false;

    IERC20 public seed;
    ITreasury public treasury;

    mapping(address => Masonseat) public masons;
    MasonrySnapshot[] public masonryHistory;

    uint256 public withdrawLockupEpochs;
    uint256 public rewardLockupEpochs;

    /* ========== EVENTS ========== */

    event Initialized(address indexed executor, uint256 at);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(address indexed user, uint256 reward);

    /* ========== Modifiers =============== */

    modifier onlyOperator() {
        require(operator == msg.sender, "Masonry: caller is not the operator");
        _;
    }

    modifier masonExists() {
        require(balanceOf(msg.sender) > 0, "Masonry: The mason does not exist");
        _;
    }

    modifier updateReward(address mason) {
        if (mason != address(0)) {
            Masonseat memory seat = masons[mason];
            seat.rewardEarned = earned(mason);
            seat.lastSnapshotIndex = latestSnapshotIndex();
            masons[mason] = seat;
        }
        _;
    }

    modifier notInitialized() {
        require(!initialized, "Masonry: already initialized");
        _;
    }

    /* ========== GOVERNANCE ========== */

    function initialize(
        IERC20 _seed,
        IERC20 _sshare,
        ITreasury _treasury
    ) public notInitialized {
        seed = _seed;
        sshare = _sshare;
        treasury = _treasury;

        MasonrySnapshot memory genesisSnapshot = MasonrySnapshot({
            time: block.number,
            rewardReceived: 0,
            rewardPerShare: 0
        });
        masonryHistory.push(genesisSnapshot);

        withdrawLockupEpochs = 6; // Lock for 6 epochs (36h) before release withdraw
        rewardLockupEpochs = 3; // Lock for 3 epochs (18h) before release claimReward

        initialized = true;
        operator = msg.sender;
        emit Initialized(msg.sender, block.number);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setLockUp(
        uint256 _withdrawLockupEpochs,
        uint256 _rewardLockupEpochs
    ) external onlyOperator {
        require(
            _withdrawLockupEpochs >= _rewardLockupEpochs &&
                _withdrawLockupEpochs <= 56,
            "_withdrawLockupEpochs: out of range"
        ); // <= 2 week
        withdrawLockupEpochs = _withdrawLockupEpochs;
        rewardLockupEpochs = _rewardLockupEpochs;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // =========== Snapshot getters

    function latestSnapshotIndex() public view returns (uint256) {
        return masonryHistory.length.sub(1);
    }

    function getLatestSnapshot()
        internal
        view
        returns (MasonrySnapshot memory)
    {
        return masonryHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address mason)
        public
        view
        returns (uint256)
    {
        return masons[mason].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address mason)
        internal
        view
        returns (MasonrySnapshot memory)
    {
        return masonryHistory[getLastSnapshotIndexOf(mason)];
    }

    function canWithdraw(address mason) external view returns (bool) {
        return
            masons[mason].epochTimerStart.add(withdrawLockupEpochs) <=
            treasury.epoch();
    }

    function canClaimReward(address mason) external view returns (bool) {
        return
            masons[mason].epochTimerStart.add(rewardLockupEpochs) <=
            treasury.epoch();
    }

    function epoch() external view returns (uint256) {
        return treasury.epoch();
    }

    function nextEpochPoint() external view returns (uint256) {
        return treasury.nextEpochPoint();
    }

    function getTombPrice() external view returns (uint256) {
        return treasury.getTombPrice();
    }

    // =========== Mason getters

    function rewardPerShare() public view returns (uint256) {
        return getLatestSnapshot().rewardPerShare;
    }

    function earned(address mason) public view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerShare;
        uint256 storedRPS = getLastSnapshotOf(mason).rewardPerShare;

        return
            balanceOf(mason).mul(latestRPS.sub(storedRPS)).div(1e18).add(
                masons[mason].rewardEarned
            );
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount)
        public
        override
        onlyOneBlock
        updateReward(msg.sender)
    {
        require(amount > 0, "Masonry: Cannot stake 0");
        super.stake(amount);
        masons[msg.sender].epochTimerStart = treasury.epoch(); // reset timer
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        onlyOneBlock
        masonExists
        updateReward(msg.sender)
    {
        require(amount > 0, "Masonry: Cannot withdraw 0");
        require(
            masons[msg.sender].epochTimerStart.add(withdrawLockupEpochs) <=
                treasury.epoch(),
            "Masonry: still in withdraw lockup"
        );
        claimReward();
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
    }

    function claimReward() public updateReward(msg.sender) {
        uint256 reward = masons[msg.sender].rewardEarned;
        if (reward > 0) {
            require(
                masons[msg.sender].epochTimerStart.add(rewardLockupEpochs) <=
                    treasury.epoch(),
                "Masonry: still in reward lockup"
            );
            masons[msg.sender].epochTimerStart = treasury.epoch(); // reset timer
            masons[msg.sender].rewardEarned = 0;
            seed.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function allocateSeigniorage(uint256 amount)
        external
        onlyOneBlock
        onlyOperator
    {
        require(amount > 0, "Masonry: Cannot allocate 0");
        require(
            totalSupply() > 0,
            "Masonry: Cannot allocate when totalSupply is 0"
        );

        // Create & add new snapshot
        uint256 prevRPS = getLatestSnapshot().rewardPerShare;
        uint256 nextRPS = prevRPS.add(amount.mul(1e18).div(totalSupply()));

        MasonrySnapshot memory newSnapshot = MasonrySnapshot({
            time: block.number,
            rewardReceived: amount,
            rewardPerShare: nextRPS
        });
        masonryHistory.push(newSnapshot);

        seed.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardAdded(msg.sender, amount);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        // do not allow to drain core tokens
        require(address(_token) != address(seed), "seed");
        require(address(_token) != address(sshare), "sshare");
        _token.safeTransfer(_to, _amount);
    }
}