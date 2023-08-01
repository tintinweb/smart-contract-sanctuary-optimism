// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/extensions/IERC20Metadata.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IExchangeAdapter} from "./../../interfaces/IExchangeAdapter.sol";
import {BeefyBase} from "./BeefyBase.sol";
import {IStargateEth} from "./../../interfaces/IStargateEth.sol";
import {IWrappedEther} from "./../../interfaces/IWrappedEther.sol";

interface IStargate {
    function addLiquidity(
        uint256 _poolId,
        uint256 _amountLD,
        address _to
    ) external;

    function instantRedeemLocal(
        uint16 _srcPoolId,
        uint256 _amountLP,
        address _to
    ) external returns (uint256 amountSD);
}

contract BeefyStargateWethAdapter is IExchangeAdapter {
    IStargate public constant STARGATE =
        IStargate(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b);
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant STARGATE_ETH =
        0xb69c8CBCD90A39D8D3d3ccf0a3E968511C3856A0;
    address public constant MOO_TOKEN =
        0x79149B500f0d796aA7f85e0170d16C7e79BAd3C5;
    uint16 public constant POOL_ID = 13;

    // 0x6012856e  =>  executeSwap(address,address,address,uint256)
    function executeSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 amount
    ) external payable returns (uint256) {
        if (fromToken == WETH && toToken == MOO_TOKEN) {
            // USDC -> Stargate LP
            depositUsdcToStargate(amount);

            // Stargate LP -> moo token
            return BeefyBase.beefyDepositAll(pool);
        } else if (fromToken == MOO_TOKEN && toToken == WETH) {
            // moo token -> Stargate LP
            uint256 hopReceived = BeefyBase.beefyWithdraw(pool, amount);

            // Stargate LP -> USDC
            uint256 received = getUsdcFromStargate(hopReceived);
            return received;
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

    function getUsdcFromStargate(uint256 amount) internal returns (uint256) {
        uint256 ethReceived = STARGATE.instantRedeemLocal(
            POOL_ID,
            amount,
            address(this)
        );
        IWrappedEther(WETH).deposit{value: ethReceived}();

        return ethReceived;
    }

    function depositUsdcToStargate(uint256 amount) internal {
        IWrappedEther(WETH).withdraw(amount);
        IStargateEth(STARGATE_ETH).deposit{value: amount}();

        STARGATE.addLiquidity(POOL_ID, amount, address(this));
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
pragma solidity ^0.8.19;

interface IStargateEth {
    function allowance(address, address) external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function decimals() external view returns (uint8);

    function deposit() external payable;

    function name() external view returns (string memory);

    function noUnwrapTo(address) external view returns (bool);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function setNoUnwrapTo(address _addr) external;

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function withdraw(uint256 wad) external;
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