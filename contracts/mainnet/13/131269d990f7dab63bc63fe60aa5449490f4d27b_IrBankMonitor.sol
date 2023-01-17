/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-17
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom( address sender, address recipient,uint256 amount ) external returns (bool);
}

interface CTokenInterface {

    function getCash() external view returns (uint256);
    function decimals() external view returns (uint8);
    function underlying() external view returns (address);

}

interface StakingRewardsInterface {

    function paused() external view returns (bool);

}




interface StakingRewardsHelperInterface {

    struct UserStaked {
        address stakingTokenAddress;
        uint256 balance;
    }
    function getUserStaked(address account) external view returns (UserStaked[] memory);

}




interface IVaultInterface {
     function execute(address, bytes memory)
        external
        payable
        returns (bytes memory);
}


contract IrBankMonitor  {
    address [] public vaults;
    address [] public pTokens;
    address [] public stakeRewards;
    address public irBankStrategy;
    address public stakeRewardsHelper;
    address public owner;
    bool public flag;
    mapping (address => uint256) public cashThreshold;
    mapping(address => bool) public whitelisted;



    constructor (address _owner, address _irbankStrategy, address _stakeRewardsHelper)  {
        owner = _owner;
        irBankStrategy = _irbankStrategy;
        stakeRewardsHelper =_stakeRewardsHelper;

    }

    modifier onlyWhitelisted() {
        require(
            whitelisted[msg.sender] || msg.sender == owner,
            "exit all: Not whitelisted"
        );
        _;
    }


    function getUnderlying(address pToken) external view returns (address) {
        address underlying;
        underlying = CTokenInterface(pToken).underlying();
        return underlying;
    }


    function getDecimals(address token) external view returns (uint8) {
        uint8 decimals;
        decimals = IERC20(token).decimals();
        return decimals;
    }

    function getCash(address pToken) internal view returns (uint256) {
        uint256 cash;
        cash = CTokenInterface(pToken).getCash();
        return cash;
    }



    function getPaused(address [] memory stakerRewards) internal view returns (bool) {
        bool pause;
        for(uint256 i=0; i<stakerRewards.length; i++ ){      
            pause = StakingRewardsInterface(stakerRewards[i]).paused();
            if (pause == true) {
                return true;
            }
        }
        return false;
    }


    function getPaused2(address [] memory stakerRewards) external view returns (bool) {
        bool pause;
        for(uint256 i=0; i<stakerRewards.length; i++ ){      
            pause = StakingRewardsInterface(stakerRewards[i]).paused();
            if (pause == true) {
                return true;
            }
        }
        return false;
    }




    function getUserStakedAmount(address account) external view returns (StakingRewardsHelperInterface.UserStaked [] memory) {
        StakingRewardsHelperInterface.UserStaked [] memory userStakes = StakingRewardsHelperInterface(stakeRewardsHelper).getUserStaked(account);
        return userStakes;
    }





    function encodeExitAllInputs() internal  pure returns (bytes memory encodedInput) {
        return abi.encodeWithSignature("exitAll()");
    }



    function encodeExitAllInputs2() external  pure returns (bytes memory encodedInput) {
        return abi.encodeWithSignature("exitAll()");
    }




    function setCashThreshold(address pToken, uint256 cashCap)
        external
    {
        require(msg.sender == owner, "only owner set cashCap");
        cashThreshold[pToken] = cashCap;
    }


    function setPTokens (address [] memory ptokens) external {
        require(msg.sender == owner," only owner set pTokens");
        for(uint i=0;i<ptokens.length;i++){
            pTokens.push(ptokens[i]);
        }
    }

    function setVaults (address [] memory _vaults) external {
        require(msg.sender == owner," only owner set vaults");
        for(uint i=0;i<_vaults.length;i++){
            vaults.push(_vaults[i]);
        }
    }


    function setFlag (bool _flag) external {
        require(msg.sender == owner," only owner set flag");
        flag = _flag;

    }

    function setStakeRewards(address [] memory _stakeRewards) external {
        require(msg.sender == owner," only owner set setStakeRewaards");
        stakeRewards = _stakeRewards;

    }


    function popStakeRewaards(address [] memory _stakeRewaards) external {
        require(msg.sender == owner," only owner set setStakeRewaards");
        stakeRewards = _stakeRewaards;

    }




    function setWhitelist(address _account, bool _whitelist)
        external
    {
        require(msg.sender == owner," only owner set whiteliste");
        whitelisted[_account] = _whitelist;
    }




    function popPToken() external {
        require(msg.sender == owner," only owner pop pToken");
            pTokens.pop();
    }

    function popStakeRewaards() external {
        require(msg.sender == owner," only owner set setStakeRewaards");
        stakeRewards.pop();

    }



    function exitAll(address [] memory allVaults) external onlyWhitelisted {
        bytes memory data;
        data = encodeExitAllInputs();   
        for (uint256 i=0; i<allVaults.length; i++) {
            IVaultInterface(allVaults[i]).execute(irBankStrategy, data);
        }
        flag = true;
    }

    function pauseOperate() view public returns (bool) {
        bool exit;
        if (flag == true) {
            return false;
        } else {
            for(uint256 i=0; i < pTokens.length; i++ ) {                   
                if (getCash(pTokens[i]) < cashThreshold[pTokens[i]] || getPaused(stakeRewards) == true) {
                    exit = true;
                    return exit;
                }
            }
        return false;

        }
        
    }


    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        bool _operate;
        _operate = pauseOperate();
        if (_operate == true) {

            canExec = true;

        } else {

            canExec = false;


        }

        execPayload = abi.encodeCall(this.exitAll, (vaults));
    }

}