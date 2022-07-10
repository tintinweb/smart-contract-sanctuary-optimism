pragma solidity ^0.8;

import "Math.sol";
import "IERC20.sol";
import "IUniswapV2Factory.sol";
import "IUniswapV2Callee.sol";
import "IUniswapV2Pair.sol";
import "OwnableAccept.sol";

interface IERC20WithBurn is IERC20 {
    function burn(uint amount) external;
}

contract BuySupportPool is OwnableAccept {
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    IERC20 immutable public token0;
    IERC20 immutable public token1;
    IERC20WithBurn immutable public zip;
    IERC20 immutable public weth;
    bool immutable public zipIsToken0;
    IUniswapV2Pair immutable basePool;

    uint112 public wethReserve;

    function tokens() public view returns (address _token0, address _token1) {
        return (address(token0), address(token1));
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        //it's used in fee router methods and subtracted from the balance
        if(zipIsToken0) {
            return (0, uint112(wethReserve), uint32(block.timestamp));
        }
        else {
            return (uint112(wethReserve), 0, uint32(block.timestamp));
        }
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ZipswapBuySupport: TRANSFER_FAILED');
    }

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(IUniswapV2Pair _basePool, bool _zipIsToken0) {
        basePool = _basePool;
        (address _token0, address _token1) = _basePool.tokens();
        (token0, token1) = (IERC20(_token0), IERC20(_token1));
        assert(_token0 < _token1);
        if(!_zipIsToken0) {
            (_token0, _token1) = (_token1, _token0);
        }
        (zip, weth) = (IERC20WithBurn(_token0), IERC20(_token1));
        zipIsToken0 = _zipIsToken0;
    }

    //only one *In non-zero and only one *Out non-zero
    //checks done in swap, assumed to hold and amounts to be correct
    function swapWithBasePool(uint zipIn, uint zipOut, uint wethIn, uint wethOut, address to) internal {
        if(zipIn != 0) {
            _safeTransfer(address(zip), address(basePool), zipIn);
        }
        else /* wethIn != 0 */ {
            _safeTransfer(address(weth), address(basePool), wethIn);
        }
        (uint amount0Out, uint amount1Out) = swapOrder2(zipOut, wethOut);
        basePool.swap(amount0Out, amount1Out, to, bytes(''));
    }

    //note: this doesn't enforce the pool invariant due to rounding and isqrt. use getAmountOut on the result
    //security assumption: all arguments are pool variables < 2**112
    function getAmountInUntilEqualPrice(uint reserve0, uint reserve1, uint priceNumerator, uint priceDenominator) internal pure returns (int amount0In) {
        amount0In = (int(Math.sqrt(reserve0*(3988000*priceNumerator*reserve1/priceDenominator + 9*reserve0)))-int(1997*reserve0))/1994;
    }

    function getBasePoolReserves() internal view returns (uint baseZipReserve, uint baseWethReserve) {
        (uint baseReserve0, uint baseReserve1,) = /* returns (uint112, uint112) */ basePool.getReserves();
        (baseZipReserve, baseWethReserve) = swapOrder2(baseReserve0, baseReserve1);
    }

    function getAmountIn(uint amountOut, address tokenIn, address tokenOut) external view returns (uint amountIn) {
        if(tokenIn == address(zip) && tokenOut == address(weth)) {
            (uint localZipIn, uint baseZipIn) = getAmountInSellZip(amountOut);
            return localZipIn+baseZipIn;
        }
        else if(tokenIn == address(weth) && tokenOut == address(zip)) {
            return getAmountInBuyZip(amountOut);
        }
        else revert("ZipswapBuySupport:getAmountIn wrong tokens");
    }

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amountOut) {
        if(tokenIn == address(zip) && tokenOut == address(weth)) {
            (uint baseZipIn, uint localZipIn, uint baseWethOut, uint localWethOut) = getAmountOutSellZip(amountIn);
            return baseWethOut+localWethOut;
        }
        else if(tokenIn == address(weth) && tokenOut == address(zip)) {
            return getAmountOutBuyZip(amountIn);
        }
        else revert("ZipswapBuySupport:getAmountOut wrong tokens");
    }

    function sellZip(uint zipIn, address to) internal returns (uint wethOut) {
        (uint baseZipIn, uint localZipIn, uint baseWethOut, uint localWethOut) = getAmountOutSellZip(zipIn);
        if(baseZipIn > 0) {
            swapWithBasePool(baseZipIn, 0, 0, baseWethOut, to);
        }
        if(localZipIn > 0) {
            weth.transfer(to, localWethOut);
            zip.burn(localZipIn);
            wethReserve -= uint112(localWethOut);
        }
        wethOut = baseWethOut + localWethOut;
    }

    function buyZip(uint wethIn, uint zipOut, address to) internal {
        //redirect all buys to base pool
        swapWithBasePool(0, zipOut, wethIn, 0, to);
    }

    function getAmountOutBuyZip(uint wethIn) internal view returns (uint zipOut) {
        (uint baseZipReserve, uint baseWethReserve) = getBasePoolReserves();
        return uni2GetAmountOut(wethIn, baseWethReserve, baseZipReserve);
    }

    function getAmountInBuyZip(uint zipOut) internal view returns (uint wethIn) {
        (uint baseZipReserve, uint baseWethReserve) = getBasePoolReserves();
        return uni2GetAmountIn(zipOut, baseWethReserve, baseZipReserve);
    }

    function getAmountOutSellZip(uint zipIn) internal view returns (uint baseZipIn, uint localZipIn, uint baseWethOut, uint localWethOut) {
        (uint baseZipReserve, uint baseWethReserve) = getBasePoolReserves();
        uint localWethReserve = wethReserve;
        if(localWethReserve > 0) {
            uint totalZipSupply = zip.totalSupply();
            //this assumes basepool has at least minimum liquidity
            int zipToSellIntoBaseForEqualPrice = getAmountInUntilEqualPrice(baseZipReserve, baseWethReserve, totalZipSupply, localWethReserve);

            if(zipToSellIntoBaseForEqualPrice <= 100) {
                //price in basepool is lower or close enough to not make it worth it
                baseZipIn = 0;
                baseWethOut = 0;
                localZipIn = zipIn;
                localWethOut = localZipIn*localWethReserve/totalZipSupply;
            }
            else {
                //division makes sense
                baseZipIn = Math.min(uint(zipToSellIntoBaseForEqualPrice), zipIn);
                baseWethOut = uni2GetAmountOut(baseZipIn, baseZipReserve, baseWethReserve);
                if(baseWethOut <= 100) {
                    //output too small to bother
                    baseZipIn = 0;
                    baseWethOut = 0;
                }
                localZipIn = zipIn-baseZipIn;
                localWethOut = localZipIn*localWethReserve/totalZipSupply;
            }
        }
        else {
            baseZipIn = zipIn;
            baseWethOut = uni2GetAmountOut(baseZipIn, baseZipReserve, baseWethReserve);
            localZipIn = 0;
            localWethOut = 0;
        }
    }

    function getAmountInSellZip(uint wethOut) internal view returns (uint localZipIn, uint baseZipIn) {
        (uint baseZipReserve, uint baseWethReserve) = getBasePoolReserves();
        uint localWethReserve = wethReserve;
        if(localWethReserve > 0) {
            uint totalZipSupply = zip.totalSupply();
            int zipToSellIntoBaseForEqualPrice = getAmountInUntilEqualPrice(baseZipReserve, baseWethReserve, totalZipSupply, localWethReserve);
            if(zipToSellIntoBaseForEqualPrice <= 100) {
                //price in basepool is lower or close enough to not make it worth it
                localZipIn = wethOut*totalZipSupply/localWethReserve;
                baseZipIn = 0;
            }
            else {
                //division makes sense
                //min() needed so that uni2GetAmountIn doesn't throw - impossible to get more out than the pool has
                uint baseWethOut = Math.min(wethOut, baseWethReserve-1);
                baseZipIn = uni2GetAmountIn(baseWethOut, baseZipReserve, baseWethReserve);
                if(baseZipIn > uint(zipToSellIntoBaseForEqualPrice)) {
                    baseZipIn = uint(zipToSellIntoBaseForEqualPrice);
                    baseWethOut = uni2GetAmountOut(baseZipIn, baseZipReserve, baseWethReserve);
                    if(baseWethOut <= 100) {
                        baseZipIn = 0;
                        baseWethOut = 0;
                    }
                }
                localZipIn = (wethOut-baseWethOut)*totalZipSupply/localWethReserve;
            }
        }
        else {
            localZipIn = 0;
            baseZipIn = uni2GetAmountIn(wethOut, baseZipReserve, baseWethReserve);
        }
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require((amount0Out > 0 && amount1Out == 0) || (amount0Out == 0 && amount1Out > 0), 'ZipswapBuySupport: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint zipOut, uint wethOut) = swapOrder2(amount0Out, amount1Out);
        uint wethIn = 0; uint zipIn = 0;

        if(zipOut > 0) {
            wethIn = weth.balanceOf(address(this)) - wethReserve;
            require(wethIn > 0, 'zero wethIn');
            buyZip(wethIn, zipOut, to);
        }
        else {
            zipIn = zip.balanceOf(address(this));
            require(zipIn > 0, 'zero zipIn');
            uint receivedWeth = sellZip(zipIn, to);
            require(receivedWeth == wethOut, 'incorrect wethOut');
        }

        (uint amount0In, uint amount1In) = swapOrder2(zipIn, wethIn);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    //UTILITY FUNCTIONS

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function uni2GetAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'ZipswapBuySupport:uni2GetAmountOut INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'ZipswapBuySupport:uni2GetAmountOut INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn*997; //amountIn.mul(997);
        uint numerator = amountInWithFee*reserveOut; //amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn*1000+amountInWithFee; //reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function uni2GetAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'ZipswapBuySupport:uni2GetAmountIn INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'ZipswapBuySupport:uni2GetAmountIn INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn*amountOut*1000; //reserveIn.mul(amountOut).mul(1000);
        uint denominator = (reserveOut-amountOut)*997; //reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator)+1;
    }

    function swapOrder2(uint a, uint b) internal view returns (uint, uint) {
        if(zipIsToken0) {
            return (a, b);
        }
        else {
            return (b, a);
        }
    }

    //admin functions

    function withdrawToken(IERC20 _token, address recipient, uint amount) external onlyOwner returns (uint) {
        if(amount == 0) {
            amount = _token.balanceOf(address(this));
        }
        require(_token.transfer(recipient, amount));
        return amount;
    }

    function withdrawEth(address recipient) external onlyOwner {
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "eth transfer failure");
    }

    function sync() external onlyOwner returns (uint) {
        uint112 _wethReserve = uint112(weth.balanceOf(address(this)));
        wethReserve = _wethReserve;
        (uint a, uint b) = swapOrder2(0, _wethReserve);
        emit Sync(uint112(a), uint112(b));
        return _wethReserve;
    }
}

pragma solidity >0.5.16;

// a library for performing various math operations

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

pragma solidity >=0.5.0;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

pragma solidity >=0.5.0;

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function tokens() external view returns (address, address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

abstract contract OwnableAccept {
    address private _owner;
    address private newOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(msg.sender);
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
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address _newOwner) public virtual onlyOwner {
        require(_newOwner != address(0), "Ownable: new owner is the zero address");
        newOwner = _newOwner;
    }

    function acceptOwnership() public virtual {
        require(msg.sender == newOwner, "Ownable: sender != newOwner");
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address _newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }
}