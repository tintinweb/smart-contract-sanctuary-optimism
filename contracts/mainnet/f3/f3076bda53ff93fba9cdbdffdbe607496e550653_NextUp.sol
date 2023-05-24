/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract NextUp {
	struct Application {
		uint256 id;
		string image;	
		string title;			
		string description;
		string[] links;
		uint256 totalVotes;
		address author;
		address[] voters;
	}

	uint256 public applicationCount;

	mapping(uint256 => Application) public applications;
	mapping (uint => mapping(address => bool)) public voted;

	event ApplicationCreated (
		uint256 id,
		string image,
		string title,
		string description,
		string[] links,
		address author
	);

	event ApplicationUpvoted (
		uint256 id,
		string image,
		string title,
		string description,
		uint256 totalVotes,
		address author,
		address voter
	);

	function uploadApplication(string calldata _imgUrl, string calldata _title, string calldata _description, string[] calldata _links)  public {
		require(msg.sender != address(0), "Invalid wallet address");
		applicationCount++;

		applications[applicationCount] = Application(
			applicationCount,
			_imgUrl,			
			_title,
			_description,
      		_links, 
			0,
			msg.sender,
			new address[](0)
		);

		emit ApplicationCreated(
			applicationCount, 
			_imgUrl, 
			_title,
			_description, 
      		_links,
			msg.sender
		);	
	}

	function upvoteApplication(uint256 _id) public {
		Application memory _application  = applications[_id];
		require(0 < _id && _id <= applicationCount, "Invalid ID");
		require(msg.sender != _application.author, "User cannot upvote themselves");
		require(voted[_id][msg.sender] == false, "You have already voted on this publication.");

		_application.totalVotes++;

		applications[_id] = _application;
		applications[_id].voters.push(msg.sender);

		// Mark voter as having voted on publication
        voted[_id][msg.sender] = true;

		emit ApplicationUpvoted(_id, 
			_application.image, 
			_application.title, 
			_application.description, 
			_application.totalVotes, 
			_application.author,
			msg.sender
		);
	} 

    function getVoterList(uint256 _id) public view returns(address[] memory) {
        return applications[_id].voters;
    } 

    function getLinkList(uint256 _id) public view returns(string[] memory) {
        return applications[_id].links;
    }     

// * receive function
    receive() external payable {}

    // * fallback function
    fallback() external payable {} 
}