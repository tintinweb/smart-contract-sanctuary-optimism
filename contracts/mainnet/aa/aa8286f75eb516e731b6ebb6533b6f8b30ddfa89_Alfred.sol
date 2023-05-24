/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-14
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Alfred {
    
    string[] public brainOfAlfred = [
        "Why did the tomato turn red? Because it saw the salad dressing!",
        "Why do we tell actors to 'break a leg?' Because every play has a cast!",
        "What do you call a fake noodle? An impasta!",
        "Why was the math book sad? Because it had too many problems!",
        "What do you call a boomerang that doesn't come back? A stick!",
        "Why did the coffee file a police report? It got mugged!",
        "Why did the chicken cross the playground? To get to the other slide!",
        "What do you get when you cross a snowman and a shark? Frostbite!",
        "What do you call a sleeping bull? A bulldozer!",
        "Why don't scientists trust atoms? Because they make up everything!",
        "Why don't eggs tell jokes? Because they'd crack each other up!",
        "Why did the scarecrow win an award? Because he was outstanding in his field!",
        "Why was the computer cold? Because it left its Windows open!",
        "What's the best way to watch a fly fishing tournament? Live stream!",
        "What do you call an alligator in a vest? An investigator!",
        "Why was the belt sent to jail? For holding up pants!"
    ];
    

    function askAlfred(string memory question) public view returns (string memory) {
        uint256 index = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, question))) % brainOfAlfred.length;
        return string(abi.encodePacked("Hmm, I don't have an answer for that but here is a joke, ", brainOfAlfred[index]));
    }

    function sayHelloToAlfred() public returns (string memory) {
        string memory message = string(abi.encodePacked(msg.sender, " said hello to Alfred!!"));
        emit HelloAlfred(message);
        return "Hello there! I'm Alfred, your friendly AI assistant for the deep dark decentralized web.";
    }


    event HelloAlfred(string message);
    
}