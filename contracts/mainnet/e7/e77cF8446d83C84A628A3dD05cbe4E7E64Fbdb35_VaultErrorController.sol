// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./interfaces/IVault.sol";
import "../access/Governable.sol";

contract VaultErrorController is Governable {
    function setErrors(IVault _vault, string[] calldata _errors) external onlyGov {
        for (uint256 i = 0; i < _errors.length; i++) {
            _vault.setError(i, _errors[i]);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IVaultUtils.sol";
import "./IFeeUtils.sol";

interface IVault {
    function isInitialized() external view returns (bool);
    function isSwapEnabled() external view returns (bool);
    function isLeverageEnabled() external view returns (bool);

    function setVaultUtils(IVaultUtils _vaultUtils) external;
    function setFeeUtils(IFeeUtils _feeUtils) external;
    function setError(uint256 _errorCode, string calldata _error) external;

    function router() external view returns (address);
    function usdf() external view returns (address);
    function gov() external view returns (address);

    function getVaultUtils() external view returns (address);
    function getFeeUtils() external view returns (address);

    function whitelistedTokenCount() external view returns (uint256);
    function maxLeverage() external view returns (uint256);

    function minProfitTime() external view returns (uint256);
    function totalTokenWeights() external view returns (uint256);
    function getTargetUsdfAmount(address _token) external view returns (uint256);

    function inManagerMode() external view returns (bool);
    function inPrivateLiquidationMode() external view returns (bool);

    function maxGasPrice() external view returns (uint256);

    function approvedRouters(address _account, address _router) external view returns (bool);
    function isLiquidator(address _account) external view returns (bool);
    function isManager(address _account) external view returns (bool);

    function minProfitBasisPoints(address _token) external view returns (uint256);
    function tokenBalances(address _token) external view returns (uint256);

    function setMaxLeverage(uint256 _maxLeverage) external;
    function setInManagerMode(bool _inManagerMode) external;
    function setManager(address _manager, bool _isManager) external;
    function setIsSwapEnabled(bool _isSwapEnabled) external;
    function setIsLeverageEnabled(bool _isLeverageEnabled) external;
    function setMaxGasPrice(uint256 _maxGasPrice) external;
    function setUsdfAmount(address _token, uint256 _amount) external;
    function setBufferAmount(address _token, uint256 _amount) external;
    function setMaxGlobalShortSize(address _token, uint256 _amount) external;
    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external;
    function setLiquidator(address _liquidator, bool _isActive) external;

    function setMinProfitTime(uint256 _minProfitTime) external;

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _redemptionBps,
        uint256 _minProfitBps,
        uint256 _maxUsdfAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function clearTokenConfig(address _token) external;

    function setPriceFeed(address _priceFeed) external;
    function withdrawFees(address _token, address _receiver) external returns (uint256);

    function directPoolDeposit(address _token) external;
    function buyUSDF(address _token, address _receiver) external returns (uint256);
    function sellUSDF(address _token, address _receiver) external returns (uint256);
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external;
    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);

    function priceFeed() external view returns (address);

    function allWhitelistedTokensLength() external view returns (uint256);
    function allWhitelistedTokens(uint256) external view returns (address);
    function whitelistedTokens(address _token) external view returns (bool);
    function stableTokens(address _token) external view returns (bool);
    function shortableTokens(address _token) external view returns (bool);
    function feeReserves(address _token) external view returns (uint256);
    function globalShortSizes(address _token) external view returns (uint256);
    function globalShortAveragePrices(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
    function tokenDecimals(address _token) external view returns (uint256);
    function tokenWeights(address _token) external view returns (uint256);
    function guaranteedUsd(address _token) external view returns (uint256);
    function poolAmounts(address _token) external view returns (uint256);
    function bufferAmounts(address _token) external view returns (uint256);
    function reservedAmounts(address _token) external view returns (uint256);
    function usdfAmounts(address _token) external view returns (uint256);
    function maxUsdfAmounts(address _token) external view returns (uint256);
    function getRedemptionAmount(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) external view returns (bool, uint256);
    function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (bool, uint256);
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
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

import "./IFeeUtils.sol";

interface IVaultUtils {
    function getFeeUtils() external view returns (address);

    function setFeeUtils(IFeeUtils _feeUtils) external;
    function validateIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external view;
    function validateDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external view;
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFeeUtils {
    function gov() external view returns (address);

    function feeMultiplierIfInactive() external view returns (uint256);
    function isActive() external view returns (bool);

    function setFeeMultiplierIfInactive(uint256 _feeMultiplierIfInactive) external;
    function setIsActive(bool _isActive) external;

    function getLiquidationFeeUsd() external view returns (uint256);
    function getBaseIncreasePositionFeeBps(address _indexToken) external view returns (uint256);
    function getBaseDecreasePositionFeeBps(address _indexToken) external view returns (uint256);

    function getEntryRolloverRate(address _collateralToken) external view returns (uint256);
    function getNextRolloverRate(address _token) external view returns (uint256);
    function getRolloverRates(address _weth, address[] memory _tokens) external view returns (uint256[] memory);
    function updateCumulativeRolloverRate(address _collateralToken) external;

    function getIncreasePositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getDecreasePositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getRolloverFee(address _collateralToken, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);

    function getBuyUsdfFeeBasisPoints(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getSellUsdfFeeBasisPoints(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _usdfAmount) external view returns (uint256);
    function getFeeBasisPoints(address _token, uint256 _usdfDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);
}