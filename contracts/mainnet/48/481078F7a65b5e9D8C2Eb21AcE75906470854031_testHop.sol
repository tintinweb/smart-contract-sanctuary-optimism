// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;
interface IHop {
    function swapAndSend( uint256 chainId, address recipient, uint256 amount, 
        int256 bonderFee, uint256 amountOutMin, uint256 deadline, 
        uint256 destinationAmountOutMin, uint256 destinationDeadline
    ) external payable;
}
contract testHop {
    address constant public myAddress = 0x205f835f920c8bb9A2737139bDB951b371A9410d;
    function testCall(address _hopcontract) external payable {
        IHop(_hopcontract).swapAndSend{value: msg.value}(
            42161,
            myAddress,
            10000000000000000,
            282881533325123,
            9647505468058660,
            1647801119,
            9653171937149882,
            1647801119
        );
    }
}