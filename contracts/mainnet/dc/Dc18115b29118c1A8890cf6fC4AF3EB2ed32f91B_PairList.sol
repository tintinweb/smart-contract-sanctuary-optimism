//SPDX-License-Identifier: None
pragma solidity =0.7.6;
pragma abicoder v2;

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

    function getPool(uint poolId) view external returns (Pool memory pool){
        if(poolId == 0){
            return Pool(0x4200000000000000000000000000000000000006, 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, 500); // WETH / USDC 0.05%
        } else if(poolId == (1 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0x4200000000000000000000000000000000000042, 3000); // WETH / OP 0.3%
        } else if(poolId == (2 << 252)){
            return Pool(0x4200000000000000000000000000000000000042, 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, 3000); // OP / USDC 0.3%
        } else if(poolId == (3 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0x4200000000000000000000000000000000000042, 500); // WETH / OP 0.05%
        } else if(poolId == (4 << 252)){
            return Pool(0x7F5c764cBc14f9669B88837ca1490cCa17c31607, 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, 100); // USDC / DAI 0.01%
        } else if(poolId == (5 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4, 3000); // WETH / SNX 0.3%
        } else if(poolId == (6 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, 3000); // WETH / DAI 0.3%
        }

        return pools[poolId];
    }

    function sweepTokenFromRouter(address router, address token, uint amount, address receiver) onlyOwner external {
        (bool success, ) = router.call(abi.encode(token, amount, receiver));
        require(success);
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