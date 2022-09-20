// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import './interfaces/IFireBirdFactory.sol';
import './interfaces/IFireBirdFormula.sol';
import './interfaces/IFireBirdPair.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './interfaces/IAggregationExecutor.sol';
import './interfaces/IMultihopRouter.sol';
import './interfaces/IRFQ.sol';
import './interfaces/ISwap.sol';
import './interfaces/ISwapFlashLoan.sol';
import './interfaces/ICurve.sol';
import './interfaces/ICurveTriCrypto.sol';
import './libraries/DMMLibrary.sol';
import './interfaces/IUniswapV3Pool.sol';
import './interfaces/IProMMPool.sol';
import './interfaces/IBalancerV2Vault.sol';
import './interfaces/IDODOV1.sol';
import './interfaces/IDODOV2.sol';
import './interfaces/IDODOSellHelper.sol';
import './interfaces/IVelodromePair.sol';
import './interfaces/IGMXVault.sol';
import './interfaces/ISynthetix.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';

contract AggregationExecutor is IAggregationExecutor, IMultihopRouter, Ownable {
  using SafeCast for uint256;
  address public immutable override factory;
  address public immutable override formula;
  address public immutable override WETH;
  address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  /// @dev Transient storage variable used for returning the pool uni v3 address callback swapping
  address private poolSwapCached;
  /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
  uint160 internal constant MIN_SQRT_RATIO = 4295128739;
  /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
  uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
  uint16 internal constant BPS = 10000;

  // fee data in case taking in dest token
  struct DestTokenFeeData {
    address feeReceiver;
    bool isInBps; // true if taking the fee in percentage, with 100% is 1 BPS
    uint256 feeAmount; // in bps unit or in dest token unit
  }

  struct SwapExecutorDescription {
    Swap[][] swapSequences;
    address tokenIn;
    address tokenOut;
    uint256 minTotalAmountOut;
    address to;
    uint256 deadline;
    bytes destTokenFeeData;
  }

  modifier ensure(uint256 deadline) {
    require(deadline >= block.timestamp, 'Router: EXPIRED');
    _;
  }

  constructor(
    address _factory,
    address _formula,
    address _WETH
  ) {
    factory = _factory;
    formula = _formula;
    WETH = _WETH;
  }

  receive() external payable {}

  // **** SWAP ****
  function multihopBatchSwapExactIn(
    Swap[][] memory swapSequences,
    address tokenIn,
    address tokenOut,
    uint256 minTotalAmountOut,
    address to,
    uint256 deadline,
    bytes memory destTokenFeeData
  ) public payable virtual override ensure(deadline) returns (uint256 totalAmountOut) {
    if (isETH(tokenIn)) {
      IWETH(WETH).deposit{value: msg.value}();
    }

    uint256 balanceBefore;
    if (!isETH(tokenOut)) {
      balanceBefore = IERC20(tokenOut).balanceOf(to);
    }

    for (uint256 i = 0; i < swapSequences.length; i++) {
      uint256 tokenAmountOut;
      for (uint256 k = 0; k < swapSequences[i].length; k++) {
        tokenAmountOut = _swapSinglePool(swapSequences[i][k], k, tokenAmountOut, deadline);
      }

      // This takes the amountOut of the last swap
      totalAmountOut = tokenAmountOut + totalAmountOut;
    }

    uint256 tokenOutBalance = getBalance(tokenOut);
    // make only one unwrap
    if (isETH(tokenOut)) IWETH(WETH).withdraw(tokenOutBalance);

    if (destTokenFeeData.length > 0) {
      // taking fee in dest token, assume tokenOut should have been transferred to this Executor first
      DestTokenFeeData memory feeData = abi.decode(destTokenFeeData, (DestTokenFeeData));
      feeData.feeAmount = feeData.feeReceiver == address(0) ? 0 : feeData.isInBps
        ? (feeData.feeAmount * totalAmountOut) / BPS
        : feeData.feeAmount;
      totalAmountOut -= feeData.feeAmount;
      tokenOutBalance -= feeData.feeAmount;
      transferToken(tokenOut, feeData.feeReceiver, feeData.feeAmount, false);
    }
    transferToken(tokenOut, to, tokenOutBalance, false);
    transferToken(tokenIn, to, getBalance(tokenIn), true);

    if (isETH(tokenOut)) {
      require(totalAmountOut >= minTotalAmountOut, 'ERR_LIMIT_OUT');
    } else {
      require(IERC20(tokenOut).balanceOf(to) - balanceBefore >= minTotalAmountOut, '<minTotalAmountOut');
    }
  }

  function _executeUniSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut,
    uint8 dexId
  ) internal returns (uint256 tokenAmountOut) {
    UniSwap memory uniSwap = abi.decode(data, (UniSwap));
    // no need to transfer if the collectAmount is set to 0

    uniSwap.collectAmount = uniSwap.collectAmount == 0
      ? 0
      : getSwapAmount(index, previousAmountOut, uniSwap.tokenIn, uniSwap.collectAmount);

    tokenAmountOut = _swapSingleSupportFeeOnTransferTokens(uniSwap, dexId);
  }

  function _executeStableSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut,
    uint256 deadline,
    uint8 stableDexType
  ) internal returns (uint256 tokenAmountOut) {
    StableSwap memory stableSwap = abi.decode(data, (StableSwap));
    uint256 balanceBefore = IERC20(stableSwap.tokenTo).balanceOf(address(this));
    stableSwap.dx = getSwapAmount(index, previousAmountOut, stableSwap.tokenFrom, stableSwap.dx);

    TransferHelper.safeApprove(stableSwap.tokenFrom, stableSwap.pool, stableSwap.dx);
    if (stableSwap.poolLp == stableSwap.tokenFrom) {
      //remove liq
      ISwap(stableSwap.pool).removeLiquidityOneToken(
        stableSwap.dx,
        stableSwap.tokenIndexTo,
        stableSwap.minDy,
        deadline
      );
    } else if (stableSwap.poolLp == stableSwap.tokenTo) {
      //add liq
      uint256[] memory base_amounts = new uint256[](stableSwap.poolLength);
      base_amounts[stableSwap.tokenIndexFrom] = stableSwap.dx;

      if (stableDexType == uint8(DexType.SADDLE)) {
        ISwapFlashLoan(stableSwap.pool).addLiquidity(base_amounts, stableSwap.minDy, deadline, new bytes32[](0));
      } else {
        ISwap(stableSwap.pool).addLiquidity(base_amounts, stableSwap.minDy, deadline);
      }
    } else {
      //swap within pool
      ISwap(stableSwap.pool).swap(
        stableSwap.tokenIndexFrom,
        stableSwap.tokenIndexTo,
        stableSwap.dx,
        stableSwap.minDy,
        deadline
      );
    }

    tokenAmountOut = IERC20(stableSwap.tokenTo).balanceOf(address(this)) - balanceBefore;
    emit Exchange(stableSwap.pool, tokenAmountOut, stableSwap.tokenTo);
  }

  function _executeCurveSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    CurveSwap memory curveSwap = abi.decode(data, (CurveSwap));
    uint256 balanceBefore = getBalanceNative(curveSwap.tokenTo);

    curveSwap.dx = getSwapAmount(index, previousAmountOut, curveSwap.tokenFrom, curveSwap.dx);
    ICurve pool = ICurve(curveSwap.pool);

    uint256 valueETH;
    if (isETH(curveSwap.tokenFrom)) {
      IWETH(WETH).withdraw(curveSwap.dx);
      valueETH = curveSwap.dx;
    } else {
      TransferHelper.safeApprove(curveSwap.tokenFrom, curveSwap.pool, curveSwap.dx);
    }

    if (curveSwap.useTriCrypto) {
      if (curveSwap.usePoolUnderlying) {
        ICurveTriCrypto(curveSwap.pool).exchange_underlying{value: valueETH}(
          uint256(uint128(curveSwap.tokenIndexFrom)),
          uint256(uint128(curveSwap.tokenIndexTo)),
          curveSwap.dx,
          curveSwap.minDy
        );
      } else {
        ICurveTriCrypto(curveSwap.pool).exchange{value: valueETH}(
          uint256(uint128(curveSwap.tokenIndexFrom)),
          uint256(uint128(curveSwap.tokenIndexTo)),
          curveSwap.dx,
          curveSwap.minDy
        );
      }
    } else {
      if (curveSwap.usePoolUnderlying) {
        pool.exchange_underlying{value: valueETH}(
          curveSwap.tokenIndexFrom,
          curveSwap.tokenIndexTo,
          curveSwap.dx,
          curveSwap.minDy
        );
      } else {
        pool.exchange{value: valueETH}(
          curveSwap.tokenIndexFrom,
          curveSwap.tokenIndexTo,
          curveSwap.dx,
          curveSwap.minDy
        );
      }
    }

    tokenAmountOut = getBalanceNative(curveSwap.tokenTo) - balanceBefore;
    if (isETH(curveSwap.tokenTo)) {
      IWETH(WETH).deposit{value: tokenAmountOut}();
    }
    emit Exchange(curveSwap.pool, tokenAmountOut, curveSwap.tokenTo);
  }

  function _executeKyberDMMSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    UniSwap memory kyberDMMSwap = abi.decode(data, (UniSwap));
    // no need to transfer if the collectAmount is set to 0
    kyberDMMSwap.collectAmount = kyberDMMSwap.collectAmount == 0
      ? 0
      : getSwapAmount(index, previousAmountOut, kyberDMMSwap.tokenIn, kyberDMMSwap.collectAmount);

    tokenAmountOut = _swapKyberDMMSupportFeeOnTransferTokens(kyberDMMSwap);
  }

  function _executeUniV3ProMMSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    UniSwapV3ProMM memory uniSwapV3ProMM = abi.decode(data, (UniSwapV3ProMM));
    uniSwapV3ProMM.swapAmount = getSwapAmount(
      index,
      previousAmountOut,
      uniSwapV3ProMM.tokenIn,
      uniSwapV3ProMM.swapAmount
    );

    SwapCallbackDataPath memory swapCallbackDataPath = SwapCallbackDataPath(
      uniSwapV3ProMM.pool,
      uniSwapV3ProMM.tokenIn,
      uniSwapV3ProMM.tokenOut
    );
    SwapCallbackData memory swapCallbackData = SwapCallbackData({
      path: abi.encode(swapCallbackDataPath),
      payer: address(this)
    });
    poolSwapCached = uniSwapV3ProMM.pool;
    uint256 amountOutput;
    int256 amount0;
    int256 amount1;
    bool swapDirection = uniSwapV3ProMM.tokenIn < uniSwapV3ProMM.tokenOut;
    address recipient = uniSwapV3ProMM.recipient == address(0) ? address(this) : uniSwapV3ProMM.recipient;
    uint256 balanceBefore = IERC20(uniSwapV3ProMM.tokenOut).balanceOf(recipient);
    if (uniSwapV3ProMM.isUniV3) {
      (amount0, amount1) = IUniswapV3Pool(uniSwapV3ProMM.pool).swap(
        recipient,
        swapDirection,
        uniSwapV3ProMM.swapAmount.toInt256(),
        uniSwapV3ProMM.sqrtPriceLimitX96 == 0
          ? (swapDirection ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1)
          : uniSwapV3ProMM.sqrtPriceLimitX96,
        abi.encode(swapCallbackData)
      );
    } else {
      (amount0, amount1) = IProMMPool(uniSwapV3ProMM.pool).swap(
        recipient,
        uniSwapV3ProMM.swapAmount.toInt256(),
        swapDirection,
        uniSwapV3ProMM.sqrtPriceLimitX96 == 0
          ? (swapDirection ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1)
          : uniSwapV3ProMM.sqrtPriceLimitX96,
        abi.encode(swapCallbackData)
      );
    }

    amountOutput = uint256(-(swapDirection ? amount1 : amount0));
    emit Exchange(uniSwapV3ProMM.pool, amountOutput, uniSwapV3ProMM.tokenOut);

    tokenAmountOut = IERC20(uniSwapV3ProMM.tokenOut).balanceOf(recipient) - balanceBefore;
    require(tokenAmountOut >= uniSwapV3ProMM.limitReturnAmount, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
  }

  function _executeRfqSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    KyberRFQ memory kyberRFQ;
    {
      // can't use the KyberRFQ struct for decoding because of bytes type
      // hence must explicitly specify types and assign to variable
      (address rfq, bytes memory order, bytes memory signature, uint256 amount, address payable target) = abi.decode(
        data,
        (address, bytes, bytes, uint256, address)
      );
      kyberRFQ.rfq = rfq;
      kyberRFQ.order = order;
      kyberRFQ.signature = signature;
      kyberRFQ.amount = amount;
      kyberRFQ.target = target;
    }
    IRFQ.OrderRFQ memory orderRFQ = abi.decode(kyberRFQ.order, (IRFQ.OrderRFQ));
    uint256 balanceBefore = IERC20(orderRFQ.makerAsset).balanceOf(kyberRFQ.target);
    uint256 actualTakerAmount = getSwapAmount(index, previousAmountOut, orderRFQ.takerAsset, kyberRFQ.amount);
    TransferHelper.safeApprove(orderRFQ.takerAsset, kyberRFQ.rfq, actualTakerAmount);
    IRFQ(kyberRFQ.rfq).fillOrderRFQTo(orderRFQ, kyberRFQ.signature, 0, actualTakerAmount, kyberRFQ.target);
    tokenAmountOut = IERC20(orderRFQ.makerAsset).balanceOf(kyberRFQ.target) - balanceBefore;

    emit Exchange(kyberRFQ.rfq, tokenAmountOut, orderRFQ.makerAsset);
  }

  function uniswapV3SwapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata _data
  ) external {
    _handleSwapCallback(amount0Delta, amount1Delta, _data);
  }

  function swapCallback(
    int256 deltaQty0,
    int256 deltaQty1,
    bytes calldata data
  ) external {
    _handleSwapCallback(deltaQty0, deltaQty1, data);
  }

  function _handleSwapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata _data
  ) internal {
    require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
    require(msg.sender == address(poolSwapCached), 'Router: invalid sender callback');

    SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
    SwapCallbackDataPath memory dataPath = abi.decode(data.path, (SwapCallbackDataPath));

    uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
    // pay with tokens already in the contract (for the exact input multihop case)
    TransferHelper.safeTransfer(dataPath.tokenIn, msg.sender, amountToPay);
  }

  function _executeBalV2Swap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut,
    uint256 deadline
  ) internal returns (uint256 tokenAmountOut) {
    BalancerV2 memory balancerV2 = abi.decode(data, (BalancerV2));
    uint256 balanceBefore = IERC20(balancerV2.assetOut).balanceOf(address(this));
    balancerV2.amount = getSwapAmount(index, previousAmountOut, balancerV2.assetIn, balancerV2.amount);

    TransferHelper.safeApprove(balancerV2.assetIn, balancerV2.vault, balancerV2.amount);

    IBalancerV2Vault.SingleSwap memory singleSwap = IBalancerV2Vault.SingleSwap(
      balancerV2.poolId,
      IBalancerV2Vault.SwapKind.GIVEN_IN,
      balancerV2.assetIn,
      balancerV2.assetOut,
      balancerV2.amount,
      new bytes(0)
    );
    IBalancerV2Vault.FundManagement memory funds = IBalancerV2Vault.FundManagement(
      address(this),
      false,
      address(this),
      false
    );
    uint256 amountOutput = IBalancerV2Vault(balancerV2.vault).swap(singleSwap, funds, balancerV2.limit, deadline);

    emit Exchange(address(uint160(uint256(balancerV2.poolId) >> (12 * 8))), amountOutput, balancerV2.assetOut);
    tokenAmountOut = IERC20(balancerV2.assetOut).balanceOf(address(this)) - balanceBefore;
  }

  function _executeDODOSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    DODO memory dodo = abi.decode(data, (DODO));
    address recipient = dodo.recipient == address(0) ? address(this) : dodo.recipient;
    uint256 balanceBefore = IERC20(dodo.tokenTo).balanceOf(recipient);
    dodo.amount = getSwapAmount(index, previousAmountOut, dodo.tokenFrom, dodo.amount);

    if (dodo.isVersion2) {
      TransferHelper.safeTransfer(dodo.tokenFrom, dodo.pool, dodo.amount);
      if (dodo.isSellBase) {
        IDODOV2(dodo.pool).sellBase(recipient);
      } else {
        IDODOV2(dodo.pool).sellQuote(recipient);
      }
    } else {
      TransferHelper.safeApprove(dodo.tokenFrom, dodo.pool, dodo.amount);
      if (dodo.isSellBase) {
        IDODOV1(dodo.pool).sellBaseToken(dodo.amount, dodo.minReceiveQuote, '');
      } else {
        uint256 canBuyBaseAmount = IDODOSellHelper(dodo.sellHelper).querySellQuoteToken(dodo.pool, dodo.amount);
        IDODOV1(dodo.pool).buyBaseToken(canBuyBaseAmount, dodo.amount, '');
      }
    }
    tokenAmountOut = IERC20(dodo.tokenTo).balanceOf(recipient) - balanceBefore;
    emit Exchange(dodo.pool, tokenAmountOut, dodo.tokenTo);
  }

  function _executeVelodromeSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    UniSwap memory velodrome = abi.decode(data, (UniSwap));

    velodrome.collectAmount = velodrome.collectAmount == 0
      ? 0
      : getSwapAmount(index, previousAmountOut, velodrome.tokenIn, velodrome.collectAmount);

    if (velodrome.collectAmount > 0) {
      TransferHelper.safeTransfer(velodrome.tokenIn, velodrome.pool, velodrome.collectAmount);
    }

    uint256 reserveTokenIn = velodrome.tokenIn == IVelodromePair(velodrome.pool).token0()
      ? IVelodromePair(velodrome.pool).reserve0()
      : IVelodromePair(velodrome.pool).reserve1();

    uint256 amountIn = IERC20(velodrome.tokenIn).balanceOf(velodrome.pool) - reserveTokenIn;
    tokenAmountOut = IVelodromePair(velodrome.pool).getAmountOut(amountIn, velodrome.tokenIn);

    address recipient = velodrome.recipient == address(0) ? address(this) : velodrome.recipient;

    velodrome.tokenIn < velodrome.tokenOut
      ? IVelodromePair(velodrome.pool).swap(uint256(0), tokenAmountOut, recipient, new bytes(0))
      : IVelodromePair(velodrome.pool).swap(tokenAmountOut, uint256(0), recipient, new bytes(0));

    emit Exchange(velodrome.pool, tokenAmountOut, velodrome.tokenOut);
  }

  function _executeGMXSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    GMX memory gmx = abi.decode(data, (GMX));
    gmx.amount = getSwapAmount(index, previousAmountOut, gmx.tokenIn, gmx.amount);
    address receiver = gmx.receiver == address(0) ? address(this) : gmx.receiver;
    uint256 balanceBefore = IERC20(gmx.tokenOut).balanceOf(receiver);

    if (gmx.amount > 0) {
      // transfer tokenIn to vault
      transferToken(gmx.tokenIn, gmx.vault, gmx.amount, false);
    }

    // execute swap and verify amount out
    uint256 amountOut = IGMXVault(gmx.vault).swap(gmx.tokenIn, gmx.tokenOut, receiver);
    require(gmx.minOut <= amountOut, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
    emit Exchange(gmx.vault, amountOut, gmx.tokenOut);
    tokenAmountOut = IERC20(gmx.tokenOut).balanceOf(receiver) - balanceBefore;
  }

  function _executeSynthetixSwap(
    uint256 index,
    bytes memory data,
    uint256 previousAmountOut
  ) internal returns (uint256 tokenAmountOut) {
    Synthetix memory synthetix = abi.decode(data, (Synthetix));

    synthetix.sourceAmount = getSwapAmount(index, previousAmountOut, synthetix.tokenIn, synthetix.sourceAmount);
    if (synthetix.useAtomicExchange) {
      tokenAmountOut = ISynthetix(synthetix.synthetixProxy).exchangeAtomically(
        synthetix.sourceCurrencyKey,
        synthetix.sourceAmount,
        synthetix.destinationCurrencyKey,
        bytes32(0),
        synthetix.minAmount
      );
    } else {
      tokenAmountOut = ISynthetix(synthetix.synthetixProxy).exchange(
        synthetix.sourceCurrencyKey,
        synthetix.sourceAmount,
        synthetix.destinationCurrencyKey
      );
    }

    emit Exchange(synthetix.synthetixProxy, tokenAmountOut, synthetix.tokenOut);
  }

  function getBalance(address token) internal view returns (uint256) {
    if (isETH(token)) {
      return IWETH(WETH).balanceOf(address(this));
    } else {
      return IERC20(token).balanceOf(address(this));
    }
  }

  function _swapSingleSupportFeeOnTransferTokens(UniSwap memory swapData, uint8 dexId)
    internal
    returns (uint256 tokenAmountOut)
  {
    if (swapData.collectAmount > 0) {
      TransferHelper.safeTransfer(swapData.tokenIn, swapData.pool, swapData.collectAmount);
    }

    uint256 amountOutput;
    {
      (, uint256 reserveInput, uint256 reserveOutput, uint32 tokenWeightInput, , uint32 swapFee) = IFireBirdFormula(
        formula
      ).getFactoryReserveAndWeights(factory, swapData.pool, swapData.tokenIn, dexId);
      uint256 amountInput = IERC20(swapData.tokenIn).balanceOf(swapData.pool) - reserveInput;
      amountOutput = IFireBirdFormula(formula).getAmountOut(
        amountInput,
        reserveInput,
        reserveOutput,
        tokenWeightInput,
        100 - tokenWeightInput,
        swapFee
      );
    }

    address recipient = swapData.recipient == address(0) ? address(this) : swapData.recipient;

    uint256 balanceBefore = IERC20(swapData.tokenOut).balanceOf(recipient);

    if (swapData.tokenIn == IFireBirdPair(swapData.pool).token0()) {
      IFireBirdPair(swapData.pool).swap(0, amountOutput, recipient, new bytes(0));
    } else {
      IFireBirdPair(swapData.pool).swap(amountOutput, 0, recipient, new bytes(0));
    }
    emit Exchange(swapData.pool, amountOutput, swapData.tokenOut);

    tokenAmountOut = IERC20(swapData.tokenOut).balanceOf(recipient) - balanceBefore;

    require(tokenAmountOut >= swapData.limitReturnAmount, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
  }

  function _swapKyberDMMSupportFeeOnTransferTokens(UniSwap memory swapData) internal returns (uint256 tokenAmountOut) {
    if (swapData.collectAmount > 0) {
      TransferHelper.safeTransfer(swapData.tokenIn, swapData.pool, swapData.collectAmount);
    }

    uint256 amountOutput;
    {
      // scope to avoid stack too deep errors
      (
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 vReserveIn,
        uint256 vReserveOut,
        uint256 feeInPrecision
      ) = DMMLibrary.getTradeInfo(swapData.pool, IERC20(swapData.tokenIn), IERC20(swapData.tokenOut));
      uint256 amountInput = IERC20(swapData.tokenIn).balanceOf(address(swapData.pool)) - reserveIn;
      amountOutput = DMMLibrary.getAmountOut(
        amountInput,
        reserveIn,
        reserveOut,
        vReserveIn,
        vReserveOut,
        feeInPrecision
      );
    }
    address recipient = swapData.recipient == address(0) ? address(this) : swapData.recipient;

    uint256 balanceBefore = IERC20(swapData.tokenOut).balanceOf(recipient);
    if (swapData.tokenIn == IFireBirdPair(swapData.pool).token0()) {
      IFireBirdPair(swapData.pool).swap(0, amountOutput, recipient, new bytes(0));
    } else {
      IFireBirdPair(swapData.pool).swap(amountOutput, 0, recipient, new bytes(0));
    }
    emit Exchange(swapData.pool, amountOutput, swapData.tokenOut);

    tokenAmountOut = IERC20(swapData.tokenOut).balanceOf(recipient) - balanceBefore;
    require(tokenAmountOut >= swapData.limitReturnAmount, 'Router: INSUFFICIENT_OUTPUT_AMOUNT');
  }

  function getSwapAmount(
    uint256 index,
    uint256 previousAmountOut,
    address tokenSwap,
    uint256 amountIn
  ) internal view returns (uint256) {
    uint256 _currentBalance = getBalance(tokenSwap);

    // tokens may have been transferred directly to the pool in case of uni type
    if (_currentBalance == 0) return 0;
    if (index > 0) {
      // Makes sure that on the second swap the output of the first was used
      // so there is not intermediate token leftover
      return previousAmountOut;
    } else {
      // if current balance less than swap amount, use less (in case of deflating token)
      if (amountIn > _currentBalance) {
        return _currentBalance;
      }
    }
    return amountIn;
  }

  function getBalanceNative(address token) internal view returns (uint256) {
    if (isETH(token)) {
      return address(this).balance;
    } else {
      return IERC20(token).balanceOf(address(this));
    }
  }

  function transferToken(
    address token,
    address to,
    uint256 amount,
    bool needUnwrap
  ) internal {
    if (amount == 0) return;
    if (isETH(token)) {
      if (needUnwrap) IWETH(WETH).withdraw(amount);
      TransferHelper.safeTransferETH(to, amount);
    } else {
      TransferHelper.safeTransfer(token, to, amount);
    }
  }

  function isETH(address token) internal pure returns (bool) {
    return (token == ETH_ADDRESS);
  }

  function callBytes(bytes calldata data) external payable override {
    SwapExecutorDescription memory swapExecutorDescription = abi.decode(data, (SwapExecutorDescription));

    multihopBatchSwapExactIn(
      swapExecutorDescription.swapSequences,
      swapExecutorDescription.tokenIn,
      swapExecutorDescription.tokenOut,
      swapExecutorDescription.minTotalAmountOut,
      swapExecutorDescription.to,
      swapExecutorDescription.deadline,
      swapExecutorDescription.destTokenFeeData
    );
  }

  // Swap a single sequence, only works when:
  // 1. the tokenIn is not the native token
  // 2. the first pool of each sequence should be able to receive the token before calling swap
  function swapSingleSequence(bytes calldata data) external override {
    Swap[] memory swapData = abi.decode(data, (Swap[]));
    uint8 dexType = uint8(swapData[0].dexOption >> 8);
    // the first pool must be able to receive the token before calling swap func,
    // i.e: UNI, DMM types

    require(
      dexType == uint8(DexType.UNI) ||
        dexType == uint8(DexType.KYBERDMM) ||
        dexType == uint8(DexType.VELODROME) ||
        dexType == uint8(DexType.GMX),
      'AggregationExecutor: Wrong first pool dex type'
    );
    uint256 tokenAmountOut;
    for (uint256 i = 0; i < swapData.length; i++) {
      tokenAmountOut = _swapSinglePool(swapData[i], i, tokenAmountOut, block.timestamp + 100);
    }
  }

  // finalize all information after swap
  // in case taking fee in dest token, transfer fee to the fee receiver
  function finalTransactionProcessing(
    address tokenIn,
    address tokenOut,
    address to,
    bytes calldata destTokenFeeData
  ) external override {
    uint256 tokenOutBalance = getBalance(tokenOut);
    // make only one unwrap
    if (isETH(tokenOut)) IWETH(WETH).withdraw(tokenOutBalance);

    if (destTokenFeeData.length > 0) {
      // taking fee in dest token, assume tokenOut should have been transferred to this Executor first
      DestTokenFeeData memory feeData = abi.decode(destTokenFeeData, (DestTokenFeeData));
      feeData.feeAmount = feeData.feeReceiver == address(0) ? 0 : feeData.isInBps
        ? (feeData.feeAmount * tokenOutBalance) / BPS
        : feeData.feeAmount;
      tokenOutBalance -= feeData.feeAmount;
      transferToken(tokenOut, feeData.feeReceiver, feeData.feeAmount, false);
    }

    transferToken(tokenOut, to, tokenOutBalance, false);
    transferToken(tokenIn, to, getBalance(tokenIn), true);
  }

  function rescueFunds(address token, uint256 amount) external onlyOwner {
    if (isETH(token)) {
      TransferHelper.safeTransferETH(msg.sender, amount);
    } else {
      TransferHelper.safeTransfer(token, msg.sender, amount);
    }
  }

  function _swapSinglePool(
    Swap memory swap,
    uint256 index,
    uint256 tokenAmountOut,
    uint256 deadline
  ) internal returns (uint256) {
    uint8 dexType = uint8(swap.dexOption >> 8);
    if (dexType == uint8(DexType.UNI)) {
      return _executeUniSwap(index, swap.data, tokenAmountOut, uint8(swap.dexOption));
    } else if (dexType == uint8(DexType.STABLESWAP) || dexType == uint8(DexType.SADDLE)) {
      return _executeStableSwap(index, swap.data, tokenAmountOut, deadline, dexType);
    } else if (dexType == uint8(DexType.CURVE)) {
      return _executeCurveSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.KYBERDMM)) {
      return _executeKyberDMMSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.UNIV3PROMM)) {
      return _executeUniV3ProMMSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.BALANCERV2)) {
      return _executeBalV2Swap(index, swap.data, tokenAmountOut, deadline);
    } else if (dexType == uint8(DexType.KYBERRFQ)) {
      return _executeRfqSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.DODO)) {
      return _executeDODOSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.VELODROME)) {
      return _executeVelodromeSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.GMX)) {
      return _executeGMXSwap(index, swap.data, tokenAmountOut);
    } else if (dexType == uint8(DexType.SYNTHETIX)) {
      return _executeSynthetixSwap(index, swap.data, tokenAmountOut);
    } else {
      revert('AggregationExecutor: Dex type not supported');
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IFireBirdFactory {
  event PairCreated(
    address indexed token0,
    address indexed token1,
    address pair,
    uint32 tokenWeight0,
    uint32 swapFee,
    uint256
  );

  function feeTo() external view returns (address);

  function formula() external view returns (address);

  function protocolFee() external view returns (uint256);

  function feeToSetter() external view returns (address);

  function getPair(
    address tokenA,
    address tokenB,
    uint32 tokenWeightA,
    uint32 swapFee
  ) external view returns (address pair);

  function allPairs(uint256) external view returns (address pair);

  function isPair(address) external view returns (bool);

  function allPairsLength() external view returns (uint256);

  function createPair(
    address tokenA,
    address tokenB,
    uint32 tokenWeightA,
    uint32 swapFee
  ) external returns (address pair);

  function getWeightsAndSwapFee(address pair)
    external
    view
    returns (
      uint32 tokenWeight0,
      uint32 tokenWeight1,
      uint32 swapFee
    );

  function setFeeTo(address) external;

  function setFeeToSetter(address) external;

  function setProtocolFee(uint256) external;
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >=0.5.16;

/*
    Bancor Formula interface
*/
interface IFireBirdFormula {
  function getFactoryReserveAndWeights(
    address factory,
    address pair,
    address tokenA,
    uint8 dexId
  )
    external
    view
    returns (
      address tokenB,
      uint256 reserveA,
      uint256 reserveB,
      uint32 tokenWeightA,
      uint32 tokenWeightB,
      uint32 swapFee
    );

  function getFactoryWeightsAndSwapFee(
    address factory,
    address pair,
    uint8 dexId
  )
    external
    view
    returns (
      uint32 tokenWeight0,
      uint32 tokenWeight1,
      uint32 swapFee
    );

  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut,
    uint32 tokenWeightIn,
    uint32 tokenWeightOut,
    uint32 swapFee
  ) external view returns (uint256 amountIn);

  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut,
    uint32 tokenWeightIn,
    uint32 tokenWeightOut,
    uint32 swapFee
  ) external view returns (uint256 amountOut);

  function getFactoryAmountsIn(
    address factory,
    address tokenIn,
    address tokenOut,
    uint256 amountOut,
    address[] calldata path,
    uint8[] calldata dexIds
  ) external view returns (uint256[] memory amounts);

  function getFactoryAmountsOut(
    address factory,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address[] calldata path,
    uint8[] calldata dexIds
  ) external view returns (uint256[] memory amounts);

  function ensureConstantValue(
    uint256 reserve0,
    uint256 reserve1,
    uint256 balance0Adjusted,
    uint256 balance1Adjusted,
    uint32 tokenWeight0
  ) external view returns (bool);

  function getReserves(
    address pair,
    address tokenA,
    address tokenB
  ) external view returns (uint256 reserveA, uint256 reserveB);

  function getOtherToken(address pair, address tokenA) external view returns (address tokenB);

  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) external pure returns (uint256 amountB);

  function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

  function mintLiquidityFee(
    uint256 totalLiquidity,
    uint112 reserve0,
    uint112 reserve1,
    uint32 tokenWeight0,
    uint32 tokenWeight1,
    uint112 collectedFee0,
    uint112 collectedFee1
  ) external view returns (uint256 amount);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IFireBirdPair {
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external pure returns (uint8);

  function totalSupply() external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external pure returns (bytes32);

  function nonces(address owner) external view returns (uint256);

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  event PaidProtocolFee(uint112 collectedFee0, uint112 collectedFee1);
  event Mint(address indexed sender, uint256 amount0, uint256 amount1);
  event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
  event Swap(
    address indexed sender,
    uint256 amount0In,
    uint256 amount1In,
    uint256 amount0Out,
    uint256 amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint256);

  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves()
    external
    view
    returns (
      uint112 reserve0,
      uint112 reserve1,
      uint32 blockTimestampLast
    );

  function getCollectedFees() external view returns (uint112 _collectedFee0, uint112 _collectedFee1);

  function getTokenWeights() external view returns (uint32 tokenWeight0, uint32 tokenWeight1);

  function getSwapFee() external view returns (uint32);

  function price0CumulativeLast() external view returns (uint256);

  function price1CumulativeLast() external view returns (uint256);

  function mint(address to) external returns (uint256 liquidity);

  function burn(address to) external returns (uint256 amount0, uint256 amount1);

  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;

  function skim(address to) external;

  function sync() external;

  function initialize(
    address,
    address,
    uint32,
    uint32
  ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.5.16;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
  function safeApprove(
    address token,
    address to,
    uint256 value
  ) internal {
    // bytes4(keccak256(bytes('approve(address,uint256)')));
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
  }

  function safeTransfer(
    address token,
    address to,
    uint256 value
  ) internal {
    // bytes4(keccak256(bytes('transfer(address,uint256)')));
    if (value == 0) return;
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
  }

  function safeTransferFrom(
    address token,
    address from,
    address to,
    uint256 value
  ) internal {
    // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
    if (value == 0) return;
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
  }

  function safeTransferETH(address to, uint256 value) internal {
    if (value == 0) return;
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IERC20 {
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function totalSupply() external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IWETH {
  function deposit() external payable;

  function transfer(address to, uint256 value) external returns (bool);

  function withdraw(uint256) external;

  function balanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IAggregationExecutor {
  function callBytes(bytes calldata data) external payable; // 0xd9c45357

  // callbytes per swap sequence
  function swapSingleSequence(bytes calldata data) external;

  function finalTransactionProcessing(
    address tokenIn,
    address tokenOut,
    address to,
    bytes calldata destTokenFeeData
  ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;

pragma abicoder v2;

interface IMultihopRouter {
  enum DexType {
    UNI,
    STABLESWAP,
    CURVE,
    KYBERDMM,
    SADDLE,
    UNIV3PROMM,
    BALANCERV2,
    KYBERRFQ,
    DODO,
    VELODROME,
    PLATYPUS,
    GMX,
    SYNTHETIX
  }

  event Exchange(address pair, uint256 amountOut, address output);
  struct Swap {
    bytes data;
    //dexType:
    //  0: uni
    //  1: stable swap
    //  2: curve
    //  3: kyber dmm
    //  4: saddle
    //  5: univ3 or kyber ProMM
    //  6: balancerv2
    //  7: kyber RFQ
    //  8: dodo
    //  9: velodrome
    //  10: platypus
    //  11: gmx
    //  12: synthetix
    //dexId:
    //  0: firebird
    uint16 dexOption; //dexType(8bit) + dexId(8bit)
  }

  struct UniSwap {
    address pool;
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 collectAmount; // amount that should be transferred to the pool
    uint256 limitReturnAmount;
  }

  struct StableSwap {
    address pool;
    address tokenFrom;
    address tokenTo;
    uint8 tokenIndexFrom;
    uint8 tokenIndexTo;
    uint256 dx;
    uint256 minDy;
    uint256 poolLength;
    address poolLp;
  }

  struct CurveSwap {
    address pool;
    address tokenFrom;
    address tokenTo;
    int128 tokenIndexFrom;
    int128 tokenIndexTo;
    uint256 dx;
    uint256 minDy;
    bool usePoolUnderlying;
    bool useTriCrypto;
  }

  struct UniSwapV3ProMM {
    address recipient;
    address pool;
    address tokenIn;
    address tokenOut;
    uint256 swapAmount;
    uint256 limitReturnAmount;
    uint160 sqrtPriceLimitX96;
    bool isUniV3; // true = UniV3, false = ProMM
  }
  struct SwapCallbackData {
    bytes path;
    address payer;
  }
  struct SwapCallbackDataPath {
    address pool;
    address tokenIn;
    address tokenOut;
  }

  struct BalancerV2 {
    address vault;
    bytes32 poolId;
    address assetIn;
    address assetOut;
    uint256 amount;
    uint256 limit;
  }

  struct KyberRFQ {
    address rfq;
    bytes order;
    bytes signature;
    uint256 amount;
    address payable target;
  }

  struct DODO {
    address recipient;
    address pool;
    address tokenFrom;
    address tokenTo;
    uint256 amount;
    uint256 minReceiveQuote;
    address sellHelper;
    bool isSellBase;
    bool isVersion2;
  }

  struct GMX {
    address vault;
    address tokenIn;
    address tokenOut;
    uint256 amount;
    uint256 minOut;
    address receiver;
  }

  struct Synthetix {
    address synthetixProxy;
    address tokenIn;
    address tokenOut;
    bytes32 sourceCurrencyKey;
    uint256 sourceAmount;
    bytes32 destinationCurrencyKey;
    uint256 minAmount;
    bool useAtomicExchange;
  }

  function factory() external view returns (address);

  function formula() external view returns (address);

  function WETH() external view returns (address);

  function multihopBatchSwapExactIn(
    Swap[][] memory swapSequences,
    address tokenIn,
    address tokenOut,
    uint256 minTotalAmountOut,
    address to,
    uint256 deadline,
    bytes memory destTokenFeeData
  ) external payable returns (uint256 totalAmountOut);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;
pragma abicoder v2;

interface IRFQ {
  struct OrderRFQ {
    // lowest 64 bits is the order id, next 64 bits is the expiration timestamp
    // highest bit is unwrap WETH flag which is set on taker's side
    // [unwrap eth(1 bit) | unused (127 bits) | expiration timestamp(64 bits) | orderId (64 bits)]
    uint256 info;
    address makerAsset;
    address takerAsset;
    address maker;
    address allowedSender; // null address on public orders
    uint256 makingAmount;
    uint256 takingAmount;
  }

  /// @notice Fills an order's quote, either fully or partially
  /// @dev Funds will be sent to msg.sender
  /// @param order Order quote to fill
  /// @param signature Signature to confirm quote ownership
  /// @param makingAmount Maker amount
  /// @param takingAmount Taker amount
  function fillOrderRFQ(
    OrderRFQ memory order,
    bytes calldata signature,
    uint256 makingAmount,
    uint256 takingAmount
  )
    external
    payable
    returns (
      uint256, /* actualmakingAmount */
      uint256 /* actualtakingAmount */
    );

  /// @notice Main function for fulfilling orders
  /// @param order Order quote to fill
  /// @param signature Signature to confirm quote ownership
  /// @param makingAmount Maker amount
  /// @param takingAmount Taker amount
  /// @param target Address that will receive swapped funds
  function fillOrderRFQTo(
    OrderRFQ memory order,
    bytes calldata signature,
    uint256 makingAmount,
    uint256 takingAmount,
    address payable target
  )
    external
    payable
    returns (
      uint256, /* actualmakingAmount */
      uint256 /* actualtakingAmount */
    );
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import './IERC20.sol';

interface ISwap {
  // pool data view functions
  function getA() external view returns (uint256);

  function getToken(uint8 index) external view returns (IERC20);

  function getTokenIndex(address tokenAddress) external view returns (uint8);

  function getTokenBalance(uint8 index) external view returns (uint256);

  function getTokenLength() external view returns (uint256);

  function getVirtualPrice() external view returns (uint256);

  function swapStorage()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      address
    );

  function getPoolTokens() external view returns (IERC20[] memory);

  function calculateRemoveLiquidity(address account, uint256 amount) external view returns (uint256[] memory);

  //function of iron swap
  function getLpToken() external view returns (address);

  function getNumberOfTokens() external view returns (uint256);

  // state modifying functions
  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) external returns (uint256);

  function addLiquidity(
    uint256[] calldata amounts,
    uint256 minToMint,
    uint256 deadline
  ) external returns (uint256);

  function removeLiquidity(
    uint256 amount,
    uint256[] calldata minAmounts,
    uint256 deadline
  ) external returns (uint256[] memory);

  function removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount,
    uint256 deadline
  ) external returns (uint256);

  function removeLiquidityImbalance(
    uint256[] calldata amounts,
    uint256 maxBurnAmount,
    uint256 deadline
  ) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import './IERC20.sol';

interface ISwapFlashLoan {
  //function of saddle flash swap
  function swapStorage()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      address
    );

  //function of saddle flash swap
  function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[] memory);

  //function of saddle v1
  function addLiquidity(
    uint256[] calldata amounts,
    uint256 minToMint,
    uint256 deadline,
    bytes32[] calldata merkleProof
  ) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface ICurve {
  function add_liquidity(
    uint256[2] calldata amounts,
    uint256 min_mint_amount,
    bool _use_underlying
  ) external payable returns (uint256);

  function add_liquidity(
    uint256[3] calldata amounts,
    uint256 min_mint_amount,
    bool _use_underlying
  ) external payable returns (uint256);

  function add_liquidity(
    uint256[4] calldata amounts,
    uint256 min_mint_amount,
    bool _use_underlying
  ) external payable returns (uint256);

  function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount) external payable;

  function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount) external payable;

  function add_liquidity(uint256[4] calldata amounts, uint256 min_mint_amount) external payable;

  // crv.finance: Curve.fi Factory USD Metapool v2
  function add_liquidity(
    address pool,
    uint256[4] calldata amounts,
    uint256 min_mint_amount
  ) external;

  function exchange(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external payable;

  //    function exchange(
  //        uint256 i,
  //        uint256 j,
  //        uint256 dx,
  //        uint256 min_dy
  //    ) external payable;

  function exchange_underlying(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external payable;

  //    function exchange_underlying(
  //        uint256 i,
  //        uint256 j,
  //        uint256 dx,
  //        uint256 min_dy
  //    ) external payable;

  function remove_liquidity(
    uint256 _amount,
    uint256[2] calldata _min_amounts,
    bool _use_underlying
  ) external returns (uint256[] memory);

  function remove_liquidity(
    uint256 _amount,
    uint256[3] calldata _min_amounts,
    bool _use_underlying
  ) external returns (uint256[] memory);

  function remove_liquidity(
    uint256 _amount,
    uint256[4] calldata _min_amounts,
    bool _use_underlying
  ) external returns (uint256[] memory);

  function remove_liquidity(uint256 _amount, uint256[2] calldata _min_amounts) external returns (uint256[] memory);

  function remove_liquidity(uint256 _amount, uint256[3] calldata _min_amounts) external returns (uint256[] memory);

  function remove_liquidity(uint256 _amount, uint256[4] calldata _min_amounts) external returns (uint256[] memory);

  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 _min_amount,
    bool _use_underlying
  ) external returns (uint256);

  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 _min_amount
  ) external returns (uint256);

  //    function remove_liquidity_one_coin(
  //        uint256 _token_amount,
  //        uint256 i,
  //        uint256 _min_amount
  //    ) external returns (uint256);

  function remove_liquidity_imbalance(
    uint256[2] calldata _amounts,
    uint256 _max_burn_amount,
    bool _use_underlying
  ) external returns (uint256);

  function remove_liquidity_imbalance(
    uint256[3] calldata _amounts,
    uint256 _max_burn_amount,
    bool _use_underlying
  ) external returns (uint256);

  function remove_liquidity_imbalance(
    uint256[4] calldata _amounts,
    uint256 _max_burn_amount,
    bool _use_underlying
  ) external returns (uint256);

  function remove_liquidity_imbalance(uint256[2] calldata _amounts, uint256 _max_burn_amount)
    external
    returns (uint256);

  function remove_liquidity_imbalance(uint256[3] calldata _amounts, uint256 _max_burn_amount)
    external
    returns (uint256);

  function remove_liquidity_imbalance(uint256[4] calldata _amounts, uint256 _max_burn_amount)
    external
    returns (uint256);

  function lp_token() external view returns (address);

  function coins(uint256) external view returns (address);

  function underlying_coins(uint256) external view returns (address);
  //    function coins(int128) external view returns (address);
  //    function underlying_coins(int128) external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface ICurveTriCrypto {
  function exchange(
    uint256 i,
    uint256 j,
    uint256 dx,
    uint256 min_dy
  ) external payable;

  function exchange_underlying(
    uint256 i,
    uint256 j,
    uint256 dx,
    uint256 min_dy
  ) external payable;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IDMMPool.sol';

library DMMLibrary {
  using SafeMath for uint256;

  uint256 public constant PRECISION = 1e18;

  // returns sorted token addresses, used to handle return values from pools sorted in this order
  function sortTokens(IERC20 tokenA, IERC20 tokenB) internal pure returns (IERC20 token0, IERC20 token1) {
    require(tokenA != tokenB, 'DMMLibrary: IDENTICAL_ADDRESSES');
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(address(token0) != address(0), 'DMMLibrary: ZERO_ADDRESS');
  }

  /// @dev fetch the reserves and fee for a pool, used for trading purposes
  function getTradeInfo(
    address pool,
    IERC20 tokenA,
    IERC20 tokenB
  )
    internal
    view
    returns (
      uint256 reserveA,
      uint256 reserveB,
      uint256 vReserveA,
      uint256 vReserveB,
      uint256 feeInPrecision
    )
  {
    (IERC20 token0, ) = sortTokens(tokenA, tokenB);
    uint256 reserve0;
    uint256 reserve1;
    uint256 vReserve0;
    uint256 vReserve1;
    (reserve0, reserve1, vReserve0, vReserve1, feeInPrecision) = IDMMPool(pool).getTradeInfo();
    (reserveA, reserveB, vReserveA, vReserveB) = tokenA == token0
      ? (reserve0, reserve1, vReserve0, vReserve1)
      : (reserve1, reserve0, vReserve1, vReserve0);
  }

  /// @dev fetches the reserves for a pool, used for liquidity adding
  function getReserves(
    address pool,
    IERC20 tokenA,
    IERC20 tokenB
  ) internal view returns (uint256 reserveA, uint256 reserveB) {
    (IERC20 token0, ) = sortTokens(tokenA, tokenB);
    (uint256 reserve0, uint256 reserve1) = IDMMPool(pool).getReserves();
    (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
  }

  // given some amount of an asset and pool reserves, returns an equivalent amount of the other asset
  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) internal pure returns (uint256 amountB) {
    require(amountA > 0, 'DMMLibrary: INSUFFICIENT_AMOUNT');
    require(reserveA > 0 && reserveB > 0, 'DMMLibrary: INSUFFICIENT_LIQUIDITY');
    amountB = amountA.mul(reserveB) / reserveA;
  }

  // given an input amount of an asset and pool reserves, returns the maximum output amount of the other asset
  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut,
    uint256 vReserveIn,
    uint256 vReserveOut,
    uint256 feeInPrecision
  ) internal pure returns (uint256 amountOut) {
    require(amountIn > 0, 'DMMLibrary: INSUFFICIENT_INPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'DMMLibrary: INSUFFICIENT_LIQUIDITY');
    uint256 amountInWithFee = amountIn.mul(PRECISION.sub(feeInPrecision)).div(PRECISION);
    uint256 numerator = amountInWithFee.mul(vReserveOut);
    uint256 denominator = vReserveIn.add(amountInWithFee);
    amountOut = numerator.div(denominator);
    require(reserveOut > amountOut, 'DMMLibrary: INSUFFICIENT_LIQUIDITY');
  }

  // given an output amount of an asset and pool reserves, returns a required input amount of the other asset
  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut,
    uint256 vReserveIn,
    uint256 vReserveOut,
    uint256 feeInPrecision
  ) internal pure returns (uint256 amountIn) {
    require(amountOut > 0, 'DMMLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > amountOut, 'DMMLibrary: INSUFFICIENT_LIQUIDITY');
    uint256 numerator = vReserveIn.mul(amountOut);
    uint256 denominator = vReserveOut.sub(amountOut);
    amountIn = numerator.div(denominator).add(1);
    // amountIn = floor(amountIN *PRECISION / (PRECISION - feeInPrecision));
    numerator = amountIn.mul(PRECISION);
    denominator = PRECISION.sub(feeInPrecision);
    amountIn = numerator.add(denominator - 1).div(denominator);
  }

  // performs chained getAmountOut calculations on any number of pools
  function getAmountsOut(
    uint256 amountIn,
    address[] memory poolsPath,
    IERC20[] memory path
  ) internal view returns (uint256[] memory amounts) {
    amounts = new uint256[](path.length);
    amounts[0] = amountIn;
    for (uint256 i; i < path.length - 1; i++) {
      (
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 vReserveIn,
        uint256 vReserveOut,
        uint256 feeInPrecision
      ) = getTradeInfo(poolsPath[i], path[i], path[i + 1]);
      amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, vReserveIn, vReserveOut, feeInPrecision);
    }
  }

  // performs chained getAmountIn calculations on any number of pools
  function getAmountsIn(
    uint256 amountOut,
    address[] memory poolsPath,
    IERC20[] memory path
  ) internal view returns (uint256[] memory amounts) {
    amounts = new uint256[](path.length);
    amounts[amounts.length - 1] = amountOut;
    for (uint256 i = path.length - 1; i > 0; i--) {
      (
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 vReserveIn,
        uint256 vReserveOut,
        uint256 feeInPrecision
      ) = getTradeInfo(poolsPath[i - 1], path[i - 1], path[i]);
      amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, vReserveIn, vReserveOut, feeInPrecision);
    }
  }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool {
  /// @notice Swap token0 for token1, or token1 for token0
  /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
  /// @param recipient The address to receive the output of the swap
  /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
  /// @param amountSpecified The amount of the swap, which implicitly configures
  /// the swap as exact input (positive), or exact output (negative)
  /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
  /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
  /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) external returns (int256 amount0, int256 amount1);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The swap interface for a Kyber ProMM Pool
interface IProMMPool {
  /// @notice Swap token0 -> token1, or vice versa
  /// @dev This method's caller receives a callback in the form of ISwapCallback#swapCallback
  /// @dev swaps will execute up to limitSqrtP or swapQty is fully used
  /// @param recipient The address to receive the swap output
  /// @param swapQty The swap quantity, which implicitly configures the swap as exact input (>0), or exact output (<0)
  /// @param isToken0 Whether the swapQty is specified in token0 (true) or token1 (false)
  /// @param limitSqrtP the limit of sqrt price after swapping
  /// could be MAX_SQRT_RATIO-1 when swapping 1 -> 0 and MIN_SQRT_RATIO+1 when swapping 0 -> 1 for no limit swap
  /// @param data Any data to be passed through to the callback
  /// @return qty0 Exact token0 qty sent to recipient if < 0. Minimally received quantity if > 0.
  /// @return qty1 Exact token1 qty sent to recipient if < 0. Minimally received quantity if > 0.
  function swap(
    address recipient,
    int256 swapQty,
    bool isToken0,
    uint160 limitSqrtP,
    bytes calldata data
  ) external returns (int256 qty0, int256 qty1);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma experimental ABIEncoderV2;
pragma solidity >=0.7.6;

/**
 * @dev Full external interface for the Vault core contract - no external or public methods exist in the contract that
 * don't override one of these declarations.
 */
interface IBalancerV2Vault {
  enum PoolSpecialization {
    GENERAL,
    MINIMAL_SWAP_INFO,
    TWO_TOKEN
  }
  enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
  }

  function swap(
    SingleSwap memory singleSwap,
    FundManagement memory funds,
    uint256 limit,
    uint256 deadline
  ) external payable returns (uint256);

  struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint256 amount;
    bytes userData;
  }

  struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address recipient;
    bool toInternalBalance;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IDODOV1 {
  function querySellBaseToken(uint256 amount) external view returns (uint256 receiveQuote);

  function queryBuyBaseToken(uint256 amount) external view returns (uint256 payQuote);

  function sellBaseToken(
    uint256 amount,
    uint256 minReceiveQuote,
    bytes calldata data
  ) external returns (uint256);

  function buyBaseToken(
    uint256 amount,
    uint256 maxPayQuote,
    bytes calldata data
  ) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IDODOV2 {
  function querySellBase(address trader, uint256 payBaseAmount)
    external
    view
    returns (uint256 receiveQuoteAmount, uint256 mtFee);

  function querySellQuote(address trader, uint256 payQuoteAmount)
    external
    view
    returns (uint256 receiveBaseAmount, uint256 mtFee);

  function sellBase(address to) external returns (uint256 receiveQuoteAmount);

  function sellQuote(address to) external returns (uint256 receiveBaseAmount);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IDODOSellHelper {
  function querySellQuoteToken(address dodo, uint256 amount) external view returns (uint256);

  function querySellBaseToken(address dodo, uint256 amount) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IVelodromePair {
  function token0() external view returns (address);

  function reserve0() external view returns (uint256);

  function reserve1() external view returns (uint256);

  function getAmountOut(uint256, address) external view returns (uint256);

  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IGMXVault {
  function swap(
    address _tokenIn,
    address _tokenOut,
    address _receiver
  ) external returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.24;

interface ISynthetix {
  function exchange(
    bytes32 sourceCurrencyKey,
    uint256 sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint256 amountReceived);

  function exchangeAtomically(
    bytes32 sourceCurrencyKey,
    uint256 sourceAmount,
    bytes32 destinationCurrencyKey,
    bytes32 trackingCode,
    uint256 minAmount
  ) external returns (uint256 amountReceived);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
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
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.6.12;

import './IERC20.sol';

interface IDMMPool {
  function mint(address to) external returns (uint256 liquidity);

  function burn(address to) external returns (uint256 amount0, uint256 amount1);

  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;

  function sync() external;

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1);

  function getTradeInfo()
    external
    view
    returns (
      uint112 _vReserve0,
      uint112 _vReserve1,
      uint112 reserve0,
      uint112 reserve1,
      uint256 feeInPrecision
    );

  function token0() external view returns (IERC20);

  function token1() external view returns (IERC20);

  function ampBps() external view returns (uint32);

  function factory() external view returns (address);

  function kLast() external view returns (uint256);
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