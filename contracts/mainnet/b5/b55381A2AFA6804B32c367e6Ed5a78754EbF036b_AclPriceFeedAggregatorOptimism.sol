// 2a8eaf68ac21df3941127c669e34999f03871082
// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.17;

import "AclPriceFeedAggregatorBASE.sol";



contract AclPriceFeedAggregatorOptimism is AclPriceFeedAggregatorBASE {
    
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    constructor() {
        tokenMap[ETH] = WETH;   //nativeToken to wrappedToken
        tokenMap[address(0)] = WETH;

        priceFeedAggregator[address(0)] = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
        priceFeedAggregator[ETH] = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;// ETH
        priceFeedAggregator[WETH] = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;// WETH
        priceFeedAggregator[0x4200000000000000000000000000000000000042] = 0x0D276FC14719f9292D5C1eA2198673d1f4269246;// OP
        priceFeedAggregator[0x68f180fcCe6836688e9084f035309E29Bf0A2095] = 0x718A5788b89454aAE3A028AE9c111A29Be6c2a6F;// WBTC
        priceFeedAggregator[0x6fd9d7AD17242c41f7131d257212c54A0e816691] = 0x11429eE838cC01071402f21C219870cbAc0a59A0;// UNI
        priceFeedAggregator[0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6] = 0xCc232dcFAAE6354cE191Bd574108c1aD03f86450;// LINK
        priceFeedAggregator[0x7F5c764cBc14f9669B88837ca1490cCa17c31607] = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;// USDC
        priceFeedAggregator[0x94b008aA00579c1307B0EF2c499aD98a8ce58e58] = 0xECef79E109e997bCA29c1c0897ec9d7b03647F5E;// USDT
        priceFeedAggregator[0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1] = 0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6;// DAI
        priceFeedAggregator[0x2E3D870790dC77A83DD1d18184Acc7439A53f475] = 0xc7D132BeCAbE7Dcc4204841F33bae45841e41D9C;// FRAX
        priceFeedAggregator[0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97] = address(0);// STG
        priceFeedAggregator[0xFdb794692724153d1488CcdBE0C56c252596735F] = address(0);// LDO
        priceFeedAggregator[0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9] = 0x7f99817d87baD03ea21E05112Ca799d715730efe;// sUSD
        priceFeedAggregator[0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb] = address(0);// WSTETH
    }
}

// 2a8eaf68ac21df3941127c669e34999f03871082
// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.17;

import "Ownable.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

interface IERC20 {
    function decimals() external view returns (uint8);
}


contract AclPriceFeedAggregatorBASE is TransferOwnable{
    
    uint256 public constant DECIMALS_BASE = 18;
    mapping(address => address) public priceFeedAggregator;
    mapping(address => address) public tokenMap;

    struct PriceFeedAggregator {
        address token; 
        address priceFeed; 
    }

    event PriceFeedUpdated(address indexed token, address indexed priceFeed);
    event TokenMap(address indexed nativeToken, address indexed wrappedToken);

    function getUSDPrice(address _token) public view returns (uint256,uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAggregator[_token]);
        require(address(priceFeed) != address(0), "priceFeed not found");
        (uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        require(price > 0, "Chainlink: price <= 0");
        require(answeredInRound >= roundId, "Chainlink: answeredInRound <= roundId");
        require(updatedAt > 0, "Chainlink: updatedAt <= 0");
        return (uint256(price) , uint256(priceFeed.decimals()));
    }

    function getUSDValue(address _token , uint256 _amount) public view returns (uint256) {
        if (tokenMap[_token] != address(0)) {
            _token = tokenMap[_token];
        } 
        (uint256 price, uint256 priceFeedDecimals) = getUSDPrice(_token);
        uint256 usdValue = (_amount * uint256(price) * (10 ** DECIMALS_BASE)) / ((10 ** IERC20(_token).decimals()) * (10 ** priceFeedDecimals));
        return usdValue;
    }

    function setPriceFeed(address _token, address _priceFeed) public onlyOwner {    
        require(_priceFeed != address(0), "_priceFeed not allowed");
        require(priceFeedAggregator[_token] != _priceFeed, "_token _priceFeed existed");
        priceFeedAggregator[_token] = _priceFeed;
        emit PriceFeedUpdated(_token,_priceFeed);
    }

    function setPriceFeeds(PriceFeedAggregator[] calldata _priceFeedAggregator) public onlyOwner {    
        for (uint i=0; i < _priceFeedAggregator.length; i++) { 
            priceFeedAggregator[_priceFeedAggregator[i].token] = _priceFeedAggregator[i].priceFeed;
        }
    }

    function setTokenMap(address _nativeToken, address _wrappedToken) public onlyOwner {    
        require(_wrappedToken != address(0), "_wrappedToken not allowed");
        require(tokenMap[_nativeToken] != _wrappedToken, "_nativeToken _wrappedToken existed");
        tokenMap[_nativeToken] = _wrappedToken;
        emit TokenMap(_nativeToken,_wrappedToken);
    }


    fallback() external {
        revert("Unauthorized access");
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "Context.sol";

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function _transferOwnership(address newOwner) internal virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract TransferOwnable is Ownable {
    function transferOwnership(address newOwner) public virtual onlyOwner {
        _transferOwnership(newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}