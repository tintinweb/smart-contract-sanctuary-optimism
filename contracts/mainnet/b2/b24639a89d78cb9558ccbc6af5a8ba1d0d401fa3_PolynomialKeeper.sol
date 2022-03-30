/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-30
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface PolynomialVault {
    function sellOptions(uint256 _amt) external;
}

contract PolynomialKeeper {
    address public owner;
    mapping (address => bool) permitted;

    event TransferOwnership(address oldOwner, address newOwner);
    event Permit(address user);
    event Revoke(address user);
    event SellOptions(address indexed vault, uint256 amt);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyPermitted {
        require(msg.sender == owner || permitted[msg.sender]);
        _;
    }

    constructor() {
        owner = msg.sender;
        permitted[msg.sender] = true;

        emit TransferOwnership(address(0x0), msg.sender);
        emit Permit(msg.sender);
    }

    function permit(address _user) external onlyOwner {
        permitted[_user] = true;

        emit Permit(_user);
    }

    function revoke(address _user) external onlyOwner {
        permitted[_user] = false;

        emit Revoke(_user);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0x0));
        emit TransferOwnership(owner, _newOwner);
        owner = _newOwner;
    }

    function sellOptions(PolynomialVault _vault, uint256 _amt) external onlyPermitted {
        _vault.sellOptions(_amt);
        emit SellOptions(address(_vault), _amt);
    }
}