pragma solidity >=0.8.11;

contract DefiDubai {
    string private meetupLocationUrl;
    address payable public owner;

    constructor() payable {
        owner = payable(msg.sender);
    }

    function setMeetupUrl(string memory url) public {
        require(msg.sender == owner, "only owner");
        meetupLocationUrl = url;
    }

    function whereNextMeetupSir() public view returns (string memory) {
        return meetupLocationUrl;
    }

    function setOwner(address newOwner) public payable {
        require(msg.sender == owner, "only owner");
        owner = payable(newOwner);
    }
}