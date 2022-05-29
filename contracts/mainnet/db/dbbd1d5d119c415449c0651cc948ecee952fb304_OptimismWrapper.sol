/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-28
*/

pragma solidity ^0.8.14;

interface SnxBridge {
    function withdrawTo(address _to, uint256 _amount) external;
}

contract OptimismWrapper {
    function withdrawTo(
        address _l2Token,
        address _to,
        uint256 _amount,
        uint256 _l1Gas,
        bytes memory _data
    ) public {
        SnxBridge(0x136b1EC699c62b0606854056f02dC7Bb80482d63).withdrawTo(_to, _amount);
    }
}