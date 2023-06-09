// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnershipTransferred(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

        // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
        // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));

        authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function transferOwnership(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";

interface IPerpsV2MarketSettings {
    function skewScale(bytes32 _marketKey) external view returns (uint256);

    function liquidationPremiumMultiplier(bytes32 _marketKey) external view returns (uint256);

    function liquidationBufferRatio(bytes32 _marketKey) external view returns (uint256);

    function minKeeperFee() external view returns (uint256);

    function maxKeeperFee() external view returns (uint256);

    function liquidationFeeRatio() external view returns (uint256);

    function keeperLiquidationFee() external view returns (uint256);
}

interface IPerpV2Market {
    function assetPrice() external view returns (uint256 price, bool invalid);

    function marketKey() external view returns (bytes32 key);
}

contract BellPepper is Auth {
    struct Params {
        uint256 assetPrice;
        uint256 skewScale;
        uint256 liquidationPremiumMultiplier;
        uint256 liquidationBufferRatio;
        uint256 minKeeperFee;
        uint256 maxKeeperFee;
        uint256 liquidationFeeRatio;
        uint256 keeperLiquidationFee;
    }

    IPerpsV2MarketSettings settings;

    constructor(address _settings) Auth(msg.sender, Authority(address(0x0))) {
        settings = IPerpsV2MarketSettings(_settings);
    }

    function setSettings(address _settings) external requiresAuth {
        settings = IPerpsV2MarketSettings(_settings);
    }

    function getMarketParams(address market) public view returns (Params memory params) {
        IPerpV2Market perpMarket = IPerpV2Market(market);

        (params.assetPrice,) = perpMarket.assetPrice();
        bytes32 marketKey = perpMarket.marketKey();

        params.skewScale = settings.skewScale(marketKey);
        params.liquidationPremiumMultiplier = settings.liquidationPremiumMultiplier(marketKey);
        params.liquidationBufferRatio = settings.liquidationBufferRatio(marketKey);
        params.minKeeperFee = settings.minKeeperFee();
        params.maxKeeperFee = settings.maxKeeperFee();
        params.liquidationFeeRatio = settings.liquidationFeeRatio();
        params.keeperLiquidationFee = settings.keeperLiquidationFee();
    }
}