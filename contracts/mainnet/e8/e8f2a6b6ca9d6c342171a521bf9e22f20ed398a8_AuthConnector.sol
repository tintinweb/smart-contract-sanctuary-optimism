// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "../utils/BaseConnector.sol";

interface IAccount {
    function isAuth(address user) external view returns (bool);
    function enable(address user) external;
    function disable(address user) external;
}

interface IList {
    struct AccountLink {
        address first;
        address last;
        uint64 count;
    }

    function accountID(address) external view returns (uint64);
    function accountLink(uint64) external view returns (AccountLink memory);
}

contract AuthConnector is BaseConnector {
    string public constant name = "Auth-v1";
    IList public constant list = IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B);

    function enable(address _auth) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(_auth != address(0), "Not-valid-authority");

        IAccount account = IAccount(address(this));

        if (!account.isAuth(_auth)) {
            account.enable(_auth);
        } else {
            _auth = address(0x0);
        }

        _eventName = "LogEnable(address,address)";
        _eventParam = abi.encode(msg.sender, _auth);
    }

    function disable(address _auth) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(_auth != address(0), "Not-valid-authority");

        uint64 accountId = list.accountID(address(this));
        uint64 count = list.accountLink(accountId).count;
        require(count > 1, "Removing-all-authorities");

        IAccount account = IAccount(address(this));
        if (account.isAuth(_auth)) {
            account.disable(_auth);
        } else {
            _auth = address(0x0);
        }

        _eventName = "LogDisable(address,address)";
        _eventParam = abi.encode(msg.sender, _auth);
    }

    event LogEnable(address indexed _msgSender, address indexed _authority);
    event LogDisable(address indexed _msgSender, address indexed _authority);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IStorage {
    function getUint(uint256 id) external view returns (uint256 num);
    function setUint(uint256 id, uint256 val) external;
}

abstract contract BaseConnector {
    IStorage internal constant store = IStorage(0x9f4e24e48D1Cd41FA87A481Ae2242372Bd32618C);

    address internal constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address internal constant wethAddr = 0x4200000000000000000000000000000000000006;

    /**
     * @dev Get Uint value from FxStorage Contract.
     */
    function getUint(uint256 getId, uint256 val) internal view returns (uint256 returnVal) {
        returnVal = getId == 0 ? val : store.getUint(getId);
    }

    /**
     * @dev Set Uint value in FxStorage Contract.
     */
    function setUint(uint256 setId, uint256 val) internal virtual {
        if (setId != 0) store.setUint(setId, val);
    }
}