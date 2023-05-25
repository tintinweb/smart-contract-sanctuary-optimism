// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPriceFeed {
    function description() external view returns (string memory);
    function aggregator() external view returns (address);
    function latestAnswer() external view returns (int256);
    function latestRound() external view returns (uint80);
    function getRoundData(uint80 roundId) external view returns (uint80, int256, uint256, uint256, uint80);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPair {
    function metadata() external view returns (uint dec0, uint dec1, uint r0, uint r1, bool st, address t0, address t1);
    function claimFees() external returns (uint, uint);
    function tokens() external returns (address, address);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
}

interface IERC20 {
    function decimals() external view returns (uint8);
}

import "./interfaces/IPriceFeed.sol";

contract VeloPriceFeed is IPriceFeed {
    int256 public answer;
    uint80 public roundId;
    string public override description = "VeloPriceFeed";
    address public override aggregator;
    
    address public veloPair; // ONLY USE USDC PAIR (0xe8537b6FF1039CB9eD0B71713f697DDbaDBb717d)

    uint256 public decimals;

    address public gov;
    address public veloToken = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;

    mapping(uint80 => int256) public answers;
    mapping(address => bool) public isAdmin;

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    constructor() public {
        gov = msg.sender;
        isAdmin[msg.sender] = true;
    }

    function setVeloPair(address _pairAddress) public {
        require(msg.sender == gov, "PriceFeed: forbidden");
        veloPair = _pairAddress;
    }

    function setAdmin(address _account, bool _isAdmin) public {
        require(msg.sender == gov, "PriceFeed: forbidden");
        isAdmin[_account] = _isAdmin;
    }

    function latestAnswer() public view override returns (int256) {
        return answer;
    }

    function latestRound() public view override returns (uint80) {
        return roundId;
    }

    function getVeloTokenPriceInUsd() public returns(int256)
    {
        IPair pair = IPair(veloPair);
        (address token0Address, address token1Address) = pair.tokens();
        IERC20 token0 = IERC20(token0Address);
        IERC20 token1 = IERC20(token1Address);

        (uint reserve0, uint reserve1, ) = pair.getReserves();

        uint8 decimals0 = token0.decimals();
        uint8 decimals1 = token1.decimals();

        uint256 price;

        if (token0Address == address(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05)) {
            price = (uint256(reserve1) * 10**decimals0) / (uint256(reserve0) * 10**decimals1);
        } else {
            price = (uint256(reserve0) * 10**decimals1) / (uint256(reserve1) * 10**decimals0);
        }

        return int256(price * 10**8);
    }

    function setLatestAnswer() public {
        require(isAdmin[msg.sender], "PriceFeed: forbidden");
        roundId = roundId + 1;
        answer = getVeloTokenPriceInUsd();
        answers[roundId] = getVeloTokenPriceInUsd();

        emit AnswerUpdated(
        answer,
        uint256(roundId),
        block.timestamp
      );
    }

    // returns roundId, answer, startedAt, updatedAt, answeredInRound
    function getRoundData(uint80 _roundId)
        public
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (_roundId, answers[_roundId], 0, 0, 0);
    }
}