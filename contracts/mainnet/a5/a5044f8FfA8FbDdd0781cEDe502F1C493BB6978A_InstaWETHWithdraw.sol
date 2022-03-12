pragma solidity ^0.7.6;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint) external;
    function transfer(address, uint) external;
    function approve(address, uint256) external;
    function transferFrom(address, address, uint) external;
}

contract InstaWETHWithdraw {
    IWETH public weth = IWETH(0x4200000000000000000000000000000000000006);
    
    receive() external payable {}

    function withdraw(uint wad) public {
       weth.transferFrom(msg.sender, address(this), wad);
       weth.withdraw(wad);
       (bool status, ) = msg.sender.call{value: wad}("");
       require(status);
    }
}