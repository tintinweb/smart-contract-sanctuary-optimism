// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {IERC20} from "src/interfaces/IERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {Create2} from "src/lib/Create2.sol";
import {SafeTransferLib} from "src/lib/SafeTransferLib.sol";

// ============================
// ======== Interfaces ========
// ============================

interface IAavePool {
  struct ReserveConfigurationMap {
    uint data; // This is a packed word, but we don't need this data here.
  }

  struct ReserveData {
    ReserveConfigurationMap configuration; // stores the reserve configuration
    uint128 liquidityIndex; // the liquidity index. Expressed in ray
    uint128 currentLiquidityRate; // the current supply rate. Expressed in ray
    uint128 variableBorrowIndex; // variable borrow index. Expressed in ray
    uint128 currentVariableBorrowRate; // the current variable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate; // the current stable borrow rate. Expressed in ray
    uint40 lastUpdateTimestamp; // timestamp of last update
    uint16 id; // the id of the reserve. Represents the position in the list of the active reserves
    address aTokenAddress; // aToken address
    address stableDebtTokenAddress; // stableDebtToken address
    address variableDebtTokenAddress; // variableDebtToken address
    address interestRateStrategyAddress; // address of the interest rate strategy
    uint128 accruedToTreasury; // the current treasury balance, scaled
    uint128 unbacked; // the outstanding unbacked aTokens minted through the bridging feature
    uint128 isolationModeTotalDebt; // the outstanding debt borrowed against this asset in isolation mode
  }

  function getReserveData(address asset)
    external
    view
    returns (ReserveData memory);

  function supply(
    address asset,
    uint amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  function withdraw(address asset, uint amount, address to)
    external
    returns (uint);

  // The below methods are used in scripts, but not in these contracts.
  function supply(bytes32 args) external;
  function withdraw(bytes32 args) external;
}

// =========================
// ======== Helpers ========
// =========================

// Amounts supplied or withdrawn are specified as a fraction of the user's
// balance. You can pass up to 31 bytes of data to define this fraction. If zero
// bytes are provided, the max amount is used. If one byte is provided, that
// data is considered the numerator, and the denominator becomes 255, which is
// the max value of a single byte. If two bytes are provided, the data is still
// considered the numerator, but the denominator becomes 65_535, which is the
// max value of 2 bytes. This pattern continues through 31 bytes, and this
// method will revert if you try passing 32 bytes or more of calldata.
// Realistically you'll never need that much anyway.
function parseAmount(uint balance, bytes calldata data) pure returns (uint) {
  if (data.length == 0) return balance;

  uint bits = data.length * 8;
  uint fraction = uint(bytes32(data) >> (256 - bits));
  uint maxUintN = (1 << bits) - 1;
  return balance * fraction / maxUintN;
}

// =========================
// ======== Routers ========
// =========================

abstract contract AaveRouterBase {
  IAavePool public immutable AAVE;
  address public immutable ASSET;
  address public immutable ATOKEN;

  uint internal constant MAX_UINT = type(uint).max;
  uint16 internal constant REFERRAL_CODE = 0;

  constructor(IAavePool aave, address asset) {
    AAVE = aave;
    ASSET = asset;
    ATOKEN = aave.getReserveData(asset).aTokenAddress;
  }
}

// -------- Supply ETH Router --------
contract AaveSupplyEth is AaveRouterBase {
  using SafeTransferLib for IERC20;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {
    IERC20(asset).safeApprove(address(aave), type(uint).max);
  }

  receive() external payable {
    IWETH(ASSET).deposit{value: msg.value}();
    AAVE.supply(ASSET, msg.value, msg.sender, REFERRAL_CODE);
  }
}

// -------- Supply Tokens Router --------
contract AaveSupplyToken is AaveRouterBase {
  using SafeTransferLib for IERC20;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {
    IERC20(asset).safeApprove(address(aave), type(uint).max);
  }

  fallback() external {
    uint balance = IERC20(ASSET).balanceOf(msg.sender);
    uint amt = parseAmount(balance, msg.data);
    IERC20(ASSET).safeTransferFrom(msg.sender, address(this), amt);
    AAVE.supply(ASSET, amt, msg.sender, 0);
  }
}

// -------- Withdraw ETH Router --------
contract AaveWithdrawEth is AaveRouterBase {
  using SafeTransferLib for IERC20;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {}

  fallback() external payable {
    if (msg.sender == ASSET) return; // Getting ETH from the WETH contract.

    uint balance = IERC20(ATOKEN).balanceOf(msg.sender);
    uint amt = parseAmount(balance, msg.data);
    IERC20(ATOKEN).safeTransferFrom(msg.sender, address(this), amt);

    // Need to pass MAX_UINT to withdraw full amount after interest accrual.
    amt = AAVE.withdraw(ASSET, amt == balance ? MAX_UINT : amt, address(this));

    // Unwrap WETH and send ETH to user.
    IWETH(ASSET).withdraw(amt);
    (bool ok,) = msg.sender.call{value: amt}("");
    require(ok, "Transfer failed");
  }
}

// -------- Withdraw Tokens Router --------
contract AaveWithdrawToken is AaveRouterBase {
  using SafeTransferLib for IERC20;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {}

  fallback() external {
    uint balance = IERC20(ATOKEN).balanceOf(msg.sender);
    uint amt = parseAmount(balance, msg.data);
    IERC20(ATOKEN).safeTransferFrom(msg.sender, address(this), amt);

    // Need to pass MAX_UINT to withdraw full amount after interest accrual.
    AAVE.withdraw(address(ASSET), amt == balance ? MAX_UINT : amt, msg.sender);
  }
}

// =========================
// ======== Factory ========
// =========================

contract AaveRouterFactory {
  IAavePool public immutable AAVE;
  address public immutable WETH;
  address public immutable SUPPLY_ETH_ROUTER;
  address public immutable WITHDRAW_ETH_ROUTER;

  event RoutersDeployed(
    address supplyRouter, address withdrawRouter, address indexed asset
  );

  constructor(IAavePool aave, address weth) {
    AAVE = aave;
    WETH = weth;

    bytes32 salt = _salt(weth);
    SUPPLY_ETH_ROUTER = address(new AaveSupplyEth{salt: salt}(aave, weth));
    WITHDRAW_ETH_ROUTER = address(new AaveWithdrawEth{salt: salt}(aave, weth));
    emit RoutersDeployed(SUPPLY_ETH_ROUTER, WITHDRAW_ETH_ROUTER, weth);
  }

  function deploy(address asset) external returns (address, address) {
    address supplyRouter =
      address(new AaveSupplyToken{salt: _salt(asset)}(AAVE, asset));
    address withdrawRouter =
      address(new AaveWithdrawToken{salt: _salt(asset)}(AAVE, asset));

    emit RoutersDeployed(supplyRouter, withdrawRouter, asset);
    return (supplyRouter, withdrawRouter);
  }

  function getRouters(address asset) public view returns (address, address) {
    if (asset == WETH) return (SUPPLY_ETH_ROUTER, WITHDRAW_ETH_ROUTER);

    (address supplyRouter, address withdrawRouter) = computeAddresses(asset);
    if (supplyRouter.code.length == 0) return (address(0), address(0));
    return (supplyRouter, withdrawRouter);
  }

  function isDeployed(address asset) external view returns (bool) {
    (address supplyRouter,) = getRouters(asset);
    return supplyRouter != address(0);
  }

  function computeAddresses(address asset)
    public
    view
    returns (address, address)
  {
    if (asset == WETH) return (SUPPLY_ETH_ROUTER, WITHDRAW_ETH_ROUTER);
    address supplyRouter = _computeAddress(asset, true);
    address withdrawRouter = _computeAddress(asset, false);
    return (supplyRouter, withdrawRouter);
  }

  function _computeAddress(address asset, bool supply)
    internal
    view
    returns (address)
  {
    return Create2.computeCreate2Address(
      _salt(asset),
      address(this),
      supply
        ? type(AaveSupplyToken).creationCode
        : type(AaveWithdrawToken).creationCode,
      abi.encode(AAVE, asset)
    );
  }

  function _salt(address asset) internal pure returns (bytes32) {
    return bytes32(uint(uint160(asset)));
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IERC20 {
  function approve(address spender, uint amount) external returns (bool);
  function balanceOf(address who) external view returns (uint);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IWETH {
  function deposit() external payable;
  function withdraw(uint wad) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

library Create2 {
  function computeCreate2Address(
    bytes32 salt,
    address deployer,
    bytes memory initcode,
    bytes memory constructorArgs
  ) internal pure returns (address) {
    return address(
      uint160(
        uint(
          keccak256(
            abi.encodePacked(
              bytes1(0xff),
              deployer,
              salt,
              keccak256(abi.encodePacked(initcode, constructorArgs))
            )
          )
        )
      )
    );
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "src/interfaces/IERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
/// @dev Identical to the solmate version, but using the IERC20 interface type.
/// Copied from: https://github.com/transmissions11/solmate/blob/4933263adeb62ee8878028e542453c4d1a071be9/src/utils/SafeTransferLib.sol
library SafeTransferLib {
  /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeTransferETH(address to, uint amount) internal {
    bool success;

    assembly {
      // Transfer the ETH and store if it succeeded or not.
      success := call(gas(), to, amount, 0, 0, 0, 0)
    }

    require(success, "ETH_TRANSFER_FAILED");
  }

  /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeTransferFrom(IERC20 token, address from, address to, uint amount)
    internal
  {
    bool success;

    assembly {
      // We'll write our calldata to this slot below, but restore it later.
      let memPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(
        0, 0x23b872dd00000000000000000000000000000000000000000000000000000000
      )
      mstore(4, from) // Append the "from" argument.
      mstore(36, to) // Append the "to" argument.
      mstore(68, amount) // Append the "amount" argument.

      success :=
        and(
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(
            and(eq(mload(0), 1), gt(returndatasize(), 31)),
            iszero(returndatasize())
          ),
          // We use 100 because that's the total length of our calldata (4 + 32 * 3)
          // Counterintuitively, this call() must be positioned after the or() in the
          // surrounding and() because and() evaluates its arguments from right to left.
          call(gas(), token, 0, 0, 100, 0, 32)
        )

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, memPointer) // Restore the memPointer.
    }

    require(success, "TRANSFER_FROM_FAILED");
  }

  function safeTransfer(IERC20 token, address to, uint amount) internal {
    bool success;

    assembly {
      // We'll write our calldata to this slot below, but restore it later.
      let memPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(
        0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000
      )
      mstore(4, to) // Append the "to" argument.
      mstore(36, amount) // Append the "amount" argument.

      success :=
        and(
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(
            and(eq(mload(0), 1), gt(returndatasize(), 31)),
            iszero(returndatasize())
          ),
          // We use 68 because that's the total length of our calldata (4 + 32 * 2)
          // Counterintuitively, this call() must be positioned after the or() in the
          // surrounding and() because and() evaluates its arguments from right to left.
          call(gas(), token, 0, 0, 68, 0, 32)
        )

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, memPointer) // Restore the memPointer.
    }

    require(success, "TRANSFER_FAILED");
  }

  function safeApprove(IERC20 token, address to, uint amount) internal {
    bool success;

    assembly {
      // We'll write our calldata to this slot below, but restore it later.
      let memPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(
        0, 0x095ea7b300000000000000000000000000000000000000000000000000000000
      )
      mstore(4, to) // Append the "to" argument.
      mstore(36, amount) // Append the "amount" argument.

      success :=
        and(
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(
            and(eq(mload(0), 1), gt(returndatasize(), 31)),
            iszero(returndatasize())
          ),
          // We use 68 because that's the total length of our calldata (4 + 32 * 2)
          // Counterintuitively, this call() must be positioned after the or() in the
          // surrounding and() because and() evaluates its arguments from right to left.
          call(gas(), token, 0, 0, 68, 0, 32)
        )

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, memPointer) // Restore the memPointer.
    }

    require(success, "APPROVE_FAILED");
  }
}