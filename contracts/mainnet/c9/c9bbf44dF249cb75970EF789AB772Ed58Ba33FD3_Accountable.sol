//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/******************************************************************************
******************************************************************************
******************************************************************************
   _____                                   __        ___.   .__          
  /  _  \   ____  ____  ____  __ __  _____/  |______ \_ |__ |  |   ____  
 /  /_\  \_/ ___\/ ___\/  _ \|  |  \/    \   __\__  \ | __ \|  | _/ __ \ 
/    |    \  \__\  \__(  <_> )  |  /   |  \  |  / __ \| \_\ \  |_\  ___/ 
\____|__  /\___  >___  >____/|____/|___|  /__| (____  /___  /____/\___  >
        \/     \/    \/                 \/          \/    \/          \/ 
******************************************************************************
******************************************************************************
******************************************************************************/

import "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";

contract Accountable is ReentrancyGuard {
    // Enum representing status of a stake 
    // Pending = stake has been confirmed and is in progress
    // Success = stake has been completed successfully
    // Failure = stake was marked as failed
    // Unconfirmed = stake has been created by stakee but not yet confirmed by the accountability buddy. 
    //               This state is mainly to guard against entering incorrectly entering your accountability
    //               buddy's address, and lets you withdraw your money
    // Aborted = stake was aborted by the stakee and funds were sent back to the stakee before. Stake was never
    //           confirmed by accountability buddy. 
    enum Status {
        Pending, 
        Success,
        Failure,
        Unconfirmed,
        Aborted
    }

    //Khan Academy address according to https://www.khanacademy.org/donate (scroll to FAQ)
    address public constant KHAN_ACADEMY_ADDRESS = 0x95a647B3d8a3F11176BAdB799b9499C671fa243a;

    //represents a single stake made by a stakee 
    struct Stake {
        //person who is staking their money to the contract
        address stakee; 
        //person who is entrusted to make sure the stakee is held accountable.
        //@notice, this should be someone the stakee trusts, though there is no incentive
        //for the buddy to be dishonest since they can't take they money. The accounabilityBuddy is in charge
        //of confirming to the contract whether the stakee did what they agreed on doing.
        address accountabilityBuddy;
        Status status;
        string name;
        uint256 id;
        //@notice, amount of money staked in wei
        uint256 amountStaked;
        
    }
    Stake[] stakes;
    mapping (uint256 => Stake) public idToStakeStruct; 
    mapping (address => uint256[]) public stakeIDsForStakeeAddress;
    mapping (address => uint256[]) public stakeIDsForAccountabilityAddress;

    //@notice, when a new stake is created
    event NewStakeCreated(string name, uint id);
    //@notice, if a stake is successfully completed (i.e. the stakee accomplished
    //the agreed upon goal)
    event StakeSuccessful(string name, uint id);
    //@notice, if a stake is successfully unsuccessfully (i.e. the stakee did not accomplish 
    //the agreed upon goal), the money gets donated to Khan Academy
    event StakeFailed(string name, uint id);
    //@notice, marks when a stake is confirmed by the accountability buddy and the stakee can no longer withdraw
    //the money
    event StakeConfirmed(string name, uint id);
    //@notice if a stake is aborted and the stakee withdraws the money before the accountability buddy
    //confirms the stake
    event StakeAborted(string name, uint id);


    receive() external payable {}

    modifier validPendingStakeID(uint256 stakeID) {
        require(stakeID < stakes.length, "Invalid id provided");
        require(stakes[stakeID].status == Status.Pending, "Stake has not been confirmed yet or was already completed.");
        _;
    }
    modifier validUnconfirmedStakeID(uint256 stakeID) {
        require(stakeID < stakes.length, "Invalid id provided");
        require(stakes[stakeID].status == Status.Unconfirmed, "Stake has already been confirmed");
        _;
    }

    function getAllStakes() public view returns (Stake[] memory) {
        return stakes;
    }

    function getStakeFromID(uint256 stakeID) public view returns (Stake memory) {
        require(stakeID < stakes.length);
        return stakes[stakeID];
    }

    //gets all stakes for a given stakee address
    function getStakesForStakeeAddress() public view returns (Stake[] memory) {
        uint256[] storage ids = stakeIDsForStakeeAddress[msg.sender];
        Stake[] memory currStakes = new Stake[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            currStakes[i] = getStakeFromID(ids[i]);
        }
        return currStakes;
    }

    function getStakesForAccountabilityAddress() public view returns (Stake[] memory) {
        uint256[] storage ids = stakeIDsForAccountabilityAddress[msg.sender];
        Stake[] memory currStakes = new Stake[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            currStakes[i] = getStakeFromID(ids[i]);
        }
        return currStakes;
    }

    function createNewStake(string memory name, address accountabilityBuddy) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "Must stake non-zero amount of ether");
        require(accountabilityBuddy != msg.sender, "Must assign someone else as accountability buddy");
        
        Stake memory newStake = Stake({stakee: msg.sender, name: name, amountStaked: msg.value, accountabilityBuddy: accountabilityBuddy, id: stakes.length, status: Status.Unconfirmed});
        stakes.push(newStake);

        stakeIDsForStakeeAddress[msg.sender].push(stakes.length - 1);
        stakeIDsForAccountabilityAddress[accountabilityBuddy].push(stakes.length - 1);

        emit NewStakeCreated(name, stakes.length - 1);

        return stakes.length - 1;
    }

    function confirmStakeWithBuddy(uint256 stakeID) external validUnconfirmedStakeID(stakeID) nonReentrant {
        require(stakes[stakeID].accountabilityBuddy == msg.sender, "Only the accountability buddy can confirm a stake");
        
        stakes[stakeID].status = Status.Pending;

        emit StakeConfirmed(stakes[stakeID].name, stakeID);
    }

    function widthrawMoneyBeforeConfirmation(uint256 stakeID) external validUnconfirmedStakeID(stakeID) nonReentrant {
        require(stakes[stakeID].stakee == msg.sender, "Only the stakee can withdraw money before confirmation");

        //transfer funds to the stakee
        (bool success, ) = stakes[stakeID].stakee.call{value: stakes[stakeID].amountStaked }("");

        require(success, "Failed to send Ether to Stakee");
        stakes[stakeID].status = Status.Aborted;

        emit StakeAborted(stakes[stakeID].name, stakeID);
    }

    //@notice, upon successful completion of the agreed upon task/goal etc., the accountability buddy
    //marks the stake as successful for the money to be transferred back to the stakee.
    function markStakeSuccessful(uint256 stakeID) external validPendingStakeID(stakeID) nonReentrant {
        //ensure accountability buddy
        require(stakes[stakeID].accountabilityBuddy == msg.sender, "Only the accountability buddy can mark a stake as successful");

        //transfer funds to the stakee
        (bool success, ) = stakes[stakeID].stakee.call{value: stakes[stakeID].amountStaked }("");

        require(success, "Failed to send Ether to Stakee");
        stakes[stakeID].status = Status.Success;

        emit StakeSuccessful(stakes[stakeID].name, stakeID);
    }

    //@notice, if a stake is marked as failed, stakee's money gets donated directly to Khan Academy
    function markStakeFailed(uint256 stakeID) external validPendingStakeID(stakeID) nonReentrant {
        //ensure accountability buddy
        require(stakes[stakeID].accountabilityBuddy == msg.sender, "Only the accountability buddy can mark a stake as failed");

        //transfer funds to the stakee
        (bool success, ) = KHAN_ACADEMY_ADDRESS.call{value: stakes[stakeID].amountStaked}("");

        require(success, "Failed to send Ether to Accountability Buddy");
        stakes[stakeID].status = Status.Failure;

        emit StakeFailed(stakes[stakeID].name, stakeID);
    }

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private reentrancyStatus = 1;

    modifier nonReentrant() {
        require(reentrancyStatus == 1, "REENTRANCY");

        reentrancyStatus = 2;

        _;

        reentrancyStatus = 1;
    }
}