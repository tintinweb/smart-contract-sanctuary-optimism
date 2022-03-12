/**
 *Submitted for verification at optimistic.etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: MIT

pragma solidity =0.8.10;





contract OptimismAuthAddresses {
    // address internal constant ADMIN_VAULT_ADDR = 0xCCf3d848e08b94478Ed8f46fFead3008faF581fD;
    address internal constant FACTORY_ADDRESS = 0xc19d0F1E2b38AA283E226Ca4044766A43aA7B02b;
    address internal constant ADMIN_ADDR = 0x322d58b9E75a6918f7e7849AEe0fF09369977e08; // temporarly only for testing
}





contract AuthHelper is OptimismAuthAddresses {
}





contract AdminVault is AuthHelper {
    address public owner;
    address public admin;

    error SenderNotAdmin();

    constructor() {
        owner = msg.sender;
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