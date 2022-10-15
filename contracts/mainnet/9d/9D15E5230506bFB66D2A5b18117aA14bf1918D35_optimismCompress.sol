/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-14
*/

pragma solidity >= 0.8.13;

contract optimismCompress {

    function sendData(address addy, uint256 num1, uint256 num2) external {
        return;
    }

    fallback() external { 
        address addy;
        uint256 num1;
        uint256 num2;

        addy = address(bytes20(msg.data[:20]));

        num1 = uint256(bytes32(msg.data[20:23]));
        num1 = uint256(bytes32(msg.data[23:26]));
    }
}