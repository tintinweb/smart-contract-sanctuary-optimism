// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITransferController {
    function canTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransferController} from "ITransferController.sol";

contract MultiFarmAllowedTransferController is ITransferController {
    address public immutable multiFarm;

    constructor(address _multiFarm) {
        multiFarm = _multiFarm;
    }

    function canTransfer(
        address from,
        address to,
        uint256
    ) public view returns (bool) {
        return to == multiFarm || from == multiFarm;
    }
}