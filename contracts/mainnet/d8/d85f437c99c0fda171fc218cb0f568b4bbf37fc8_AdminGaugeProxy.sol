/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-03-09
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != 0x0 && codehash != accountHash);
    }

    function toPayable(address account)
        internal
        pure
        returns (address payable)
    {
        return payable(address(uint160(account)));
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) - value;
        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

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
        return (a / 2) + (b / 2) + (((a % 2) + (b % 2)) / 2);
    }
}

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
}

interface IGaugeProxy {
    function getTreasury() external view returns (address);

    function getDepositFeeRate() external view returns (uint256);
}

interface IBaseV1Pair {
    function claimFees() external returns (uint, uint);
    function tokens() external returns (address, address);
    function stable() external returns (bool);
    function brbMaker() external returns (address);
    function protocol() external returns (address);
}

contract Gauge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public BRB;
    IERC20 public inBRB;

    IERC20 public immutable TOKEN;
    address public immutable DISTRIBUTION;
    uint256 public constant DURATION = 7 days;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    modifier onlyDistribution() {
        require(
            msg.sender == DISTRIBUTION,
            "Caller is not RewardsDistribution contract"
        );
        _;
    }

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    uint256 public derivedSupply;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public derivedBalances;
    mapping(address => uint256) private _base;

    constructor(
        address _brb,
        address _inBrb,
        address _token
    ) public {
        BRB = IERC20(_brb);
        inBRB = IERC20(_inBrb);
        TOKEN = IERC20(_token);
        DISTRIBUTION = msg.sender;
    }

    function claimVotingFees() external nonReentrant returns (uint claimed0, uint claimed1) {
        // require address(TOKEN) is BaseV1Pair
        return _claimVotingFees();
    }

    function _claimVotingFees() internal returns (uint claimed0, uint claimed1) {
        (claimed0, claimed1) = IBaseV1Pair(address(TOKEN)).claimFees();
        if (claimed0 > 0 || claimed1 > 0) {
            (address _token0, address _token1) = IBaseV1Pair(address(TOKEN)).tokens();
            address brbMaker = IBaseV1Pair(address(TOKEN)).brbMaker();
            address protocolAddress = IBaseV1Pair(address(TOKEN)).protocol();
            if (claimed0 > 0) {
                IERC20(_token0).safeTransfer(brbMaker, claimed0 / 2);
                IERC20(_token0).safeTransfer(protocolAddress, claimed0 / 2);
            }
            if (claimed1 > 0) {
                IERC20(_token1).safeTransfer(brbMaker, claimed1 / 2);
                IERC20(_token1).safeTransfer(protocolAddress, claimed1 / 2);
            }
            emit ClaimVotingFees(msg.sender, claimed0, claimed1);
        }
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (derivedSupply == 0) {
            return 0;
        }

        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / derivedSupply;
    }

    function derivedBalance(address account) public view returns (uint256) {
        if (inBRB.totalSupply() == 0) return 0;
        uint256 _balance = _balances[account];
        uint256 _derived = _balance * 40 / 100;
        uint256 _adjusted = (_totalSupply * inBRB.balanceOf(account) / inBRB.totalSupply()) * 60 / 100;
        return Math.min(_derived + _adjusted, _balance);
    }

    function kick(address account) public {
        uint256 _derivedBalance = derivedBalances[account];
        derivedSupply = derivedSupply - _derivedBalance;
        _derivedBalance = derivedBalance(account);
        derivedBalances[account] = _derivedBalance;
        derivedSupply = derivedSupply + _derivedBalance;
    }

    function earned(address account) public view returns (uint256) {
        return (derivedBalances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * DURATION;
    }

    function depositAll() external {
        _deposit(TOKEN.balanceOf(msg.sender), msg.sender);
    }

    function deposit(uint256 amount) external {
        _deposit(amount, msg.sender);
    }

    function depositFor(uint256 amount, address account) external {
        _deposit(amount, account);
    }

    function _deposit(uint256 amount, address account)
        internal
        nonReentrant
        updateReward(account)
    {
        IGaugeProxy guageProxy = IGaugeProxy(DISTRIBUTION);
        address treasury = guageProxy.getTreasury();
        uint256 depositFeeRate = guageProxy.getDepositFeeRate();

        require(
            treasury != address(0x0),
            "deposit(Gauge): treasury haven't been set"
        );
        require(amount > 0, "deposit(Gauge): cannot stake 0");

        uint256 feeAmount = amount * depositFeeRate / 10000;
        uint256 userAmount = amount - feeAmount;

        _balances[account] = _balances[account] + userAmount;
        _totalSupply = _totalSupply + userAmount;

        TOKEN.safeTransferFrom(account, address(this), amount);
        TOKEN.safeTransfer(treasury, feeAmount);

        emit Staked(account, userAmount);
    }

    function withdrawAll() external {
        _withdraw(_balances[msg.sender]);
    }

    function withdraw(uint256 amount) external {
        _withdraw(amount);
    }

    function _withdraw(uint256 amount)
        internal
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        TOKEN.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            BRB.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward)
        external
        onlyDistribution
        updateReward(address(0))
    {
        BRB.safeTransferFrom(DISTRIBUTION, address(this), reward);
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / DURATION;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / DURATION;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = BRB.balanceOf(address(this));
        require(
            rewardRate <= balance / DURATION,
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + DURATION;
        emit RewardAdded(reward);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
        if (account != address(0)) {
            kick(account);
        }
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event ClaimVotingFees(address indexed from, uint256 claimed0, uint256 claimed1);
}

//
//^0.7.5;
interface MasterChef {
    function deposit(uint256, uint256) external;

    function withdraw(uint256, uint256) external;

    function userInfo(uint256, address)
        external
        view
        returns (uint256, uint256);
}

contract ProtocolGovernance {
    /// @notice governance address for the governance contract
    address public governance;
    address public pendingGovernance;

    /**
     * @notice Allows governance to change governance (for future upgradability)
     * @param _governance new governance address to set
     */
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "setGovernance: !gov");
        pendingGovernance = _governance;
    }

    /**
     * @notice Allows pendingGovernance to accept their role as governance (protection pattern)
     */
    function acceptGovernance() external {
        require(
            msg.sender == pendingGovernance,
            "acceptGovernance: !pendingGov"
        );
        governance = pendingGovernance;
    }
}

contract MasterBarbarian {

    /// @notice EIP-20 token name for this token
    string public constant name = "Master inBRB";

    /// @notice EIP-20 token symbol for this token
    string public constant symbol = "minBRB";

    /// @notice EIP-20 token decimals for this token
    uint8 public constant decimals = 18;

    /// @notice Total number of tokens in circulation
    uint256 public totalSupply = 1e18;

    mapping(address => mapping(address => uint256)) internal allowances;
    mapping(address => uint256) internal balances;

    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice The standard EIP-20 approval event
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    constructor() public {
        balances[msg.sender] = 1e18;
        emit Transfer(address(0x0), msg.sender, 1e18);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender)
        external
        view
        returns (uint256)
    {
        return allowances[account][spender];
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint256 amount) external returns (bool) {
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool) {
        address spender = msg.sender;
        uint256 spenderAllowance = allowances[src][spender];

        if (spender != src && spenderAllowance != type(uint256).max) {
            uint256 newAllowance = spenderAllowance - amount;
            allowances[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    function _transferTokens(
        address src,
        address dst,
        uint256 amount
    ) internal {
        require(src != address(0), "_transferTokens: zero address");
        require(dst != address(0), "_transferTokens: zero address");

        balances[src] = balances[src] - amount;
        balances[dst] = balances[dst] + amount;
        emit Transfer(src, dst, amount);
    }
}

contract AdminGaugeProxy is ProtocolGovernance {
    using SafeERC20 for IERC20;

    MasterChef public MASTER;
    IERC20 public inBRB;
    IERC20 public BRB;
    IERC20 public immutable TOKEN; // mInBrb

    uint256 public pid = type(uint256).max; // -1 means 0xFFF....F and hasn't been set yet
    uint256 public depositFeeRate = 0; // EX: 3000 = 30% : MAXIMUM-2000

    // VE bool
    bool public ve = false;
    address public feeDistAddr; // fee distributor address

    address[] internal _tokens;
    address public treasury;
    address public admin; //Admin address to manage gauges like add/deprecate/resurrect
    uint256 public totalWeight; // total weight of gauges
    mapping(address => address) public gauges; // token => gauge
    mapping(address => uint256) public gaugeWeights; // token => weight

    constructor(
        address _masterChef,
        address _brb,
        address _inBrb,
        address _treasury,
        address _feeDist,
        uint256 _depositFeeRate
    ) public {
        MASTER = MasterChef(_masterChef);
        BRB = IERC20(_brb);
        inBRB = IERC20(_inBrb);
        TOKEN = IERC20(address(new MasterBarbarian()));
        governance = msg.sender;
        admin = msg.sender;
        treasury = _treasury;
        depositFeeRate = _depositFeeRate;
        feeDistAddr = _feeDist;
    }

    function tokens() external view returns (address[] memory) {
        return _tokens;
    }

    function getGauge(address _token) external view returns (address) {
        return gauges[_token];
    }

    function setAdmin(address _admin) external {
        require(msg.sender == governance, "!gov");
        admin = _admin;
    }

    // Add new token gauge
    function addGauge(address _token) external returns (address) {
        require(
            (msg.sender == governance || msg.sender == admin),
            "!gov or !admin"
        );
        require(
            treasury != address(0x0),
            "addGauge: treaury should be set before every action"
        );
        require(gauges[_token] == address(0x0), "exists");
        gauges[_token] = address(
            new Gauge(address(BRB), address(inBRB), _token)
        );
        gaugeWeights[_token] = 0;
        _tokens.push(_token);
        return gauges[_token];
    }

    // Set Gauge Weight for Token
    function setGaugeWeight(address _token, uint256 _weight) external {
        require(msg.sender == governance || msg.sender == admin);
        require(gauges[_token] != address(0x0), "!exists");
        totalWeight = totalWeight - gaugeWeights[_token] + _weight;
        gaugeWeights[_token] = _weight;
    }

    // Sets MasterChef PID
    function setPID(uint256 _pid) external {
        require(msg.sender == governance, "!gov");
        pid = _pid;
    }

    // Deposits minBRB into MasterChef
    function deposit() public {
        require(pid != type(uint256).max, "pid not initialized");
        IERC20 _token = TOKEN;
        uint256 _balance = _token.balanceOf(address(this));
        _token.safeApprove(address(MASTER), 0);
        _token.safeApprove(address(MASTER), _balance);

        MASTER.deposit(pid, _balance);
    }

    // Fetches Brb
    function collect() public {
        (uint256 _locked, ) = MASTER.userInfo(pid, address(this));
        MASTER.withdraw(pid, _locked);
        deposit();
    }

    function length() external view returns (uint256) {
        return _tokens.length;
    }

    // In this GaugeProxy the distribution will be equal amongst active gauges, irrespective of votes
    function distribute() external {
        collect();
        uint256 _balance = BRB.balanceOf(address(this));
        uint256 _inBrbRewards = 0;
        if (ve) {
            uint256 _lockedBrb = BRB.balanceOf(address(inBRB));
            uint256 _brbSupply = BRB.totalSupply();
            _inBrbRewards = _balance * _lockedBrb / _brbSupply;

            if (_inBrbRewards > 0) {
                BRB.safeTransfer(feeDistAddr, _inBrbRewards);
                _balance = _balance - _inBrbRewards;
            }
        }
        if (_balance > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                if (gaugeWeights[_tokens[i]] > 0) {
                    uint256 _reward = _balance * gaugeWeights[_tokens[i]] / totalWeight;
                    address _token = _tokens[i];
                    address _gauge = gauges[_token];
                    if (_reward > 0) {
                        BRB.safeApprove(_gauge, 0);
                        BRB.safeApprove(_gauge, _reward);
                        Gauge(_gauge).notifyRewardAmount(_reward);
                    }
                }
            }
        }
        emit Distributed(_inBrbRewards);
    }

    function toggleVE() external {
        require(
            (msg.sender == governance || msg.sender == admin),
            "turnVeOn: permission is denied!"
        );
        ve = !ve;
    }

    function getDepositFeeRate() external view returns (uint256) {
        return depositFeeRate;
    }

    function updateDepositFeeRate(uint256 _depositFeeRate) external {
        require(
            msg.sender == governance,
            "updateDepositFeeRate: permission is denied!"
        );
        require(
            _depositFeeRate <= 2000,
            "updateDepositFeeRate: cannot execeed the 20%!"
        );
        depositFeeRate = _depositFeeRate;
    }

    function getTreasury() external view returns (address) {
        return treasury;
    }

    // Update fee distributor address
    function updateFeeDistributor(address _feeDistAddr) external {
        require(
            (msg.sender == governance || msg.sender == admin),
            "updateFeeDestributor: permission is denied!"
        );
        feeDistAddr = _feeDistAddr;
    }

    function updateTreasury(address _treasury) external {
        require(
            msg.sender == governance,
            "updateTreasury: permission is denied!"
        );
        treasury = _treasury;
    }

    event Distributed(uint256 brbRewards);
}