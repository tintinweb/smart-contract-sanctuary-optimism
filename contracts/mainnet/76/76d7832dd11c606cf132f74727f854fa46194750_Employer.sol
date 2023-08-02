// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITimeToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TIME Token Employer contract
 * @dev Smart contract used to model the first Use Case for TIME Token - The Employer. It pays some interest over the native cryptocurrency deposited from investors
 **/
contract Employer {

    using Math for uint256;

    bool private _isOperationLocked;

    address public constant DEVELOPER_ADDRESS = 0x731591207791A93fB0Ec481186fb086E16A7d6D0;
    address public immutable TIME_TOKEN_ADDRESS;

    uint256 public constant D = 10**18;
    uint256 public constant FACTOR = 10**18;
    uint256 public immutable FIRST_BLOCK;
    uint256 public immutable ONE_YEAR;
    uint256 public availableNative;
    uint256 public currentDepositedNative;
    uint256 public totalAnticipatedTime;
    uint256 public totalBurnedTime;
    uint256 public totalDepositedNative;
    uint256 public totalDepositedTime;
    uint256 public totalEarnedNative;
    uint256 public totalTimeSaved;
    
    mapping (address => bool) public anticipationEnabled;

    mapping (address => uint256) public deposited;
    mapping (address => uint256) public earned;
    mapping (address => uint256) public lastBlock;
    mapping (address => uint256) public remainingTime;

    constructor(address timeTokenAddress_) {
        FIRST_BLOCK = block.number;
        TIME_TOKEN_ADDRESS = timeTokenAddress_;
        ONE_YEAR = ITimeToken(timeTokenAddress_).TIME_BASE_LIQUIDITY().mulDiv(52, 1);
    }

    /**
     * @dev Implement security to avoid reentrancy attacks
     **/
    modifier nonReentrant() {
        require(!_isOperationLocked, "Operation is locked");
        _isOperationLocked = true;
        _;
        _isOperationLocked = false;
	}
    
    /**
     * @dev Update the blocks from caller (msg.sender), contract address, and burn TIME tokens accordingly. It also extracts ETH from TIME contract, compounds and transfer earnings to depositants
     **/
    modifier update(bool mustCompound) {
        if (lastBlock[address(this)] == 0 && block.number != 0)
            lastBlock[address(this)] = block.number;
        if ((lastBlock[msg.sender] == 0 && block.number != 0) || remainingTime[msg.sender] == 0)
            lastBlock[msg.sender] = block.number;
        uint256 timeToBurn = (block.number - lastBlock[address(this)]).mulDiv(D, 1);
        uint256 timeToBurnDepositant = (block.number - lastBlock[msg.sender]).mulDiv(D, 1);
        earned[msg.sender] += queryEarnings(msg.sender);
        _;
        if (mustCompound)
            _compoundDepositantEarnings(msg.sender);
        else
            _transferDepositantEarnings(msg.sender);
        ITimeToken timeToken = ITimeToken(TIME_TOKEN_ADDRESS);
        _earnInterestAndAllocate(timeToken);
        if (timeToBurn > remainingTime[address(this)])
            timeToBurn = remainingTime[address(this)];
        if (timeToBurnDepositant > remainingTime[msg.sender])
            timeToBurnDepositant = remainingTime[msg.sender];
        if (timeToBurn > 0)
            _burnTime(timeToken, address(this), timeToBurn);
        if (timeToBurnDepositant > 0)
            _burnTime(timeToken, msg.sender, timeToBurnDepositant);
        lastBlock[address(this)] = block.number;
        lastBlock[msg.sender] = block.number;
    }

    fallback() external payable {
        require(msg.data.length == 0);
    }

    receive() external payable {
        if (msg.sender != TIME_TOKEN_ADDRESS) {
            require(msg.value > 0, "Please deposit some amount");
            availableNative += msg.value;
        }
    }

    /**
     * @dev Common function to anticipate gains earned from investments from deposited amount
     * @param timeAmount TIME token amount used to anticipate the earnings in terms of blocks
     **/
    function _anticipateEarnings(uint256 timeAmount) private {
        earned[msg.sender] += queryAnticipatedEarnings(msg.sender, timeAmount);
        totalAnticipatedTime += timeAmount;
        remainingTime[address(this)] += timeAmount;
    }

    /**
     * @dev Burn TIME according to the amount set from selected depositant
     * @param timeToken The instance of TIME Token contract
     * @param depositant Address of depositant account
     * @param amount Amount to be burned
     **/
    function _burnTime(ITimeToken timeToken, address depositant, uint256 amount) private {
        if (amount > timeToken.balanceOf(address(this)))
            amount = timeToken.balanceOf(address(this));
        try timeToken.burn(amount) {
            totalBurnedTime += amount;
            remainingTime[depositant] -= amount;
        } catch {
            revert("Unable to burn TIME");
        }
    }

    /**
     * @dev Claim the withdrawable amount earned from the TIME Community Pool
     * @param timeToken The instance of TIME Token contract
     * @return earnings The amount earned from TIME Token Community Pool
     **/
    function _claimEarningsFromTime(ITimeToken timeToken) private returns (uint256 earnings) {
        uint256 currentBalance = address(this).balance;
        if (timeToken.withdrawableShareBalance(address(this)) > 0) {
            try timeToken.withdrawShare() {
                earnings = (address(this).balance - currentBalance);
                _payComission(earnings / 2);
                earnings /= 2;
                return earnings;
            } catch {
                return earnings;
            }
        } else {
            return earnings;
        }
    }

    /**
     * @dev Compound earned amount from selected depositant
     * @param depositant Address of depositant account
     **/
    function _compoundDepositantEarnings(address depositant) private {
        if (earned[depositant] > 0) {
            require(availableNative >= earned[depositant], "Not enough amount to transfer");
            availableNative -= earned[depositant];
            deposited[depositant] += earned[depositant];
            currentDepositedNative += earned[depositant];
            earned[depositant] = 0;
        }        
    }

    /**
     * @dev Claim earnings from TIME contract and buy 10% of them in TIME tokens 
     * @param timeToken The instance of TIME Token contract
     **/
    function _earnInterestAndAllocate(ITimeToken timeToken) private {
        uint256 earnedNative = _claimEarningsFromTime(timeToken);
        totalEarnedNative += earnedNative;
        _saveTime(timeToken, earnedNative / 10);
        availableNative += (earnedNative - (earnedNative / 10));
    }

    /**
     * @notice Called when need to pay comission for miner (block.coinbase) and developer
     * @param comissionAmount The total comission amount in ETH which will be paid
    **/
    function _payComission(uint256 comissionAmount) private {
        if (comissionAmount > 0) {
            uint256 share = comissionAmount / 4;
            _saveTime(ITimeToken(TIME_TOKEN_ADDRESS), share);
            payable(DEVELOPER_ADDRESS).transfer(share);
            availableNative += share;
            totalEarnedNative += share;
            if (block.coinbase == address(0))
                payable(DEVELOPER_ADDRESS).transfer(share);
            else
                payable(block.coinbase).transfer(share);
        }
    }

    /**
     * @dev Buy (save) TIME tokens from the TIME Token contract and update the amount to be burned
     * @param timeToken The instance of TIME Token contract
     * @param amountToSave Amount to be bought
     **/
    function _saveTime(ITimeToken timeToken, uint256 amountToSave) private {
        if (amountToSave > 0) {
            require(address(this).balance >= amountToSave, "Not enough amount to save TIME");
            uint256 currentTime = timeToken.balanceOf(address(this));
            try timeToken.saveTime{value: amountToSave}() {
                uint256 timeSaved = (timeToken.balanceOf(address(this)) - currentTime);
                remainingTime[address(this)] += timeSaved;
                totalTimeSaved += timeSaved;
            } catch { 
                revert("Not able to save TIME");
            }
        }
    }

    /**
     * @dev Withdraw all available earnings to the depositant address
     * @param depositant Address of depositant account
     **/
    function _transferDepositantEarnings(address depositant) private {
        if (earned[depositant] > 0) {
            require(availableNative >= earned[depositant], "Not enough amount to transfer");
            availableNative -= earned[depositant];
            payable(depositant).transfer(earned[depositant]);
            earned[depositant] = 0;
        }
    }

    /**
     * @dev Withdraw all deposited amount to the depositant address and transfer the deposited TIME from depositant to the Employer account
     **/
    function _withdraw() private {
        require(deposited[msg.sender] > 0, "Depositant does not have any amount to withdraw");
        require(currentDepositedNative >= deposited[msg.sender], "Not enough in contract to withdraw");
        remainingTime[address(this)] += remainingTime[msg.sender];
        remainingTime[msg.sender] = 0;
        currentDepositedNative -= deposited[msg.sender];
        payable(msg.sender).transfer(deposited[msg.sender]);
        deposited[msg.sender] = 0;       
    }

    /**
     * @dev Deposit only TIME in order to anticipate interest over previous deposited ETH
     * @notice Pre-condition: the depositant must have previous deposited ETH and also should approve (allow to spend) the TIME tokens to deposit. Anticipation is mandatory in this case
     * @param timeAmount The amount in TIME an investor should deposit to anticipate
     **/
    function anticipate(uint256 timeAmount) public payable nonReentrant update(false) {
        require(deposited[msg.sender] > 0, "Depositant does not have any amount to anticipate");
        require(timeAmount > 0, "Please deposit some TIME amount");
        ITimeToken timeToken = ITimeToken(TIME_TOKEN_ADDRESS);
        require(timeToken.allowance(msg.sender, address(this)) >= timeAmount, "Should allow TIME to be spent");
        try timeToken.transferFrom(msg.sender, address(this), timeAmount) {
            totalDepositedTime += timeAmount;
            _anticipateEarnings(timeAmount);
        } catch {
            revert("Problem when transferring TIME");
        }
    }      

    /**
     * @dev Calculate the anticipation fee an investor needs to pay in order to anticipate TIME Tokens in the Employer contract
     * @return fee The fee amount calculated
     **/
    function anticipationFee() public view returns (uint256) {
        return ITimeToken(TIME_TOKEN_ADDRESS).fee().mulDiv(11, 1);
    }

    /**
     * @dev Compound available earnings into the depositant account
     * @notice Pre-condition: the depositant should approve (allow to spend) the TIME tokens to deposit. Also, if they want to anticipate yield, they must enabled anticipation before the function call
     * @param timeAmount (Optional. Can be zero) The amount of TIME Tokens an investor wants to continue receiveing or anticipating earnings 
     * @param mustAnticipateTime Informs whether an investor wants to anticipate earnings to be compounded
     **/
    function compound(uint256 timeAmount, bool mustAnticipateTime) public nonReentrant update(true) {
        require(deposited[msg.sender] > 0, "Depositant does not have any amount to compound");
        if (mustAnticipateTime) 
            require(anticipationEnabled[msg.sender], "Depositant is not enabled to anticipate TIME");
        if (timeAmount > 0) {
            ITimeToken timeToken = ITimeToken(TIME_TOKEN_ADDRESS);
            require(timeToken.allowance(msg.sender, address(this)) >= timeAmount, "Should allow TIME to be spent");
            try timeToken.transferFrom(msg.sender, address(this), timeAmount) {
                totalDepositedTime += timeAmount;
                if (mustAnticipateTime) {
                    _anticipateEarnings(timeAmount);
                } else {
                    remainingTime[msg.sender] += timeAmount;               
                }
            } catch {
                revert("Problem when transferring TIME");
            }
        }
    }

    /**
     * @dev Deposit ETH and TIME in order to earn interest over them
     * @notice Pre-condition: the depositant should approve (allow to spend) the TIME tokens to deposit. Also, if they want to anticipate yield, they must enabled anticipation before the function call
     * @param timeAmount The amount in TIME an investor should deposit
     * @param mustAnticipateTime Informs if the depositant wants to anticipate the yield or not
     **/
    function deposit(uint256 timeAmount, bool mustAnticipateTime) public payable nonReentrant update(false) {
        require(msg.value > 0, "Please deposit some amount");
        require(timeAmount > 0, "Please deposit some TIME amount");
        if (mustAnticipateTime)
            require(anticipationEnabled[msg.sender], "Depositant is not enabled to anticipate TIME");
        ITimeToken timeToken = ITimeToken(TIME_TOKEN_ADDRESS);
        require(timeToken.allowance(msg.sender, address(this)) >= timeAmount, "Should allow TIME to be spent");

        uint256 comission = msg.value / 50;
        uint256 depositAmount = msg.value - comission;
        deposited[msg.sender] += depositAmount;
        currentDepositedNative += depositAmount;
        totalDepositedNative += msg.value;
        try timeToken.transferFrom(msg.sender, address(this), timeAmount) {
            totalDepositedTime += timeAmount;
            if (mustAnticipateTime) {
                _anticipateEarnings(timeAmount);
            } else {
                remainingTime[msg.sender] += timeAmount;               
            }
            _payComission(comission);
        } catch {
            revert("Problem when transferring TIME");
        }
    }

    /**
     * @dev Public call for earning interest for Employer (if it has any to receive)
     **/
    function earn() public nonReentrant {
        _earnInterestAndAllocate(ITimeToken(TIME_TOKEN_ADDRESS));
    }

    /**
     * @dev Enable an investor to anticipate yields using TIME tokens
     **/
    function enableAnticipation() public payable nonReentrant update(false) {
        require(!anticipationEnabled[msg.sender], "Address is already enabled for TIME anticipation");
        uint256 fee = ITimeToken(TIME_TOKEN_ADDRESS).fee().mulDiv(10, 1);
        require(msg.value >= fee, "Please provide the enough fee amount to enable TIME anticipation");
        uint256 comission = fee / 5;
        _payComission(comission);
        totalEarnedNative += msg.value;
        availableNative += (msg.value - comission);
        anticipationEnabled[msg.sender] = true;
    }

    /**
     * @dev Inform the current Return Of Investment the Employer contract is giving
     * @return roi The current amount returned to investors
     **/
    function getCurrentROI() public view returns (uint256) {
        if (availableNative == 0)
            return 0;
        if (currentDepositedNative == 0)
            return 10**50;
        return availableNative.mulDiv(FACTOR, currentDepositedNative);
    }

    /**
     * @dev Inform the current Return Of Investment per Block the Employer contract is giving
     * @return roi The current amount per block returned to investors
     **/
    function getCurrentROIPerBlock() public view returns (uint256) {
        return getCurrentROI().mulDiv(FACTOR, ONE_YEAR);
    }

    /**
     * @dev Inform the historical Return Of Investment the Employer contract is giving
     * @return roi The historical amount returned to investors
     **/
    function getROI() public view returns (uint256) {
        if (totalEarnedNative == 0)
            return 0;
        if (totalDepositedNative == 0)
            return 10**50;
        return totalEarnedNative.mulDiv(FACTOR, totalDepositedNative);
    }

    /**
     * @dev Inform the historical Return Of Investment per Block the Employer contract is giving
     * @return roi The historical amount per block returned to investors
     **/
    function getROIPerBlock() public view returns (uint256) {
        return getROI().mulDiv(FACTOR, ONE_YEAR);
    }

    /**
     * @dev Inform the earnings an investor can anticipate (without waiting for a given time) according to the informed TIME amount
     * @param depositant Address of the depositant account
     * @param anticipatedTime Amount of TIME informed by a depositant as anticipation
     * @return earnings Amount a depositant can anticipate
     **/
    function queryAnticipatedEarnings(address depositant, uint256 anticipatedTime) public view returns (uint256) {
        return (availableNative.mulDiv(anticipatedTime, 1)).mulDiv(deposited[depositant], ONE_YEAR.mulDiv(currentDepositedNative, 1) + 1);
    }

    /**
     * @dev Inform the earnings an investor can currently receive
     * @param depositant Address of the depositant account
     * @return earnings Amount a depositant can receive
     **/
    function queryEarnings(address depositant) public view returns (uint256) {
        uint256 numberOfBlocks = (block.number - lastBlock[depositant]).mulDiv(D, 1);
        if (numberOfBlocks <= remainingTime[depositant]) {    
            return (availableNative.mulDiv(numberOfBlocks, 1)).mulDiv(deposited[depositant], ONE_YEAR.mulDiv(currentDepositedNative, 1) + 1);
        } else {
            return (availableNative.mulDiv(remainingTime[depositant], 1)).mulDiv(deposited[depositant], ONE_YEAR.mulDiv(currentDepositedNative, 1) + 1);
        }
    }

    /**
     * @dev Withdraw earnings (only) of a depositant (msg.sender)
     * @notice All functions are in modifiers. It only checks if the depositant has earning something
     **/
    function withdrawEarnings() public nonReentrant update(false) {
        require(earned[msg.sender] > 0, "Depositant does not have any earnings to withdraw");
    }

    /**
     * @dev Withdraw all deposited values of a depositant (msg.sender)
     **/
    function withdrawDeposit() public nonReentrant update(false) {
        _withdraw();
    }

    /**
     * @dev Withdraw all deposited values of a depositant (msg.sender) without any check for earnings (emergency)
     **/
    function withdrawDepositEmergency() public nonReentrant {
        _withdraw();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITimeToken {
    function DEVELOPER_ADDRESS() external returns (address);
    function BASE_FEE() external returns (uint256);
    function COMISSION_RATE() external returns (uint256);
    function SHARE_RATE() external returns (uint256);
    function TIME_BASE_LIQUIDITY() external returns (uint256);
    function TIME_BASE_FEE() external returns (uint256);
    function TOLERANCE() external returns (uint256);
    function dividendPerToken() external returns (uint256);
    function firstBlock() external returns (uint256);
    function liquidityFactorNative() external returns (uint256);
    function liquidityFactorTime() external returns (uint256);
    function numberOfHolders() external returns (uint256);
    function numberOfMiners() external returns (uint256);
    function sharedBalance() external returns (uint256);
    function poolBalance() external returns (uint256);
    function totalMinted() external returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function burn(uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool success);
    function averageMiningRate() external view returns (uint256);
    function donateEth() external payable;
    function enableMining() external payable;
    function enableMiningWithTimeToken() external;
    function fee() external view returns (uint256);
    function feeInTime() external view returns (uint256);
    function mining() external;
    function saveTime() external payable returns (bool success);
    function spendTime(uint256 timeAmount) external returns (bool success);
    function swapPriceNative(uint256 amountNative) external view returns (uint256);
    function swapPriceTimeInverse(uint256 amountTime) external view returns (uint256);
    function accountShareBalance(address account) external view returns (uint256);
    function withdrawableShareBalance(address account) external view returns (uint256);
    function withdrawShare() external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. It the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`.
        // We also know that `k`, the position of the most significant bit, is such that `msb(a) = 2**k`.
        // This gives `2**k < a <= 2**(k+1)` → `2**(k/2) <= sqrt(a) < 2 ** (k/2+1)`.
        // Using an algorithm similar to the msb conmputation, we are able to compute `result = 2**(k/2)` which is a
        // good first aproximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1;
        uint256 x = a;
        if (x >> 128 > 0) {
            x >>= 128;
            result <<= 64;
        }
        if (x >> 64 > 0) {
            x >>= 64;
            result <<= 32;
        }
        if (x >> 32 > 0) {
            x >>= 32;
            result <<= 16;
        }
        if (x >> 16 > 0) {
            x >>= 16;
            result <<= 8;
        }
        if (x >> 8 > 0) {
            x >>= 8;
            result <<= 4;
        }
        if (x >> 4 > 0) {
            x >>= 4;
            result <<= 2;
        }
        if (x >> 2 > 0) {
            result <<= 1;
        }

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (rounding == Rounding.Up && result * result < a) {
            result += 1;
        }
        return result;
    }
}