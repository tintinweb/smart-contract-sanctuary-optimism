/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-30
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IERC20 {
	function totalSupply() external view returns (uint);
	function balanceOf(address account) external view returns (uint);
	function transfer(address recipient, uint amount) external returns (bool);
	function allowance(address owner, address spender) external view returns (uint);
	function approve(address spender, uint amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint amount) external returns (bool);
	event Transfer(address indexed from, address indexed to, uint value);
	event Approval(address indexed owner, address indexed spender, uint value);
}

interface IUniswapV2Router {
  function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);
  function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function swap(uint256 amount0Out,	uint256 amount1Out,	address to,	bytes calldata data) external;
}

contract Arb {
	address payable owner;
	
	event Log(string message, uint256 value);
	event Swap(address router, address tokenIn, address tokenOut, uint256 amount);
	event DualTrade(address router1, address router2, address token1, address token2, uint256 amount, uint256 profit);

	constructor() {
        owner = payable(msg.sender);
    }

	function swap(address router, address _tokenIn, address _tokenOut, uint256 _amount) private {
		IERC20(_tokenIn).approve(router, _amount);
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint deadline = block.timestamp + 300;
		IUniswapV2Router(router).swapExactTokensForTokens(_amount, 1, path, address(this), deadline);
		emit Swap(router, _tokenIn, _tokenOut, _amount);
	}

	function getAmountOutMin(address router, address _tokenIn, address _tokenOut, uint256 _amount) public view returns (uint256) {
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint256[] memory amountOutMins = IUniswapV2Router(router).getAmountsOut(_amount, path);
		return amountOutMins[path.length -1];
	}

  	function estimateDualDexTrade(address _router1, address _router2, address _token1, address _token2, uint256 _amount) external view returns (uint256) {
		uint256 amtBack1 = getAmountOutMin(_router1, _token1, _token2, _amount);
		uint256 amtBack2 = getAmountOutMin(_router2, _token2, _token1, amtBack1);
		return amtBack2;
	}
	
  	function dualDexTrade(address _router1, address _router2, address _token1, address _token2, uint256 _amount) external onlyOwner {
		uint startBalance = IERC20(_token1).balanceOf(address(this));
		uint token2InitialBalance = IERC20(_token2).balanceOf(address(this));
		swap(_router1,_token1, _token2,_amount);
		uint token2Balance = IERC20(_token2).balanceOf(address(this));
		uint tradeableAmount = token2Balance - token2InitialBalance;
		swap(_router2,_token2, _token1,tradeableAmount);
		uint endBalance = IERC20(_token1).balanceOf(address(this));
		require(endBalance > startBalance, "Trade Reverted, No Profit Made");
		emit DualTrade(_router1, _router2, _token1, _token2, _amount, (endBalance-startBalance));
  	}

	function estimateTriDexTrade(address _router1, address _router2, address _router3, address _token1, address _token2, address _token3, uint256 _amount) external view returns (uint256) {
		uint amtBack1 = getAmountOutMin(_router1, _token1, _token2, _amount);
		uint amtBack2 = getAmountOutMin(_router2, _token2, _token3, amtBack1);
		uint amtBack3 = getAmountOutMin(_router3, _token3, _token1, amtBack2);
		return amtBack3;
	}

	function ethBalance() public view returns (uint256) {
      return address(this).balance;
    }

    function getBalance(address _tokenAddress) public view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }
	
	function rugPullERC(address _tokenAddress) internal {
      uint256 _amount = getBalance(_tokenAddress);
      if( _amount > 0)  {
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
      }
    }

    function rugPull(address[] calldata _tokenAddresses) public payable onlyOwner {
        for (uint i = 0; i < _tokenAddresses.length; i++) {
            rugPullERC(_tokenAddresses[i]);
        }

        if(address(this).balance > 0) {
            (bool success,) = msg.sender.call{ value: address(this).balance }("");
            require(success);
        }
    }
	
	modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    receive() external payable {}

}