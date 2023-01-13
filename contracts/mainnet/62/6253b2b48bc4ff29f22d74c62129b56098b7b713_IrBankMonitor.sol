/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-13
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
    address IrBankStrategy;
    bool public stakePause;
    address public owner;
    mapping (address => uint256) public cashThreshold;
    constructor (address _owner, address _irbankStrategy)  {
        owner = _owner;
        IrBankStrategy = _irbankStrategy;

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



    function getPaused(address stakerReward) internal view returns (bool) {
        bool pause;
        pause = StakingRewardsInterface(stakerReward).paused();
        return pause;
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


    function popPToken() external {
        require(msg.sender == owner," only owner pop pToken");
            pTokens.pop();
    }



    function exitAll(address [] memory allVaults) external {
        bytes memory data;
        data = encodeExitAllInputs();   
        for (uint256 i=0; i<allVaults.length; i++) {
            IVaultInterface(allVaults[i]).execute(IrBankStrategy, data);
        }
    }


    function pauseOperate() view public returns (bool) {

        bool exit;

        for(uint256 i=0; i < pTokens.length; i++ ) {
            if (getCash(pTokens[i]) < cashThreshold[pTokens[i]]) {
                exit = true;
                return exit;
            }
        }

        return false;

    }
    

}