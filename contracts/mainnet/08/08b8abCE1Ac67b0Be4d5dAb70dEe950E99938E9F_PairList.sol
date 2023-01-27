//SPDX-License-Identifier: None
pragma solidity =0.7.6;

import "./utils/Ownable.sol";
import "./router/libs/IERC20.sol";

interface UniswapV3Pool {
    function token0() external returns (address);
    function token1() external returns (address);
    function fee() external returns (uint24);
}

contract PairList is Ownable {
    struct Pool {
        address token0;
        address token1;
        uint24 fee;
    }

    mapping(uint => Pool) public pools;

    function setPool(uint id, address pool) onlyOwner external {
        require(pools[id].token0 == address(0) && pools[id].token1 == address(0), "already set");

        pools[id] = Pool({
            fee: UniswapV3Pool(pool).fee(),
            token0: UniswapV3Pool(pool).token0(),
            token1: UniswapV3Pool(pool).token1()
        });
    }

    function sweepTokenFromRouter(address router, address token, uint amount, address receiver) onlyOwner external {
        router.call(abi.encode(token, amount, receiver)); // We don't care if call fails
    }
}

//SPDX-License-Identifier: None
pragma solidity =0.7.6;

contract Ownable {
    address public owner;

    constructor(){
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function setOwner(address newOwner) onlyOwner external {
        owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IERC20{
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}