pragma solidity 0.8.10;
/**
 * @title FlatPremium v2
 * @author @InsureDAO
 * @notice General Flat Premium Calculator
 * SPDX-License-Identifier: GPL-3.0
 */

import "../interfaces/IPremiumModelV2.sol";
import "../interfaces/IOwnership.sol";

contract FlatPremiumV2 is IPremiumModelV2 {
    IOwnership public immutable ownership;

    //variables
    mapping(address => uint256) public rates;

    uint256 public constant MAX_RATE = 1e6;
    uint256 private constant RATE_DENOMINATOR = 1e6;

    modifier onlyOwner() {
        require(
            ownership.owner() == msg.sender,
            "Caller is not allowed to operate"
        );
        _;
    }

    constructor(address _ownership, uint256 _defaultRate) {
        require(_ownership != address(0), "zero address");
        require(_defaultRate != 0, "rate is zero");

        ownership = IOwnership(_ownership);
        rates[address(0)] = _defaultRate;
    }

    function getCurrentPremiumRate(
        address _market,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) external view override returns (uint256) {
        return _getRate(_market);
    }

    function getPremiumRate(
        address _market,
        uint256 _amount,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) public view override returns (uint256) {
        return _getRate(_market);
    }

    function getPremium(
        address _market,
        uint256 _amount,
        uint256 _term,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) external view override returns (uint256) {
        require(
            _amount + _lockedAmount <= _totalLiquidity,
            "Amount exceeds total liquidity"
        );

        if (_amount == 0) {
            return 0;
        }

        uint256 premium = (_amount * _getRate(_market) * _term) /
            365 days /
            RATE_DENOMINATOR;

        return premium;
    }

    function setRate(address _market, uint256 _rate)
        external
        override
        onlyOwner
    {
        rates[_market] = _rate;
    }

    function getRate(address _market) external view returns (uint256) {
        return _getRate(_market);
    }

    function _getRate(address _market) internal view returns (uint256) {
        uint256 _rate = rates[_market];
        if (_rate == 0) {
            return rates[address(0)];
        } else {
            return _rate;
        }
    }
}

pragma solidity 0.8.10;

interface IPremiumModelV2 {
    function getCurrentPremiumRate(
        address _market,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) external view returns (uint256);

    function getPremiumRate(
        address _market,
        uint256 _amount,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) external view returns (uint256);

    function getPremium(
        address _market,
        uint256 _amount,
        uint256 _term,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) external view returns (uint256);

    //onlyOwner
    function setRate(address _market, uint256 _rate) external;
}

pragma solidity 0.8.10;

//SPDX-License-Identifier: MIT

interface IOwnership {
    function owner() external view returns (address);

    function futureOwner() external view returns (address);

    function commitTransferOwnership(address newOwner) external;

    function acceptTransferOwnership() external;
}