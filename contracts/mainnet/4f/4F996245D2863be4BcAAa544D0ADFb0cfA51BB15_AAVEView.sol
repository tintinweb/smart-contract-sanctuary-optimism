//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { IPool } from "./interfaces/IPool.sol";

contract AAVEView {
    uint256 public immutable AAVE_BASE = 100000000;
    address public immutable USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public immutable WETH = 0x4200000000000000000000000000000000000006;
    address public immutable AAVEOracle = 0xD81eb3728a631871a7eBBaD631b5f424909f0c77;
    address public immutable AAVEPool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public immutable A_USDC = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
    address public immutable V_USDC = 0xFCCf3cAbbe80101232d343252614b6A3eE81C989;
    address public immutable A_ETH = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
    address public immutable V_ETH = 0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351;

    //price in AAAVE base units 10^8 = 1 base unit (worth 1 USD),
    // 0 - lack of data
    function getOraclePrice(address asset) public view returns (uint256 price) {
        if (asset != USDC && asset != WETH) {
            return 0;
        }
        uint256 price = IOracle(AAVEOracle).getAssetPrice(asset);
        return price;
    }

    function getAmountFromBaseUnits(address asset, uint256 baseUnits)
        public
        view
        returns (uint256 amount)
    {
        uint256 price = getOraclePrice(asset);
        if (price == 0) {
            return 0;
        }
        uint256 multiplier = asset == USDC ? 10**6 : 10**18;
        return ((((multiplier * baseUnits) / price)));
    }

    function getUserAccountData(address user)
        public
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        (
            totalCollateralBase,
            totalDebtBase,
            availableBorrowsBase,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        ) = IPool(AAVEPool).getUserAccountData(user);
    }

    function getMaxAvailableToBorrow(address positionOwner, address asset)
        public
        view
        returns (uint256 amount)
    {
        if (asset != USDC && asset != WETH) {
            return 0;
        }
        uint256 decimalsBase = (asset == USDC) ? 10**6 : 10**18;

        uint256 price = getOraclePrice(asset);

        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVEPool).getUserAccountData(
            positionOwner
        );

        amount = (decimalsBase * availableBorrowsBase) / price;

        return amount;
    }

    //max amount than can be Withdrawn with account for decimals, for others than USDC/ETH allways 0, uses LTV from getUserAccountData
    function getMaxAvailableToWithdraw(address positionOwner, address collateralAsset)
        public
        view
        returns (uint256 amount)
    {
        if (collateralAsset != USDC && collateralAsset != WETH) {
            return 0;
        }
        uint256 decimalsBase = (collateralAsset == USDC) ? 10**6 : 10**18;
        (uint256 totalCollateralBase, uint256 totalDebtBase, , , uint256 ltv, ) = IPool(AAVEPool)
            .getUserAccountData(positionOwner);
        uint256 freeCollateralBase = totalCollateralBase - (totalDebtBase * 10000) / ltv;
        uint256 price = getOraclePrice(collateralAsset);
        return (((decimalsBase * freeCollateralBase) / price) * 99) / 100;
    }

    //balance of specific asset if negative asset is debt
    function getBalance(address positionOwner, address asset) public view returns (int256 amount) {
        if (asset == USDC) {
            return
                int256(IERC20(A_USDC).balanceOf(positionOwner)) -
                int256(IERC20(V_USDC).balanceOf(positionOwner));
        } else if (asset == WETH) {
            return
                int256(IERC20(A_ETH).balanceOf(positionOwner)) -
                int256(IERC20(V_ETH).balanceOf(positionOwner));
        }

        return 0;
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;

interface IERC20 {
  function totalSupply() external view returns (uint256 supply);

  function balanceOf(address _owner) external view returns (uint256 balance);

  function transfer(address _to, uint256 _value) external returns (bool success);

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) external returns (bool success);

  function approve(address _spender, uint256 _value) external returns (bool success);

  function allowance(address _owner, address _spender) external view returns (uint256 remaining);

  function decimals() external view returns (uint256 digits);

  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;

interface IOracle {
    function getAssetPrice(address assets) external view returns (uint256);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;

interface IPool {
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount taken plus a fee is returned.
     * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
     * into consideration. For further details please visit https://developers.aave.com
     * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanReceiver interface
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts of the assets being flash-borrowed
     * @param interestRateModes Types of the debt to open if the flash loan is not returned:
     *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
     *   1 -> Open debt at stable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
     *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
     * @param onBehalfOf The address  that will receive the debt in the case of using on `modes` 1 or 2
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount taken plus a fee is returned.
     * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
     * into consideration. For further details please visit https://developers.aave.com
     * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanSimpleReceiver interface
     * @param asset The address of the asset being flash-borrowed
     * @param amount The amount of the asset being flash-borrowed
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}