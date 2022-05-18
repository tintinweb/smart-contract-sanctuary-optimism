/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-18
*/

// SPDX-License-Identifier: MIT

pragma solidity =0.8.10;





contract OptimismAuthAddresses {
    address internal constant ADMIN_ADDR = 0x98118fD1Da4b3369AEe87778168e97044980632F;
}





contract AuthHelper is OptimismAuthAddresses {
}





contract AdminVault is AuthHelper {
    address public owner;
    address public admin;

    error SenderNotAdmin();

    constructor() {
        owner = 0x322d58b9E75a6918f7e7849AEe0fF09369977e08;
        admin = ADMIN_ADDR;
    }

    /// @notice Admin is able to change owner
    /// @param _owner Address of new owner
    function changeOwner(address _owner) public {
        if (admin != msg.sender){
            revert SenderNotAdmin();
        }
        owner = _owner;
    }

    /// @notice Admin is able to set new admin
    /// @param _admin Address of multisig that becomes new admin
    function changeAdmin(address _admin) public {
        if (admin != msg.sender){
            revert SenderNotAdmin();
        }
        admin = _admin;
    }

}