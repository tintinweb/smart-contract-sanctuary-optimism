// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IBeefyVaultV6} from "./IBeefyVault.sol";

library BeefyBase {
    function beefyDepositAll(address beefyVault) external returns (uint256) {
        IBeefyVaultV6(beefyVault).depositAll();
        return IBeefyVaultV6(beefyVault).balanceOf(address(this));
    }

    function beefyWithdraw(
        address beefyVault,
        uint256 amount
    ) external returns (uint256) {
        IBeefyVaultV6(beefyVault).withdraw(amount);

        // using same interface for ERC20 token, because vault itself is ERC20 token
        return
            IBeefyVaultV6(IBeefyVaultV6(beefyVault).want()).balanceOf(
                address(this)
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IExchangeAdapter} from "./../../interfaces/IExchangeAdapter.sol";
import {BeefyBase} from "./BeefyBase.sol";
import {IWrappedEther} from "./../../interfaces/IWrappedEther.sol";

// solhint-disable func-name-mixedcase
// solhint-disable var-name-mixedcase
interface ICurve {
    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received
    ) external returns (uint256);

    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);
}

contract BeefyCurveSBTCAdapter is IExchangeAdapter {
    ICurve public constant CURVE =
        ICurve(0x9F2fE3500B1a7E285FDc337acacE94c480e00130);
    IWrappedEther public constant WBTC =
        IWrappedEther(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    address public constant MOO_TOKEN =
        0x25DE69dA4469A96974FaE79d0C41366A63317FDC;

    // 0x6012856e  =>  executeSwap(address,address,address,uint256)
    function executeSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 amount
    ) external payable returns (uint256) {
        if (fromToken == address(WBTC) && toToken == MOO_TOKEN) {
            // WBTC -> Curve LP
            depositEthToCurve(amount);

            // Curve LP -> moo token
            return BeefyBase.beefyDepositAll(pool);
        } else if (fromToken == MOO_TOKEN && toToken == address(WBTC)) {
            // moo token -> Curve LP
            uint256 curveLpReceived = BeefyBase.beefyWithdraw(pool, amount);

            // Curve LP -> WBTC
            return getEthFromCurve(curveLpReceived);
        } else {
            revert("Adapter: can't swap");
        }
    }

    // 0xe83bbb76  =>  enterPool(address,address,address,uint256)
    function enterPool(
        address,
        address,
        uint256
    ) external payable returns (uint256) {
        revert("Adapter: can't enter");
    }

    // 0x9d756192  =>  exitPool(address,address,address,uint256)
    function exitPool(
        address,
        address,
        uint256
    ) external payable returns (uint256) {
        revert("Adapter: can't exit");
    }

    function getEthFromCurve(uint256 amount) internal returns (uint256) {
        uint256 wbtcReceived = CURVE.remove_liquidity_one_coin(amount, 1, 0);
        return wbtcReceived;
    }

    function depositEthToCurve(uint256 amount) internal returns (uint256) {
        uint256[2] memory amounts;
        amounts[1] = amount;
        return CURVE.add_liquidity(amounts, 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBeefyVaultV6 {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approvalDelay() external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function available() external view returns (uint256);

    function balance() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);

    function deposit(uint256 _amount) external;

    function depositAll() external;

    function earn() external;

    function getPricePerFullShare() external view returns (uint256);

    function inCaseTokensGetStuck(address _token) external;

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function proposeStrat(address _implementation) external;

    function renounceOwnership() external;

    function stratCandidate()
        external
        view
        returns (address implementation, uint256 proposedTime);

    function strategy() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function upgradeStrat() external;

    function want() external view returns (address);

    function withdraw(uint256 _shares) external;

    function withdrawAll() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IExchangeAdapter {
    // 0x6012856e  =>  executeSwap(address,address,address,uint256)
    function executeSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 amount
    ) external payable returns (uint256);

    // 0x73ec962e  =>  enterPool(address,address,uint256)
    function enterPool(
        address pool,
        address fromToken,
        uint256 amount
    ) external payable returns (uint256);

    // 0x660cb8d4  =>  exitPool(address,address,uint256)
    function exitPool(
        address pool,
        address toToken,
        uint256 amount
    ) external payable returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IWrappedEther {
    function name() external view returns (string memory);

    function approve(address guy, uint256 wad) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function withdraw(uint256 wad) external;

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function symbol() external view returns (string memory);

    function transfer(address dst, uint256 wad) external returns (bool);

    function deposit() external payable;

    function allowance(address, address) external view returns (uint256);
}