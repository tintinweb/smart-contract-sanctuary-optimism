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

contract BlockedTransferController is ITransferController {
    function canTransfer(
        address,
        address,
        uint256
    ) public pure returns (bool) {
        return false;
    }
}