// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract ResolverTest {
    bool public executed = false;

    event GelatoCalled(address who);

    function execute() external {
        emit GelatoCalled(msg.sender);
    }

    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        return (
            !executed,
            abi.encodeWithSelector(ResolverTest.execute.selector)
        );
    }
}