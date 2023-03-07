pragma solidity ^0.8.13;
import "IVotingEscrow.sol";

contract BatchGet {
    address votingEs;

    constructor(address _votingEs) {
        votingEs = _votingEs;
    }

    function get_bal(uint256 from, uint256 len) external view returns (uint256[] memory bals) {
        IVotingEscrow ve = IVotingEscrow(votingEs);
        bals = new uint256[](len);
        for (uint256 i = from; i < from + len; i++){
            bals[i] = ve.balanceOfNFT(i);
        }
    }

    function get_owner(uint256 from, uint256 len) external view returns (address[] memory owners) {
        IVotingEscrow ve = IVotingEscrow(votingEs);
        owners = new address[](len);
        for (uint256 i = from; i < from + len; i++){
            owners[i] = ve.ownerOf(i);
        }
    }

}

pragma solidity ^0.8.13;

interface IVotingEscrow {

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function token() external view returns (address);
    function team() external returns (address);
    function epoch() external view returns (uint);
    function point_history(uint loc) external view returns (Point memory);
    function user_point_history(uint tokenId, uint loc) external view returns (Point memory);
    function user_point_epoch(uint tokenId) external view returns (uint);

    function ownerOf(uint) external view returns (address);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function transferFrom(address, address, uint) external;

    function voting(uint tokenId) external;
    function abstain(uint tokenId) external;
    function attach(uint tokenId) external;
    function detach(uint tokenId) external;

    function checkpoint() external;
    function deposit_for(uint tokenId, uint value) external;
    function create_lock_for(uint, uint, address) external returns (uint);

    function balanceOfNFT(uint) external view returns (uint);
    function totalSupply() external view returns (uint);
}