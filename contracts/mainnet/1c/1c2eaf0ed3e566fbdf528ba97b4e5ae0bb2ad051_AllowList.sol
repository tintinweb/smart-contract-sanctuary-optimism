/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-25
*/

// Sources flattened with hardhat v2.9.6 https://hardhat.org

// File @rari-capital/solmate/src/auth/[email protected]

pragma solidity >=0.8.0;

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
    event OwnerUpdated(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnerUpdated(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

        // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
        // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));

        authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function setOwner(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool);
}


// File contracts/AllowList.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IERC721 {
    function balanceOf(address user) external view returns (uint256);
}

contract AllowList is Auth {
    mapping(address => bool) allowed;
    IERC721 public immutable cryptoTesters;

    constructor(IERC721 _cryptoTesters) Auth(msg.sender, Authority(address(0x0))) {
        cryptoTesters = _cryptoTesters;
    }

    function isAllowed(address user) external view returns (bool) {
        if (allowed[user]) {
            return true;
        }

        if (cryptoTesters.balanceOf(user) > 0) {
            return true;
        }

        return false;
    }

    function addAddresses(address[] memory users) external requiresAuth {
        for (uint256 i = 0; i < users.length; i++) {
            allowed[users[i]] = true;
        }
    }

    function removeAddresses(address[] memory users) external requiresAuth {
        for (uint256 i = 0; i < users.length; i++) {
            allowed[users[i]] = false;
        }
    }
}