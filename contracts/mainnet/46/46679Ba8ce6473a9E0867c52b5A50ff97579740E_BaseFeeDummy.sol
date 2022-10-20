/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-20
*/

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IBaseFee {
    function isCurrentBaseFeeAcceptable() external view returns (bool);
}

contract BaseFeeDummy {

    address public baseFeeOracle;
    address public governance;
    bool public manualBaseFeeBool;

    constructor(address _governance) public {
        manualBaseFeeBool = true;
        governance = _governance;
    }

    function isCurrentBaseFeeAcceptable() external view returns (bool) {
        if (baseFeeOracle == address(0)){
            return manualBaseFeeBool;
        } else {
            return IBaseFee(baseFeeOracle).isCurrentBaseFeeAcceptable();          
        }
    }

    function setManualBaseFeeBool(bool _manualBaseFeeBool) external {
        require(msg.sender == governance, "!gov");
        manualBaseFeeBool = _manualBaseFeeBool;
    }

    function setBaseFeeOracle(address _newBaseFeeOracle) external {
        require(msg.sender == governance, "!gov");
        baseFeeOracle = _newBaseFeeOracle;
    }

    function setGovernance(address _newGovernance) external {
        require(msg.sender == governance, "!gov");
        governance = _newGovernance;
    }
    
}