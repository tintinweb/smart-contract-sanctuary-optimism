// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Claim {
    address private _multisig;
    IERC20 private _strategyToken;

    uint256 public _unlockTime;
    address public _mainWinner;
    uint256 public _mainPrizeAmount;

    mapping (address => uint256) prizes;

    event Withdrawal(uint amount, address who);

    modifier onlyMultisig {
        require(msg.sender == _multisig);
        _;
    }

    constructor(address multisig, IERC20 strategyToken) {
        _multisig = multisig;
        _strategyToken = strategyToken;
    }

    function lockMainPrize(uint unlockTime, address mainWinner, uint mainPrizeAmount) external onlyMultisig {
        require(
            _unlockTime == 0,
            "Unlock time is already set"
        );
        require(
            block.timestamp < unlockTime,
            "Unlock time should be in the future"
        );

        _unlockTime = unlockTime;
        _mainWinner = mainWinner;
        _mainPrizeAmount = mainPrizeAmount;
    }

    function rewardToken() public view returns (address) {
        return address(_strategyToken);
    }
    function withdrawMainPrize() external {
        require(block.timestamp >= _unlockTime, "You can't withdraw yet");
        require(msg.sender == _mainWinner, "You aren't the main winner");

        require(_strategyToken.transfer(_mainWinner, _mainPrizeAmount), "Failed to transfer prize");

        emit Withdrawal(_mainPrizeAmount, _mainWinner);
    }

    function setPrizes(address[] calldata winners, uint256[] calldata prizeAmounts) external onlyMultisig {
        require(winners.length == prizeAmounts.length, "Length mismatch");

        for (uint256 i = 0; i < winners.length; i++) {
            prizes[winners[i]] = prizeAmounts[i];
        }
    }

    function DEBUG___setPrizes(address[] calldata winners, uint256[] calldata prizeAmounts) external {
        require(winners.length == prizeAmounts.length, "Length mismatch");

        for (uint256 i = 0; i < winners.length; i++) {
            prizes[winners[i]] = prizeAmounts[i];
        }
    }

    function claim() external {
        require(availableToClaim(msg.sender) > 0, "No prize for you");

        uint amount = prizes[msg.sender];
        prizes[msg.sender] = 0;
        require(_strategyToken.transfer(msg.sender, amount), "Failed to transfer prize");

        emit Withdrawal(amount, msg.sender);
    }

    function availableToClaim(address user) public view returns (uint) {
        return prizes[user];
    }
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