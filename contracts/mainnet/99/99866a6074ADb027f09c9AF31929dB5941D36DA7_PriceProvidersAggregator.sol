// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../interfaces/core/IAddressProvider.sol";

/**
 * @notice Contract module which provides access control mechanism, where
 * the governor account is granted with exclusive access to specific functions.
 * @dev Uses the AddressProvider to get the governor
 */
abstract contract Governable {
    IAddressProvider public constant addressProvider = IAddressProvider(0xfbA0816A81bcAbBf3829bED28618177a2bf0e82A);

    /// @dev Throws if called by any account other than the governor.
    modifier onlyGovernor() {
        require(msg.sender == addressProvider.governor(), "not-governor");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/core/IPriceProvidersAggregator.sol";
import "../access/Governable.sol";

/**
 * @title Price Providers Aggregator
 */
contract PriceProvidersAggregator is IPriceProvidersAggregator, Governable {
    /**
     * The native token (usually the most liquid asset in the chain)
     * @dev Is used when getting quote from two price providers
     */
    address public immutable nativeToken;

    /**
     * @notice Price providers map
     */
    mapping(DataTypes.Provider => IPriceProvider) public override priceProviders;

    /// Emitted when an price provider is updated
    event PriceProviderUpdated(
        DataTypes.Provider provider,
        IPriceProvider oldPriceProvider,
        IPriceProvider newPriceProvider
    );

    constructor(address nativeToken_) {
        require(nativeToken_ != address(0), "native-token-is-null");
        nativeToken = nativeToken_;
    }

    /// @inheritdoc IPriceProvidersAggregator
    function getPriceInUsd(DataTypes.Provider provider_, address token_)
        external
        view
        override
        returns (uint256 _priceInUsd, uint256 _lastUpdatedAt)
    {
        IPriceProvider _provider = priceProviders[provider_];
        require(address(_provider) != address(0), "provider-not-set");
        return _provider.getPriceInUsd(token_);
    }

    /// @inheritdoc IPriceProvidersAggregator
    function quote(
        DataTypes.Provider provider_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        override
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        )
    {
        IPriceProvider _provider = priceProviders[provider_];
        require(address(_provider) != address(0), "provider-not-set");
        return _provider.quote(tokenIn_, tokenOut_, amountIn_);
    }

    /// @inheritdoc IPriceProvidersAggregator
    function quote(
        DataTypes.Provider providerIn_,
        address tokenIn_,
        DataTypes.Provider providerOut_,
        address tokenOut_,
        uint256 amountIn_
    )
        public
        view
        override
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _nativeTokenLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        )
    {
        IPriceProvider _providerIn = priceProviders[providerIn_];
        require(address(_providerIn) != address(0), "provider-in-not-set");

        if (providerIn_ == providerOut_) {
            (_amountOut, _tokenInLastUpdatedAt, _tokenOutLastUpdatedAt) = _providerIn.quote(
                tokenIn_,
                tokenOut_,
                amountIn_
            );
            _nativeTokenLastUpdatedAt = block.timestamp;
            return (_amountOut, _tokenInLastUpdatedAt, _nativeTokenLastUpdatedAt, _tokenOutLastUpdatedAt);
        }

        IPriceProvider _providerOut = priceProviders[providerOut_];
        require(address(_providerOut) != address(0), "provider-out-not-set");

        uint256 _nativeTokenLastUpdatedAt0;
        uint256 _nativeTokenLastUpdatedAt1;
        (_amountOut, _tokenInLastUpdatedAt, _nativeTokenLastUpdatedAt0) = _providerIn.quote(
            tokenIn_,
            nativeToken,
            amountIn_
        );
        (_amountOut, _nativeTokenLastUpdatedAt1, _tokenOutLastUpdatedAt) = _providerOut.quote(
            nativeToken,
            tokenOut_,
            _amountOut
        );
        _nativeTokenLastUpdatedAt = Math.min(_nativeTokenLastUpdatedAt0, _nativeTokenLastUpdatedAt1);
    }

    /// @inheritdoc IPriceProvidersAggregator
    function quoteTokenToUsd(
        DataTypes.Provider provider_,
        address token_,
        uint256 amountIn_
    ) external view override returns (uint256 amountOut_, uint256 _lastUpdatedAt) {
        IPriceProvider _provider = priceProviders[provider_];
        require(address(_provider) != address(0), "provider-not-set");
        return _provider.quoteTokenToUsd(token_, amountIn_);
    }

    /// @inheritdoc IPriceProvidersAggregator
    function quoteUsdToToken(
        DataTypes.Provider provider_,
        address token_,
        uint256 amountIn_
    ) external view override returns (uint256 _amountOut, uint256 _lastUpdatedAt) {
        IPriceProvider _provider = priceProviders[provider_];
        require(address(_provider) != address(0), "provider-not-set");
        return _provider.quoteUsdToToken(token_, amountIn_);
    }

    /// @inheritdoc IPriceProvidersAggregator
    function setPriceProvider(DataTypes.Provider provider_, IPriceProvider priceProvider_)
        external
        override
        onlyGovernor
    {
        require(provider_ != DataTypes.Provider.NONE, "invalid-provider");
        IPriceProvider _current = priceProviders[provider_];
        require(priceProvider_ != _current, "same-as-current");

        emit PriceProviderUpdated(provider_, _current, priceProvider_);

        priceProviders[provider_] = priceProvider_;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./IStableCoinProvider.sol";
import "./IPriceProvidersAggregator.sol";

interface IAddressProvider {
    function governor() external view returns (address);

    function providersAggregator() external view returns (IPriceProvidersAggregator);

    function stableCoinProvider() external view returns (IStableCoinProvider);

    function updateProvidersAggregator(IPriceProvidersAggregator providersAggregator_) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IPriceProvider {
    /**
     * @notice Get USD (or equivalent) price of an asset
     * @param token_ The address of asset
     * @return _priceInUsd The USD price
     * @return _lastUpdatedAt Last updated timestamp
     */
    function getPriceInUsd(address token_) external view returns (uint256 _priceInUsd, uint256 _lastUpdatedAt);

    /**
     * @notice Get quote
     * @param tokenIn_ The address of assetIn
     * @param tokenOut_ The address of assetOut
     * @param amountIn_ Amount of input token
     * @return _amountOut Amount out
     * @return _tokenInLastUpdatedAt Last updated timestamp of `tokenIn_`
     * @return _tokenOutLastUpdatedAt Last updated timestamp of `tokenOut_`
     */
    function quote(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        );

    /**
     * @notice Get quote in USD (or equivalent) amount
     * @param token_ The address of assetIn
     * @param amountIn_ Amount of input token.
     * @return amountOut_ Amount in USD
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteTokenToUsd(address token_, uint256 amountIn_)
        external
        view
        returns (uint256 amountOut_, uint256 _lastUpdatedAt);

    /**
     * @notice Get quote from USD (or equivalent) amount to amount of token
     * @param token_ The address of assetOut
     * @param amountIn_ Input amount in USD
     * @return _amountOut Output amount of token
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteUsdToToken(address token_, uint256 amountIn_)
        external
        view
        returns (uint256 _amountOut, uint256 _lastUpdatedAt);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../../libraries/DataTypes.sol";
import "./IPriceProvider.sol";

/**
 * @notice PriceProvidersAggregator interface
 * @dev Worth noting that the `_lastUpdatedAt` logic depends on the underlying price provider. In summary:
 * ChainLink: returns the last updated date from the aggregator
 * UniswapV2: returns the date of the latest pair oracle update
 * UniswapV3: assumes that the price is always updated (returns block.timestamp)
 * Flux: returns the last updated date from the aggregator
 * Umbrella (FCD): returns the last updated date returned from their oracle contract
 * Umbrella (Passport): returns the date of the latest pallet submission
 * Anytime that a quote performs more than one query, it uses the oldest date as the `_lastUpdatedAt`.
 * See more: https://github.com/bloqpriv/one-oracle/issues/64
 */
interface IPriceProvidersAggregator {
    /**
     * @notice Get USD (or equivalent) price of an asset
     * @param provider_ The price provider to get quote from
     * @param token_ The address of asset
     * @return _priceInUsd The USD price
     * @return _lastUpdatedAt Last updated timestamp
     */
    function getPriceInUsd(DataTypes.Provider provider_, address token_)
        external
        view
        returns (uint256 _priceInUsd, uint256 _lastUpdatedAt);

    /**
     * @notice Provider Providers' mapping
     */
    function priceProviders(DataTypes.Provider provider_) external view returns (IPriceProvider _priceProvider);

    /**
     * @notice Get quote
     * @param provider_ The price provider to get quote from
     * @param tokenIn_ The address of assetIn
     * @param tokenOut_ The address of assetOut
     * @param amountIn_ Amount of input token
     * @return _amountOut Amount out
     * @return _tokenInLastUpdatedAt Last updated timestamp of `tokenIn_`
     * @return _tokenOutLastUpdatedAt Last updated timestamp of `tokenOut_`
     */
    function quote(
        DataTypes.Provider provider_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        );

    /**
     * @notice Get quote
     * @dev If providers aren't the same, uses native token as "bridge"
     * @param providerIn_ The price provider to get quote for the tokenIn
     * @param tokenIn_ The address of assetIn
     * @param providerOut_ The price provider to get quote for the tokenOut
     * @param tokenOut_ The address of assetOut
     * @param amountIn_ Amount of input token
     * @return _amountOut Amount out
     * @return _tokenInLastUpdatedAt Last updated timestamp of `tokenIn_`
     * @return _nativeTokenLastUpdatedAt Last updated timestamp of native token (i.e. WETH) used when providers aren't the same
     * @return _tokenOutLastUpdatedAt Last updated timestamp of `tokenOut_`
     */
    function quote(
        DataTypes.Provider providerIn_,
        address tokenIn_,
        DataTypes.Provider providerOut_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _nativeTokenLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        );

    /**
     * @notice Get quote in USD (or equivalent) amount
     * @param provider_ The price provider to get quote from
     * @param token_ The address of assetIn
     * @param amountIn_ Amount of input token.
     * @return amountOut_ Amount in USD
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteTokenToUsd(
        DataTypes.Provider provider_,
        address token_,
        uint256 amountIn_
    ) external view returns (uint256 amountOut_, uint256 _lastUpdatedAt);

    /**
     * @notice Get quote from USD (or equivalent) amount to amount of token
     * @param provider_ The price provider to get quote from
     * @param token_ The address of assetOut
     * @param amountIn_ Input amount in USD
     * @return _amountOut Output amount of token
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteUsdToToken(
        DataTypes.Provider provider_,
        address token_,
        uint256 amountIn_
    ) external view returns (uint256 _amountOut, uint256 _lastUpdatedAt);

    /**
     * @notice Set a price provider
     * @dev Administrative function
     * @param provider_ The provider (from enum)
     * @param priceProvider_ The price provider contract
     */
    function setPriceProvider(DataTypes.Provider provider_, IPriceProvider priceProvider_) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IStableCoinProvider {
    /**
     * @notice Return the stable coin if pegged
     * @dev Check price relation between both stable coins and revert if peg is too loose
     * @return _stableCoin The primary stable coin if pass all checks
     */
    function getStableCoinIfPegged() external view returns (address _stableCoin);

    /**
     * @notice Convert given amount of stable coin to USD representation (18 decimals)
     */
    function toUsdRepresentation(uint256 stableCoinAmount_) external view returns (uint256 _usdAmount);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library DataTypes {
    /**
     * @notice Price providers enumeration
     */
    enum Provider {
        NONE,
        CHAINLINK,
        UNISWAP_V3,
        UNISWAP_V2,
        SUSHISWAP,
        TRADERJOE,
        PANGOLIN,
        QUICKSWAP,
        UMBRELLA_FIRST_CLASS,
        UMBRELLA_PASSPORT,
        FLUX
    }

    enum ExchangeType {
        UNISWAP_V2,
        SUSHISWAP,
        TRADERJOE,
        PANGOLIN,
        QUICKSWAP,
        UNISWAP_V3,
        PANCAKE_SWAP,
        CURVE
    }

    enum SwapType {
        EXACT_INPUT,
        EXACT_OUTPUT
    }
}