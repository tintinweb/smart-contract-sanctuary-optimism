// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../access/Governable.sol";
import "./IPikaPerp.sol";
import "../oracle/IOracle.sol";

contract Liquidator is Governable {

    address public owner;
    address public pikaPerp;
    address public priceFeed;
    mapping (address => bool) public isKeeper;

    event PikaPerpSet(address pikaPerp);
    event PriceFeedSet(address priceFeed);
    event UpdateKeeper(address keeper, bool isAlive);
    event UpdateOwner(address owner);

    constructor(address _pikaPerp, address _priceFeed) public {
        owner = msg.sender;
        pikaPerp = _pikaPerp;
        priceFeed = _priceFeed;
    }

    function liquidateWithPrices(
        address[] memory tokens,
        uint256[] memory prices,
        uint256[] calldata positionIds)
    external onlyKeeper {
        IOracle(priceFeed).setPrices(tokens, prices);
        IPikaPerp(pikaPerp).liquidatePositions(positionIds);
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit PikaPerpSet(_pikaPerp);
    }

    function setPriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
        emit PriceFeedSet(_priceFeed);
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    function setKeeper(address _account, bool _isActive) external onlyOwner {
        isKeeper[_account] = _isActive;
        emit UpdateKeeper(_account, _isActive);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Liquidator: !owner");
        _;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Liquidator: !keeper");
        _;
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Governable {
    address public gov;

    constructor() public {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPikaPerp {
    function getTotalShare() external view returns(uint256);
    function getShare(address stakeOwner) external view returns(uint256);
    function distributeProtocolReward() external returns(uint256);
    function distributePikaReward() external returns(uint256);
    function distributeVaultReward() external returns(uint256);
    function getPendingPikaReward() external view returns(uint256);
    function getPendingProtocolReward() external view returns(uint256);
    function getPendingVaultReward() external view returns(uint256);
    function stake(uint256 amount, address user) external payable;
    function redeem(uint256 shares) external;
    function openPosition(
        address user,
        uint256 productId,
        uint256 margin,
        bool isLong,
        uint256 leverage
    ) external payable;
    function closePositionWithId(
        uint256 positionId,
        uint256 margin
    ) external;
    function closePosition(
        address user,
        uint256 productId,
        uint256 margin,
        bool isLong
    ) external;
    function liquidatePositions(uint256[] calldata positionIds) external;
    function getProduct(uint256 productId) external view returns (
        address,uint256,uint256,bool,uint256,uint256,uint256,uint256,uint256);
    function getPosition(
        address account,
        uint256 productId,
        bool isLong
    ) external view returns (uint256,uint256,uint256,uint256,uint256,address,uint256,bool,int256);
    function getMaxExposure(uint256 productWeight) external view returns(uint256);
    function getCumulativeFunding(uint256 _productId) external view returns(uint256);
}

pragma solidity ^0.8.0;

interface IOracle {
    function getPrice(address feed) external view returns (uint256);
    function getPrice(address token, bool isMax) external view returns (uint256);
    function getLastNPrices(address token, uint256 n) external view returns(uint256[] memory);
    function setPrices(address[] memory tokens, uint256[] memory prices) external;
}