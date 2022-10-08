/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-08
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.16;

contract WeatherData {
    uint[] public weatherData;
    address public owner;
    event Update(uint[] dataArray);

    // owner can update weather data
    function updateData(uint temperature, uint humidity, uint luminosity, uint pressure) public {
        require(msg.sender == owner);
        weatherData = [temperature, humidity, luminosity, pressure];
        
        emit Update(weatherData);
    }
    
    // owner can withdraw
    function withdraw() public {
      require(msg.sender == owner);
      payable(msg.sender).transfer(address(this).balance);
    }
    
    // sets owner
    constructor() payable {
        owner = 0x06f4DB783097c632B888669032B2905F70e08105;
    }

    // to support receiving ETH by default
    receive() external payable {}
    fallback() external payable {}

    // owner can set new owner if needed
    function setOwner(address newOwner) external {
        require(msg.sender == owner);
        owner = newOwner;
    }
}