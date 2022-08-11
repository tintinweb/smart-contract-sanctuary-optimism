// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ERC20Burnable.sol";
import "./Math.sol";

import "./SafeMath8.sol";
import "./Operator.sol";
import "./IOracle.sol";

/*
   _____ ________________  _____   ________
  / ___// ____/ ____/ __ \/  _/ | / / ____/
  \__ \/ __/ / __/ / / / // //  |/ / / __  
 ___/ / /___/ /___/ /_/ // // /|  / /_/ /  
/____/_____/_____/_____/___/_/ |_/\____/   
*/
contract Seed is ERC20Burnable, Operator {
    using SafeMath8 for uint8;
    using SafeMath for uint256;

    // Initial distribution for the first 72h genesis pools
    uint256 public constant INITIAL_GENESIS_POOL_DISTRIBUTION = 30000 ether;
    // Initial distribution for the day 2-5 SEED-OP LP -> SEED pool
    uint256 public constant INITIAL_SEED_POOL_DISTRIBUTION = 100000 ether;
    // Distribution for airdrops wallet
    uint256 public constant INITIAL_AIRDROP_WALLET_DISTRIBUTION = 15000 ether;

    // Have the rewards been distributed to the pools
    bool public rewardPoolDistributed = false;

    /**
     * @notice Constructs the SEED ERC-20 contract.
     */
    constructor() public ERC20("SEED", "SEED") {
        // Mints 1 SEED to contract creator for initial pool setup
        _mint(msg.sender, 1 ether);
    }

    /**
     * @notice Operator mints SEED to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of SEED to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(
        address _genesisPool,
        address _seedPool,
        address _airdropWallet
    ) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_genesisPool != address(0), "!_genesisPool");
        require(_seedPool != address(0), "!_seedPool");
        require(_airdropWallet != address(0), "!_airdropWallet");
        rewardPoolDistributed = true;
        _mint(_genesisPool, INITIAL_GENESIS_POOL_DISTRIBUTION);
        _mint(_seedPool, INITIAL_SEED_POOL_DISTRIBUTION);
        _mint(_airdropWallet, INITIAL_AIRDROP_WALLET_DISTRIBUTION);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}