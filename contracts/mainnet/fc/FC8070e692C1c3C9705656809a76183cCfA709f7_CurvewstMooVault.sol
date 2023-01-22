pragma solidity ^0.8.0;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestAnswer() external view returns (int256);
}

interface IPriceSource {
    function latestAnswer() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IBeefyV6 {
    function balanceOf(address account) external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256 price);
    function decimals() external view returns (uint8);
    function want() external view returns (address);
}

interface ICurvePool {
    function get_virtual_price() external view returns (uint256);
    function remove_liquidity(uint256, uint256[2] calldata) external returns (uint256);
}

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract CurvewstMooVault is IPriceSource {

    /* vaults */
    address public mooVault;
    address public perfToken;

    /* chainlink */
    address public eth;
    address public steth;
    address public exchangeRate;

    /* curve */
    uint256 public virtualprice;
    address public crvPool;

    mapping(address => address) oracles;
    
    event VirtualPrice(
        uint256 price
    );

    constructor(
        address _mooVault,
        address _crvPool,

        address _EthUsdOracle,
        address _stETHusdOracle,

        address _wstethExchangeOracle,

        address _eth,
        address _steth,

        address _perfToken
    ) public {
        mooVault = _mooVault;
        crvPool = _crvPool;
        eth = _eth;
        steth = _steth;
        oracles[eth] = _EthUsdOracle;
        oracles[steth] = _stETHusdOracle;
        exchangeRate = _wstethExchangeOracle;
        perfToken = _perfToken;
    }

    function updateVirtualPrice() external {
        uint256 _virtualPrice = ICurvePool(crvPool).get_virtual_price();
        
        {
            uint256[2] memory amounts;
            ICurvePool(crvPool).remove_liquidity(0, amounts);
        }
        
        virtualprice = _virtualPrice;
        emit VirtualPrice(virtualprice);
    }

    // It retrieves the usd value for a mooVault lp token
    function latestAnswer() external view returns (uint256) {

        IBeefyV6 mooVault_ = IBeefyV6(mooVault);

        uint256 pricePerShare = mooVault_.getPricePerFullShare();

        uint256 ethUsdPrice = uint256(AggregatorV3Interface(oracles[eth]).latestAnswer());
 
        AggregatorV3Interface stETH = AggregatorV3Interface(oracles[steth]);
        AggregatorV3Interface exstETH = AggregatorV3Interface(exchangeRate);

        uint256 stETHusdPrice = (uint256(stETH.latestAnswer()) * uint256(exstETH.latestAnswer())) / 1e18;

        // calculate min ETH price
        uint256 minPrice = ethUsdPrice;
        if (minPrice > stETHusdPrice) {
            minPrice = stETHusdPrice;
        }

        uint256 price = ((pricePerShare * minPrice) * virtualprice) / 1e36;

        uint256 newPrice = ( mooVault_.balanceOf(perfToken)* price ) / ERC20(perfToken).totalSupply();

        return newPrice;
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    receive() external payable {}
}