// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../access/Governable.sol";
import "./interfaces/ILiquidityReferralStorage.sol";

contract LiquidityReferralStorage is Governable, ILiquidityReferralStorage {
    uint256 public constant BASIS_POINTS = 10000;

    mapping (address => uint256) public referrerTiers; // link between user <> tier
    mapping (uint256 => uint256) public tierTotalRebates;

    event SetTierTotalRebate(uint256 tierId, uint256 totalRebate);
    event SetReferrerTier(address referrer, uint256 tierId);

    function setTierTotalRebate(uint256 _tierId, uint256 _totalRebate) external override onlyGov {
        require(_totalRebate <= BASIS_POINTS, "LiquidityReferralStorage: invalid totalRebate");

        tierTotalRebates[_tierId] = _totalRebate;
        emit SetTierTotalRebate(_tierId, _totalRebate);
    }

    function setReferrerTier(address _referrer, uint256 _tierId) external override onlyGov {
        referrerTiers[_referrer] = _tierId;
        emit SetReferrerTier(_referrer, _tierId);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ILiquidityReferralStorage {
    function setTierTotalRebate(uint256 _tierId, uint256 _totalRebate) external;
    function setReferrerTier(address _referrer, uint256 _tierId) external;
}