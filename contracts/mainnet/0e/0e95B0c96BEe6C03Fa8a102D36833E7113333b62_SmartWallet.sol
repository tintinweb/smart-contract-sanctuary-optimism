// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../Libraries/Utils.sol";
import "../Interfaces/ISecureExecutor.sol";

contract SmartWallet {
	address public SECURE_EXECUTOR;

	constructor(address _SecureExecutor) {
		SECURE_EXECUTOR = _SecureExecutor;
	}

	function execute(Utils.Iparams memory params, bytes memory signature) external returns (bool, bytes memory) {
		require(address(this) == params.fromAddress, 'wrong "from" param');

		ISecureExecutor(SECURE_EXECUTOR).executeTransfer(params, signature);

		(bool success, bytes memory data) = params.toAddress.call{value: params.value}(params.data);
		require(success, "call failed");
		return (success, data);
	}

	event Received(address, uint256);

	receive() external payable {
		emit Received(msg.sender, msg.value);
	}
}

// SPDX-License-Identifier: AGPL-1.0

pragma solidity 0.8.9;

library Utils {
	struct Iparams {
		address tokenAddress;
		address fromAddress;
		address toAddress;
		uint256 value;
		uint256 amount;
		bytes data;
	}
}

// SPDX-License-Identifier: AGPL-1.0

pragma solidity 0.8.9;

import "../Libraries/Utils.sol";

interface ISecureExecutor {
	function executeTransfer(Utils.Iparams memory params, bytes memory signature) external;
}