// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;
// Synthetix Interfaces
import "./interfaces/IAddressResolver.sol";
import "./interfaces/IExchanger.sol";
import "./interfaces/IProxy.sol";
import "./interfaces/ISynthetix.sol";
import "./interfaces/ISynth.sol";
// Velodrome Router
import "./interfaces/IRouter.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";

// import "hardhat/console.sol";

contract TricycleSwap {

    // Synthetix AddressResolver
    IAddressResolver public immutable AddressResolver = IAddressResolver(0x1Cb059b7e74fD21665968C908806143E744D5F30);
    ISynthetix private Synthetix;
    IExchanger private Exchanger;
    bytes32 private immutable SYNTHETIX_NAME = "ProxyERC20";
    bytes32 private immutable EXCHANGER_NAME = "Exchanger";
    // WETH
    address public immutable WETH = 0x4200000000000000000000000000000000000006;
    // Velodrome Router
    IRouter public immutable VelodromeRouter = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);

    address public owner;
    address public newOwner;
    bytes32 public trackingCode;
    
    address private immutable sUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address private immutable USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address private immutable ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint reentry = 1;

    modifier reentryG {
        require(reentry == 1);
        reentry = reentry + 1;
        _;
        reentry = reentry - 1;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    mapping (address => address) TokenToSynth;
    constructor() {
        owner = msg.sender;
        Synthetix = ISynthetix(AddressResolver.getAddress(SYNTHETIX_NAME));
        Exchanger = IExchanger(AddressResolver.getAddress(EXCHANGER_NAME));
        // ETH routing
        address sETH = AddressResolver.getAddress("ProxysETH");
        // TokenToSynth[sETH] = sETH; omitted for potential CurveIntgeration style swap
        TokenToSynth[ETH] = sETH;
        TokenToSynth[WETH] = sETH;
        // USD routing
        // TokenToSynth[sUSD] = sUSD; omitted for potential CurveIntgeration style swap
        TokenToSynth[USDC] = sUSD; // USDC
        TokenToSynth[0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1] = sUSD; // DAI
        TokenToSynth[0x94b008aA00579c1307B0EF2c499aD98a8ce58e58] = sUSD; // USDT
        TokenToSynth[0x2E3D870790dC77A83DD1d18184Acc7439A53f475] = sUSD; // FRAX
        TokenToSynth[0xc40F949F8a4e094D1b49a23ea9241D289B7b2819] = sUSD; // LUSD
        TokenToSynth[0x8aE125E8653821E851F12A49F7765db9a9ce7384] = sUSD; // DOLA
        // BTC routing
        address sBTC = AddressResolver.getAddress("ProxysBTC");
        TokenToSynth[0x68f180fcCe6836688e9084f035309E29Bf0A2095] = sBTC; // WBTC
        address sLINK = AddressResolver.getAddress("ProxysLINK");
        TokenToSynth[0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6] = sLINK;
    }

    function exchangeTokenOnly(address _from, address _to, uint _amount) external reentryG returns (uint[] memory) {
        IERC20 from = IERC20(_from);
        from.transferFrom(msg.sender, address(this), _amount);
        uint[] memory received = _exchange(_from, _to, _amount);
        IERC20 to = IERC20(_to);
        to.transfer(msg.sender, received[received.length - 1]);
        return received;
    }

    function exchangeFromETH(address _to) external payable reentryG returns (uint[] memory) {
        IWETH(WETH).deposit{value: msg.value}();
        uint[] memory received = _exchange(WETH, _to, msg.value);
        IERC20 to = IERC20(_to);
        to.transfer(msg.sender, received[received.length - 1]);
        return received;
    }

    function exchangeToETH(address _from, uint _amount) external reentryG returns (uint[] memory) {
        IERC20 from = IERC20(_from);
        from.transferFrom(msg.sender, address(this), _amount);
        uint[] memory received = _exchange(_from, WETH, _amount);
        IWETH(WETH).withdraw(received[received.length - 1]);
        payable(msg.sender).transfer(received[received.length - 1]);
        return received;
    }

    function exchangeTokenOnlyEnforceSlippage(address _from, address _to, uint _amount, uint _minimumReceived) external reentryG returns (uint[] memory) {
        IERC20 from = IERC20(_from);
        from.transferFrom(msg.sender, address(this), _amount);
        uint[] memory received = _exchange(_from, _to, _amount);
        if(received[received.length - 1] < _minimumReceived) {
            revert NotEnoughReceived(_minimumReceived, received[received.length - 1]);
        }
        IERC20 to = IERC20(_to);
        to.transfer(msg.sender, received[received.length - 1]);
        return received;
    }

    function exchangeFromETHEnforceSlippage(address _to, uint _minimumReceived) external payable reentryG returns (uint[] memory) {
        IWETH(WETH).deposit{value: msg.value}();
        uint[] memory received = _exchange(WETH, _to, msg.value);
        IERC20 to = IERC20(_to);
        if(received[received.length - 1] < _minimumReceived) {
            revert NotEnoughReceived(_minimumReceived, received[received.length - 1]);
        }
        to.transfer(msg.sender, received[received.length - 1]);
        return received;
    }

    function exchangeToETHEnforceSlippage(address _from, uint _amount, uint _minimumReceived) external reentryG returns (uint[] memory) {
        IERC20 from = IERC20(_from);
        from.transferFrom(msg.sender, address(this), _amount);
        uint[] memory received = _exchange(_from, WETH, _amount);
        if(received[received.length - 1] < _minimumReceived) {
            revert NotEnoughReceived(_minimumReceived, received[received.length - 1]);
        }
        IWETH(WETH).withdraw(received[received.length - 1]);
        payable(msg.sender).transfer(received[received.length - 1]);
        return received;
    }

    function _exchange(address _from, address _to, uint _amount) internal returns (uint[] memory amounts) {
        IERC20 from = IERC20(_from);
        address synthFrom = TokenToSynth[_from];
        address synthTo = TokenToSynth[_to];
        if(synthFrom == address(0) || synthTo == address(0)) {
            revert TokenNotSupported();
        }
        uint[] memory received = new uint[](3);
        // Velodrome Leg 1
        from.approve(address(VelodromeRouter), _amount);
        IRouter.route[] memory pathA = _getBestRoute(_from, synthFrom, _amount);
        uint[] memory amountA = VelodromeRouter.swapExactTokensForTokens(
            _amount,
            0,
            pathA,
            address(this),
            block.timestamp
        );
        received[0] = amountA[amountA.length - 1];
        // Synthetix Leg
        received[1] = Synthetix.exchangeWithTracking(
            _getCurrencyKey(synthFrom),
            received[0],
            _getCurrencyKey(synthTo),
            owner,
            trackingCode
        );
        // Velodrome Leg 2
        IERC20(synthTo).approve(address(VelodromeRouter), received[1]);
        IRouter.route[] memory pathB = _getBestRoute(synthTo, _to, received[1]);
        uint[] memory amountB = VelodromeRouter.swapExactTokensForTokens(
            received[1],
            0,
            pathB,
            address(this),
            block.timestamp
        );
        received[2] = amountB[amountB.length - 1];
        emit TokenExchange(_from, _to, _amount, received[received.length - 1]);
        return received;
    }

    function getAmount(address _from, address _to, uint _amount) external view returns (uint[] memory) {
        address synthFrom = TokenToSynth[_from];
        address synthTo = TokenToSynth[_to];
        if(synthFrom == address(0) || synthTo == address(0)) {
            revert TokenNotSupported();
        }
        uint[] memory received = new uint[](3);
        address from = (_from == ETH) ? WETH : _from;
        address to = (_to == ETH) ? WETH : _to;
        IRouter.route[] memory routesA = _getBestRoute(from, synthFrom, _amount);
        uint[] memory amountsA = VelodromeRouter.getAmountsOut(_amount, routesA);
        received[0] = amountsA[amountsA.length - 1];
        (uint amountReceived,,) = Exchanger.getAmountsForExchange(
            received[0],
            _getCurrencyKey(synthFrom),
            _getCurrencyKey(synthTo)
        );
        received[1] = amountReceived;
        IRouter.route[] memory routesB = _getBestRoute(synthTo, to, received[1]);
        uint[] memory amountsB = VelodromeRouter.getAmountsOut(received[1], routesB);
        received[2] = amountsB[amountsB.length - 1];
        return received;
    }
    // helper function
    // reading `currencyKey` from synth will write to storage, so get the implementation and read it instead
    function _getCurrencyKey(address _synth) internal view returns (bytes32) {
        return ISynth(IProxy(_synth).target()).currencyKey();
    }
    // in case `Synthetix` and `Exchanger` address has changed
    function rebuildCache() external {
        Synthetix = ISynthetix(AddressResolver.getAddress(SYNTHETIX_NAME));
        Exchanger = IExchanger(AddressResolver.getAddress(EXCHANGER_NAME));
    }
    // creating velodrome route with opininated path to usdc route for usd stablecoin
    function _getBestRoute(address _from, address _to, uint _amountIn) internal view returns (IRouter.route[] memory) {
        // just in case
        IRouter.route[] memory RouteA = new IRouter.route[](1);
        RouteA[0] = IRouter.route(_from, _to, false);
        uint[] memory amountA = VelodromeRouter.getAmountsOut(_amountIn, RouteA);
        
        IRouter.route[] memory RouteB = new IRouter.route[](1);
        RouteB[0] = IRouter.route(_from, _to, true);
        uint[] memory amountB = VelodromeRouter.getAmountsOut(_amountIn, RouteB);
        IRouter.route[] memory bestRoute;
        uint bestAmount;
        uint compAmountA = amountA[amountA.length - 1];
        uint compAmountB = amountB[amountB.length - 1];
        if(compAmountA > compAmountB) {
            bestRoute = RouteA;
            bestAmount = compAmountA;
        }
        else {
            bestRoute = RouteB;
            bestAmount = compAmountB;
        }
        // USDC route
        if((_from == sUSD || _to == sUSD) && (_from != USDC && _to != USDC)) {
            IRouter.route[] memory RouteC = new IRouter.route[](2);
            RouteC[0] = IRouter.route(_from, USDC, true);
            RouteC[1] = IRouter.route(USDC, _to, true);
            uint[] memory amountC = VelodromeRouter.getAmountsOut(_amountIn, RouteC);
            uint compAmountC = amountC[amountC.length - 1];
            bestRoute = (bestAmount > compAmountC) ? bestRoute : RouteC;
        }
        return bestRoute;
    }

    function setTrackingCode(bytes32 _trackingCode) external onlyOwner {
        trackingCode = _trackingCode;
    }

    function addToken(address _token, address _synth) external onlyOwner {
        //enforcing swap must not start or end from synth
        require(_token.code.length > 0 &&
                _getCurrencyKey(_synth) != bytes32(0) &&
                _token != _synth);
     TokenToSynth[_token] = _synth;
    }
    function transferOwnership(address _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() external {
        require(msg.sender == newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
    // receiving WETH withdrawal
    receive() external payable {
        require(msg.sender == WETH);
    }
    error TokenNotSupported();
    error NotEnoughReceived(uint expected, uint actual);

    event TokenExchange(address from, address to, uint anountIn, uint amountOut);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

interface IExchanger {
    function getAmountsForExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint amountReceived,
            uint fee,
            uint exchangeFeeRate
        );
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;
interface IProxy {
    function target() external view returns (address);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

interface ISynthetix {
    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;
interface ISynth {
    function currencyKey() external view returns (bytes32);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

interface IRouter {
    struct route {
        address from;
        address to;
        bool stable;
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        route[] memory routes
    ) external view returns (uint[] memory amounts);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}