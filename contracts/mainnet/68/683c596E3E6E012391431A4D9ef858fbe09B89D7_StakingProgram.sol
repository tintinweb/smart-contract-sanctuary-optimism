/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-10
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.0;

contract Ownable {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender == owner)
            _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) owner = newOwner;
    }
}

contract SafeMath {
    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract StakingProgram is Ownable, SafeMath {
    ERC20token public erc20tokenInstance;
    uint256 public stakingFee; // percentage
    uint256 public unstakingFee; // percentage
    uint256 public round = 1;
    uint256 public totalStakes = 0;
    uint256 public totalDividends = 0;
    uint256 constant private scaling = 10 ** 10;
    bool public stakingStopped = false;
    address public acceleratorAddress = address(0);

    struct Staker {
        uint256 stakedTokens;
        uint256 round;
        uint256 remainder;
    }

    mapping(address => Staker) public stakers;
    mapping(uint256 => uint256) public payouts;

    constructor(address _erc20token_address, uint256 _stakingFee, uint256 _unstakingFee) public {
        erc20tokenInstance = ERC20token(_erc20token_address);
        stakingFee = _stakingFee;
        unstakingFee = _unstakingFee;
    }

    // ==================================== EVENTS ====================================
    event staked(address indexed staker, uint256 tokens, uint256 fee);
    event unstaked(address indexed staker, uint256 tokens, uint256 fee);
    event payout(uint256 round, uint256 tokens, address indexed sender);
    event claimedReward(address indexed staker, uint256 reward);
    // ==================================== /EVENTS ====================================

    // ==================================== MODIFIERS ====================================
    modifier onlyAccelerator() {
        require(msg.sender == address(acceleratorAddress));
        _;
    }

    modifier checkIfStakingStopped() {
        require(!stakingStopped, "Staking is stopped.");
        _;
    }
    // ==================================== /MODIFIERS ====================================

    // ==================================== CONTRACT ADMIN ====================================
    function stopUnstopStaking() external onlyOwner {
        if (!stakingStopped) {
            stakingStopped = true;
        } else {
            stakingStopped = false;
        }
    }

    function setFees(uint256 _stakingFee, uint256 _unstakingFee) external onlyOwner {
        require(_stakingFee <= 10 && _unstakingFee <= 10, "Invalid fees.");

        stakingFee = _stakingFee;
        unstakingFee = _unstakingFee;
    }

    function setAcceleratorAddress(address _address) external onlyOwner {
        acceleratorAddress = address(_address);
    }
    // ==================================== /CONTRACT ADMIN ====================================

    // ==================================== CONTRACT BODY ====================================
    function stake(uint256 _tokens_amount) external checkIfStakingStopped {
        require(_tokens_amount > 0, "Invalid token amount.");
        require(erc20tokenInstance.transferFrom(msg.sender, address(this), _tokens_amount), "Tokens cannot be transferred from sender.");

        uint256 _fee = 0;
        if (totalStakes  > 0) {
            // calculating this user staking fee based on the tokens amount that user want to stake
            _fee = div(mul(_tokens_amount, stakingFee), 100);
            _addPayout(_fee);
        }

        // if staking not for first time this means that there are already existing rewards
        uint256 existingRewards = getPendingReward(msg.sender);
        if (existingRewards > 0) {
            stakers[msg.sender].remainder = add(stakers[msg.sender].remainder, existingRewards);
        }

        // saving user staked tokens minus the staking fee
        stakers[msg.sender].stakedTokens = add(sub(_tokens_amount, _fee), stakers[msg.sender].stakedTokens);
        stakers[msg.sender].round = round;

        // adding this user stake to the totalStakes
        totalStakes = add(totalStakes, sub(_tokens_amount, _fee));

        emit staked(msg.sender, sub(_tokens_amount, _fee), _fee);
    }

    function acceleratorStake(uint256 _tokens_amount, address _staker) external checkIfStakingStopped onlyAccelerator {
        require(acceleratorAddress != address(0), "Invalid address.");
        require(_tokens_amount > 0, "Invalid token amount.");
        require(erc20tokenInstance.transferFrom(msg.sender, address(this), _tokens_amount), "Tokens cannot be transferred from sender.");

        uint256 _fee = 0;
        if (totalStakes  > 0) {
            // calculating this user staking fee based on the tokens amount that user want to stake
            _fee = div(mul(_tokens_amount, stakingFee), 100);
            _addPayout(_fee);
        }

        // if staking not for first time this means that there are already existing rewards
        uint256 existingRewards = getPendingReward(_staker);
        if (existingRewards > 0) {
            stakers[_staker].remainder = add(stakers[_staker].remainder, existingRewards);
        }

        // saving user staked tokens minus the staking fee
        stakers[_staker].stakedTokens = add(sub(_tokens_amount, _fee), stakers[_staker].stakedTokens);
        stakers[_staker].round = round;

        // adding this user stake to the totalStakes
        totalStakes = add(totalStakes, sub(_tokens_amount, _fee));

        emit staked(_staker, sub(_tokens_amount, _fee), _fee);
    }

    function claimReward() external {
        uint256 pendingReward = getPendingReward(msg.sender);
        if (pendingReward > 0) {
            stakers[msg.sender].remainder = 0;
            stakers[msg.sender].round = round; // update the round

            require(erc20tokenInstance.transfer(msg.sender, pendingReward), "ERROR: error in sending reward from contract to sender.");

            emit claimedReward(msg.sender, pendingReward);
        }
    }

    function unstake(uint256 _tokens_amount) external {
        require(_tokens_amount > 0 && stakers[msg.sender].stakedTokens >= _tokens_amount, "Invalid token amount to unstake.");

        stakers[msg.sender].stakedTokens = sub(stakers[msg.sender].stakedTokens, _tokens_amount);
        stakers[msg.sender].round = round;

        // calculating this user unstaking fee based on the tokens amount that user want to unstake
        uint256 _fee = div(mul(_tokens_amount, unstakingFee), 100);

        // sending to user desired token amount minus his unstacking fee
        require(erc20tokenInstance.transfer(msg.sender, sub(_tokens_amount, _fee)), "Error in unstaking tokens.");

        totalStakes = sub(totalStakes, _tokens_amount);
        if (totalStakes > 0) {
            _addPayout(_fee);
        }

        emit unstaked(msg.sender, sub(_tokens_amount, _fee), _fee);
    }

    function addRewards(uint256 _tokens_amount) external checkIfStakingStopped {
        require(erc20tokenInstance.transferFrom(msg.sender, address(this), _tokens_amount), "Tokens cannot be transferred from sender.");
        _addPayout(_tokens_amount);
    }

    function _addPayout(uint256 _fee) private {
        uint256 dividendPerToken = div(mul(_fee, scaling), totalStakes);
        totalDividends = add(totalDividends, dividendPerToken);
        payouts[round] = add(payouts[round-1], dividendPerToken);
        round+=1;

        emit payout(round, _fee, msg.sender);
    }

    function getPendingReward(address _staker) public view returns(uint256) {
        uint256 amount = mul((sub(totalDividends, payouts[stakers[_staker].round - 1])), stakers[_staker].stakedTokens);
        return add(div(amount, scaling), stakers[_staker].remainder);
    }
    // ===================================== CONTRACT BODY =====================================
}

interface ERC20token {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
}

// MN bby ¯\_(ツ)_/¯