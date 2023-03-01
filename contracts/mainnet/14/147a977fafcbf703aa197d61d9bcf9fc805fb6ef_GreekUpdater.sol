/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-20
*/

pragma solidity =0.8.9;

interface IGreekCache {

    function updateBoardCachedGreeks(uint256 boardId) external;
}

contract GreekUpdater {


    function updateBoardsETH (address _optionsGreekCache, uint256[] calldata boardIds) external {
        IGreekCache optionsGreekCache = IGreekCache(_optionsGreekCache);
        uint256 length = boardIds.length;
        for( uint256 i = 0; i < length; i++){
            optionsGreekCache.updateBoardCachedGreeks(boardIds[i]);
        }
        
    }
}