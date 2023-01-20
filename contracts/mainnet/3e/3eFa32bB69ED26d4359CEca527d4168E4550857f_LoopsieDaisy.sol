/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-20
*/

contract Empty {}

contract LoopsieDaisy {
    function increment(uint256 n) external {
        for (uint256 i; i < n; i++) {
            new Empty{salt: bytes32(uint256(blockhash(block.number - 1)) + i)}();
        }
    }
}