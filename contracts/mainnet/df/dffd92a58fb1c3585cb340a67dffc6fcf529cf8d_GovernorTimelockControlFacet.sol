// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

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
        return a > b ? a : b;
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
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

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
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorCommon} from "src/governor/lib/GovernorCommon.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {IGovernorTimelockControl} from "src/interfaces/IGovernorTimelockControl.sol";
import {ITimelockController} from "src/interfaces/ITimelockController.sol";
import {AccessControl} from "src/utils/AccessControl.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Timelock Control Facet
 * @author Origami
 * @notice Logic for controlling the timelock queue and execution of proposals.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact [email protected]
 */
contract GovernorTimelockControlFacet is IGovernorTimelockControl, AccessControl {
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    /**
     * @notice returns the timelock controller
     * @return the timelock controller
     */
    function timelock() public view returns (ITimelockController) {
        return ITimelockController(GovernorStorage.configStorage().timelock);
    }

    // this function has overloaded behavior in the OZ contracts, acting as a
    // way to count down to execution as well as indicating if it was executed
    // or canceled. We don't need this overloaded functionality since we track
    // execution and cancellation globally in the GovernorStorage contract.
    /**
     * @dev Public accessor to check the eta of a queued proposal
     * @param proposalId the id of the proposal
     * @return the eta of the proposal
     */
    function proposalEta(uint256 proposalId) external view returns (uint256) {
        return GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp;
    }

    /**
     * @notice queue a set of transactions to be executed after a delay
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return proposalId the id of the proposal
     */
    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);

        require(
            GovernorCommon.state(proposalId) == IGovernor.ProposalState.Succeeded, "Governor: proposal not successful"
        );

        uint256 delay = timelock().getMinDelay();
        GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp = block.timestamp + delay;

        timelock().scheduleBatch(targets, values, calldatas, 0, descriptionHash, delay);

        emit ProposalQueued(proposalId, block.timestamp + delay);

        return proposalId;
    }

    /**
     * @notice execute a queued proposal after the delay has passed
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return the id of the proposal
     */
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
        require(GovernorCommon.state(proposalId) == IGovernor.ProposalState.Queued, "Governor: proposal not queued");
        timelock().executeBatch{value: msg.value}(targets, values, calldatas, 0, descriptionHash);
        GovernorStorage.proposal(proposalId).executed = true;
        emit ProposalExecuted(proposalId);
        return proposalId;
    }

    /**
     * @notice cancel a proposal queued for timelock execution
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return the id of the proposal
     */
    function cancel(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external onlyRole(CANCELLER_ROLE) returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
        IGovernor.ProposalState state = GovernorCommon.state(proposalId);

        require(
            state != IGovernor.ProposalState.Canceled && state != IGovernor.ProposalState.Expired
                && state != IGovernor.ProposalState.Executed,
            "Governor: proposal not queued"
        );

        GovernorStorage.proposal(proposalId).canceled = true;
        emit ProposalCanceled(proposalId);

        if (GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp != 0) {
            bytes32 operationHash = timelock().hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
            timelock().cancel(operationHash);
            delete GovernorStorage.proposalStorage().timelockQueue[proposalId];
        }

        return proposalId;
    }

    /**
     * @notice update the timelock address
     * @param newTimelock the new timelock address
     */
    function updateTimelock(address payable newTimelock) external onlyGovernance {
        address oldTimelock = GovernorStorage.configStorage().timelock;
        emit TimelockChange(oldTimelock, newTimelock);
        GovernorStorage.configStorage().timelock = newTimelock;
    }

    modifier onlyGovernance() {
        require(msg.sender == GovernorStorage.configStorage().timelock, "Governor: onlyGovernance");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SimpleCounting} from "src/governor/lib/SimpleCounting.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @author Origami
 * @dev Common functions for the Governor modules.
 * @custom:security-contact [email protected]
 */
library GovernorCommon {
    /**
     * @notice generates the hash of a proposal
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return the hash of the proposal, used as an id
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    /**
     * @notice execution state for a proposal, intended for use on successful proposals
     * @param proposalId the id of the proposal
     * @param status the current status of the proposal
     * @return the execution state of the proposal else the current status
     */
    function succededState(uint256 proposalId, IGovernor.ProposalState status)
        internal
        view
        returns (IGovernor.ProposalState)
    {
        if (status != IGovernor.ProposalState.Succeeded) {
            return status;
        }

        GovernorStorage.TimelockQueue storage queue = GovernorStorage.proposalStorage().timelockQueue[proposalId];
        if (queue.timestamp == 0) {
            return IGovernor.ProposalState.Succeeded;
        } else {
            return IGovernor.ProposalState.Queued;
        }
    }

    function state(uint256 proposalId) internal view returns (IGovernor.ProposalState) {
        GovernorStorage.ProposalCore storage proposal = GovernorStorage.proposal(proposalId);

        if (proposal.executed) {
            return IGovernor.ProposalState.Executed;
        }

        if (proposal.canceled) {
            return IGovernor.ProposalState.Canceled;
        }

        if (proposal.snapshot == 0) {
            // coverage seems convinced this is not invoked, but we have a test that proves it is
            revert("Governor: unknown proposal id");
        }

        if (proposal.snapshot >= block.timestamp) {
            return IGovernor.ProposalState.Pending;
        }

        if (proposal.deadline >= block.timestamp) {
            return IGovernor.ProposalState.Active;
        }

        if (SimpleCounting.quorumReached(proposalId) && SimpleCounting.voteSucceeded(proposalId)) {
            return succededState(proposalId, IGovernor.ProposalState.Succeeded);
        } else {
            return IGovernor.ProposalState.Defeated;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IVotes} from "src/interfaces/IVotes.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Quorum shared functions
 * @author Origami
 * @custom:security-contact [email protected]
 */
library GovernorQuorum {
    /**
     * @dev Returns the quorum numerator for a specific proposalId. This value is set from global config at the time of proposal creation.
     */
    function quorumNumerator(uint256 proposalId) internal view returns (uint128) {
        return GovernorStorage.proposal(proposalId).quorumNumerator;
    }

    /**
     * @dev Returns the quorum denominator. Typically set to 100, but is configurable.
     */
    function quorumDenominator(uint256 proposalId) internal view returns (uint128) {
        return GovernorStorage.proposal(proposalId).quorumDenominator;
    }

    /**
     * @dev Returns the quorum for a specific proposal's counting token as of its time of creation, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) internal view returns (uint256) {
        address proposalToken = GovernorStorage.proposal(proposalId).proposalToken;
        uint256 snapshot = GovernorStorage.proposal(proposalId).snapshot;
        uint256 supply = IVotes(proposalToken).getPastTotalSupply(snapshot);
        return (supply * quorumNumerator(proposalId)) / quorumDenominator(proposalId);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorQuorum} from "src/governor/lib/GovernorQuorum.sol";
import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";
import {Voting} from "src/governor/lib/Voting.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Simple Counting strategy
 * @author Origami
 * @notice Implements swappable counting strategies at the proposal level.
 * @custom:security-contact [email protected]
 */
library SimpleCounting {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    /**
     * @notice a required function from IGovernor that declares what Governor style we support and how we derive quorum.
     * @dev See {IGovernor-COUNTING_MODE}.
     * @return string indicating the counting mode.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() internal pure returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @notice sets the vote for a given proposal and account in a manner that is compatible with SimpleCounting strategies.
     * @param proposalId the proposal to record the vote for
     * @param account the account that is voting
     * @param support the VoteType that the account is voting
     * @param weight the weight of their vote as of the proposal snapshot
     */
    function setVote(uint256 proposalId, address account, uint8 support, uint256 weight) internal {
        bytes4 weightingSelector = GovernorStorage.proposal(proposalId).countingStrategy;

        uint256 calculatedWeight = TokenWeightStrategy.applyStrategy(weight, weightingSelector);
        Voting.setVote(proposalId, account, abi.encode(VoteType(support), weight, calculatedWeight));
    }

    /**
     * @dev used by OrigamiGovernor when totaling proposal outcomes. We defer tallying so that individual voters can change their vote during the voting period.
     * @param proposalId the id of the proposal to retrieve voters for.
     * @return the list of voters for the proposal.
     */
    function getProposalVoters(uint256 proposalId) internal view returns (address[] memory) {
        return GovernorStorage.proposalVoters(proposalId);
    }

    /**
     * @dev decodes the vote for a given proposal and voter.
     * @param proposalId the id of the proposal.
     * @param voter the address of the voter.
     * @return the vote type, the weight of the vote, and the weight of the vote with the weighting strategy applied.
     */
    function getVote(uint256 proposalId, address voter) internal view returns (VoteType, uint256, uint256) {
        return abi.decode(Voting.getVote(proposalId, voter), (VoteType, uint256, uint256));
    }

    /**
     * @notice returns the current votes for, against, or abstaining for a given proposal. Once the voting period has lapsed, this is used to determine the outcome.
     * @dev this delegates weight calculation to the strategy specified in the params
     * @param proposalId the id of the proposal to get the votes for.
     * @return againstVotes - the number of votes against the proposal.
     * @return forVotes - the number of votes for the proposal.
     * @return abstainVotes - the number of votes abstaining from the vote.
     */
    function simpleProposalVotes(uint256 proposalId)
        internal
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        address[] memory voters = GovernorStorage.proposalVoters(proposalId);
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            (VoteType support,, uint256 calculatedWeight) = getVote(proposalId, voter);
            if (support == VoteType.Abstain) {
                abstainVotes += calculatedWeight;
            } else if (support == VoteType.For) {
                forVotes += calculatedWeight;
            } else if (support == VoteType.Against) {
                againstVotes += calculatedWeight;
            }
        }
    }

    /**
     * @dev implementation of {Governor-quorumReached} that is compatible with the SimpleCounting strategies.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the quorum has been reached.
     */
    function quorumReached(uint256 proposalId) internal view returns (bool) {
        (, uint256 forVotes, uint256 abstainVotes) = simpleProposalVotes(proposalId);
        bytes4 countingStrategy = GovernorStorage.proposal(proposalId).countingStrategy;
        return TokenWeightStrategy.applyStrategy(GovernorQuorum.quorum(proposalId), countingStrategy)
            <= forVotes + abstainVotes;
    }

    /**
     * @dev returns the winning option for a given proposal.
     * @param proposalId the id of the proposal to check.
     * @return VoteType - the winning option.
     */
    function winningOption(uint256 proposalId) internal view returns (VoteType) {
        (uint256 againstVotes, uint256 forVotes,) = simpleProposalVotes(proposalId);
        if (forVotes >= againstVotes) {
            return VoteType.For;
        } else {
            return VoteType.Against;
        }
    }

    /**
     * @dev returns true if the vote succeeded.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the vote succeeded.
     */
    function voteSucceeded(uint256 proposalId) internal view returns (bool) {
        return winningOption(proposalId) == VoteType.For;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Simple Counting strategy
 * @author Origami
 * @notice Implements swappable counting strategies at the proposal level.
 * @custom:security-contact [email protected]
 */
library TokenWeightStrategy {
    bytes4 internal constant simpleWeightSelector = bytes4(keccak256("simpleWeight(uint256)"));
    bytes4 internal constant quadraticWeightSelector = bytes4(keccak256("quadraticWeight(uint256)"));

    /**
     * @notice Checks if the provided selector is a known strategy.
     * @param weightingSelector the selector to check.
     * @return true if the selector is a known strategy.
     */
    function knownStrategy(bytes4 weightingSelector) internal pure returns (bool) {
        return weightingSelector == simpleWeightSelector || weightingSelector == quadraticWeightSelector;
    }

    /**
     * @notice Applies the indicated weighting strategy to the amount `weight` that is supplied.
     * @dev the staticcall is only executed against this contract and is checked for success before failing to a revert if the selector isn't found on this contract.
     * @param weight the token weight to apply the weighting strategy to.
     * @param weightingSelector an encoded selector to use as a weighting strategy implementation.
     * @return the weight with the weighting strategy applied to it.
     */
    function applyStrategy(uint256 weight, bytes4 weightingSelector) internal pure returns (uint256) {
        if (weightingSelector == simpleWeightSelector) {
            return simpleWeight(weight);
        } else if (weightingSelector == quadraticWeightSelector) {
            return quadraticWeight(weight);
        } else {
            revert("Governor: weighting strategy not found");
        }
    }

    /**
     * @notice simple weight calculation does not apply any weighting strategy. It is an integer identity function.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function simpleWeight(uint256 weight) internal pure returns (uint256) {
        return weight;
    }

    /**
     * @notice quadratic weight calculation returns square root of the weight.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function quadraticWeight(uint256 weight) internal pure returns (uint256) {
        return squareRoot(weight);
    }

    /**
     * @dev square root algorithm from https://github.com/ethereum/dapp-bin/pull/50#issuecomment-1075267374
     * @param x the number to derive the square root of.
     * @return y - the square root of x.
     */
    function squareRoot(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Core voting interface
 * @author Origami
 * @custom:security-contact [email protected]
 */
library Voting {
    function setVote(uint256 proposalId, address account, bytes memory vote) internal {
        GovernorStorage.setProposalVote(proposalId, account, vote);
        GovernorStorage.proposalVoters(proposalId).push(account);
        GovernorStorage.setProposalHasVoted(proposalId, account);
    }

    function getVote(uint256 proposalId, address account) internal view returns (bytes memory) {
        return GovernorStorage.proposalVote(proposalId, account);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 * @author Origami
 * @author Modified from OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev Interface of the {Governor} core.
 */
interface IGovernor {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /**
     * @dev Emitted when a proposal is created.
     */
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startTimestamp,
        uint256 endTimestamp,
        string description
    );

    /**
     * @dev Emitted when a proposal is canceled.
     */
    event ProposalCanceled(uint256 proposalId);

    /**
     * @dev Emitted when a proposal is executed.
     */
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev Emitted when a vote is cast without params.
     *
     * Note: `support` values should be seen as buckets. Their interpretation depends on the voting module used.
     */
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /**
     * @notice hashes proposal params to create a proposalId.
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the hash of the description of the proposal.
     * @return the proposalId.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    /**
     * @notice returns the current ProposalState for a proposal.
     * @param proposalId the id of the proposal.
     * @return the ProposalState.
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    /**
     * @notice returns the snapshot timestamp for a proposal.
     * @dev snapshot is performed at the end of this block, hence voting for the
     * proposal starts at any timestamp greater than this, but may also be less
     * than the timestamp of the next block. Block issuance times vary per
     * chain.
     * @param proposalId the id of the proposal.
     * @return the snapshot timestamp.
     */
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    /**
     * @notice returns the deadline timestamp for a proposal.
     * @dev Votes close after this block's timestamp, so it is possible to cast a vote during this block.
     * @param proposalId the id of the proposal.
     * @return the deadline block.
     */
    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Get the configured quorum for a proposal.
     * @param proposalId The id of the proposal to get the quorum for.
     * @return The quorum for the given proposal.
     */
    function quorum(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Get votes for the given account at the given timestamp using proposal token.
     * @dev delegates the implementation to the token used for the given proposal.
     * @param account the account to get the vote weight for.
     * @param timestamp the block timestamp the snapshot is needed for.
     * @param proposalToken the token to use for counting votes.
     */
    function getVotes(address account, uint256 timestamp, address proposalToken) external view returns (uint256);

    /**
     * @notice Indicates whether or not an account has voted on a proposal.
     * @dev Unlike Bravo, we don't want to prevent multiple votes, we instead update their previous vote.
     * @return true if the account has voted on the proposal, false otherwise.
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    /**
     * @notice The current nonce for a given account.
     * @dev we use these nonces to prevent replay attacks.
     */
    function getAccountNonce(address account) external view returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The strategy to use for counting votes.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategy(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on the proposal.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made on the proposal.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made on the proposal.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The bytes4 function selector for the strategy to use for counting votes.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategyBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 proposalId);

    /**
     * @notice Propose a new action to be performed by the governor, with params specifying proposal token and counting strategy. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param params The parameters of the proposal, encoded as a tuple of (proposalToken, countingStrategy).
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParamsBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy.
     * @dev See {GovernorUpgradeable-_propose}.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param params the encoded bytes that specify the proposal's counting strategy and the token to use for counting.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice propose a new action to be performed by the governor.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @return proposalId The id of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /**
     * @notice Cast a vote on a proposal.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @return weight The weight of the vote.
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal with a reason.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @return weight The weight of the vote.
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason)
        external
        returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal with a reason by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ITimelockController} from "src/interfaces/ITimelockController.sol";

interface IGovernorTimelockControl {
    event TimelockChange(address oldTimelock, address newTimelock);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev Public accessor to check the eta of a queued proposal
     */
    function proposalEta(uint256 proposalId) external view returns (uint256);

    /**
     * @dev Public accessor to return the address of the timelock
     */
    function timelock() external returns (ITimelockController);

    /**
     * @dev Queue a proposal to be executed after a delay.
     *
     * Emits a {ProposalQueued} event.
     */
    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    /**
     * @dev Execute a successful proposal. This requires the quorum to be reached, the vote to be successful, and the
     * deadline to be reached.
     *
     * Emits a {ProposalExecuted} event.
     *
     * Note: some module can modify the requirements for execution, for example by adding an additional timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);

    /**
     * @dev Cancel a proposal. This can only be done if the proposal is still pending or queued, or if the module that
     * implements the {IGovernor} interface has a different implementation for this function.
     *
     * Emits a {ProposalCanceled} event.
     */
    function cancel(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    /**
     * @dev Update the timelock.
     *
     * Emits a {TimelockChange} event.
     */
    function updateTimelock(address payable newTimelock) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface ITimelockController {
    function getMinDelay() external view returns (uint256);

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external returns (bytes32 hash);

    function cancel(bytes32 id) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (governance/utils/IVotes.sol)
pragma solidity 0.8.16;

/**
 * @notice Common interface for {ERC20Votes}, {ERC721Votes}, and other {Votes}-enabled contracts.
 */
interface IVotes {
    /// @dev Emitted when an account changes their delegatee.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @dev Emitted when a token transfer or delegatee change results in changes to a delegatee's number of votes.
    event DelegateVotesChanged(address indexed delegatee, uint256 previousBalance, uint256 newBalance);

    /// @dev Returns the current amount of votes that `account` has.
    function getVotes(address account) external view returns (uint256);

    /// @notice Returns the amount of votes that `account` had at the end of a past block's timestamp.
    function getPastVotes(address account, uint256 timestamp) external view returns (uint256);

    /**
     * @notice Returns the total supply of votes available at the end of a past block's timestamp.
     * @param timestamp The timestamp to check the total supply of votes at.
     * @return The total supply of votes available at the last checkpoint before `timestamp`.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     */
    function getPastTotalSupply(uint256 timestamp) external view returns (uint256);

    /// @notice Returns the EIP712 domain separator for this contract.
    function domainSeparatorV4() external view returns (bytes32);

    /**
     * @notice Returns the current nonce for `delegator`.
     * @dev Used to prevent replay attacks when delegating by signature.
     * @param delegator The address of the delegator to get the nonce for.
     * @return The nonce for `delegator`.
     */
    function getDelegatorNonce(address delegator) external view returns (uint256);

    /**
     * @notice Returns the delegatee that `account` has chosen.
     * @param account The address of the account to get the delegatee for.
     * @return The address of the delegatee for `account`.
     */
    function delegates(address account) external view returns (address);

    /**
     * @notice Delegates votes from the sender to `delegatee`.
     * @param delegatee The address to delegate votes to.
     */
    function delegate(address delegatee) external;

    /**
     * @notice Delegates votes from the signer to `delegatee`.
     * @dev This allows execution by proxy of a delegation, so that signers do not need to pay gas.
     * @param delegatee The address to delegate votes to.
     * @param nonce The nonce of the delegator.
     * @param expiry The timestamp at which the delegation expires.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity 0.8.16;

import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {AccessControlStorage} from "src/utils/AccessControlStorage.sol";

import {Strings} from "@oz/utils/Strings.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 *
 * @author Origami
 * @author Modified from OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol) to conform to and use Diamond Storage and minimize certain viral OZ dependencies.
 * @custom:security-contact [email protected]
 */
contract AccessControl is IAccessControl {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return AccessControlStorage.roleStorage().roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `msg.sender` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view {
        _checkRole(role, msg.sender);
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return AccessControlStorage.roleStorage().roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        AccessControlStorage.roleStorage().roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            AccessControlStorage.roleStorage().roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            AccessControlStorage.roleStorage().roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library AccessControlStorage {
    bytes32 public constant ROLE_STORAGE_POSITION = keccak256("com.origami.accesscontrol.role");

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    struct RoleStorage {
        mapping(bytes32 => RoleData) roles;
    }

    function roleStorage() internal pure returns (RoleStorage storage rs) {
        bytes32 position = ROLE_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            rs.slot := position
        }
    }

    function roleData(bytes32 role) internal view returns (RoleData storage rd) {
        RoleStorage storage rs = roleStorage();
        rd = rs.roles[role];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";

library GovernorStorage {
    bytes32 public constant CONFIG_STORAGE_POSITION = keccak256("com.origami.governor.configStorage");
    bytes32 public constant PROPOSAL_STORAGE_POSITION = keccak256("com.origami.governor.proposalStorage");

    /**
     * @dev Emitted when a counting strategy's validity is enabled.
     * @param countingStrategy The counting strategy's bytes4 signature.
     * @param enabled Whether the counting strategy is enabled.
     */
    event CountingStrategyEnabled(bytes4 countingStrategy, bool enabled);

    /**
     * @dev Emitted when the default counting strategy is set.
     * @param oldDefaultCountingStrategy The previous default counting strategy.
     * @param newDefaultCountingStrategy The new default counting strategy.
     */
    event DefaultCountingStrategySet(bytes4 oldDefaultCountingStrategy, bytes4 newDefaultCountingStrategy);

    /**
     * @dev Emitted when the default proposal token is set.
     * @param oldDefaultProposalToken The previous default proposal token.
     * @param newDefaultProposalToken The new default proposal token.
     */
    event DefaultProposalTokenSet(address oldDefaultProposalToken, address newDefaultProposalToken);

    /**
     * @dev Emitted when the proposal token is enabled or disabled.
     * @param proposalToken The proposal token's address.
     * @param enabled Whether the proposal token is enabled.
     */
    event ProposalTokenEnabled(address proposalToken, bool enabled);

    /**
     * @dev Emitted when the voting delay is set.
     * @param oldVotingDelay The previous voting delay.
     * @param newVotingDelay The new voting delay.
     */
    event VotingDelaySet(uint64 oldVotingDelay, uint64 newVotingDelay);

    /**
     * @dev Emitted when the voting period is set.
     * @param oldVotingPeriod The previous voting period.
     * @param newVotingPeriod The new voting period.
     */
    event VotingPeriodSet(uint64 oldVotingPeriod, uint64 newVotingPeriod);

    /**
     * @dev Emitted when the proposal threshold is set.
     * @param oldProposalThreshold The previous proposal threshold.
     * @param newProposalThreshold The new proposal threshold.
     */
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    /**
     * @dev Emitted when the proposal threshold token is set.
     * @param oldProposalThresholdToken The previous proposal threshold.
     * @param newProposalThresholdToken The new proposal threshold.
     */
    event ProposalThresholdTokenSet(address oldProposalThresholdToken, address newProposalThresholdToken);

    /**
     * @dev Emitted when the quorum numerator is set.
     * @param oldQuorumNumerator The previous quorum numerator.
     * @param newQuorumNumerator The new quorum numerator.
     */
    event QuorumNumeratorSet(uint128 oldQuorumNumerator, uint128 newQuorumNumerator);

    /**
     * @dev Emitted when the quorum denominator is set.
     * @param oldQuorumDenominator The previous quorum denominator.
     * @param newQuorumDenominator The new quorum denominator.
     */
    event QuorumDenominatorSet(uint128 oldQuorumDenominator, uint128 newQuorumDenominator);

    /**
     * @dev Emitted when the membership token is set.
     * @param oldMembershipToken The previous membership token.
     * @param newMembershipToken The new membership token.
     */
    event MembershipTokenSet(address oldMembershipToken, address newMembershipToken);

    /**
     * @dev Emitted when the governance token is set.
     * @param oldGovernanceToken The previous governance token.
     * @param newGovernanceToken The new governance token.
     */
    event GovernanceTokenSet(address oldGovernanceToken, address newGovernanceToken);

    struct ProposalCore {
        address proposalToken;
        bytes4 countingStrategy;
        uint128 quorumNumerator;
        uint128 quorumDenominator;
        uint256 snapshot;
        uint256 deadline;
        bytes params;
        bool canceled;
        bool executed;
    }

    struct GovernorConfig {
        string name;
        address admin;
        address payable timelock;
        address defaultProposalToken;
        bytes4 defaultCountingStrategy;
        address membershipToken;
        address governanceToken;
        address proposalThresholdToken;
        uint64 votingDelay; // 2^64 seconds is 585 years
        uint64 votingPeriod;
        uint128 quorumNumerator;
        uint128 quorumDenominator;
        uint256 proposalThreshold;
        mapping(address => bool) proposalTokens;
        mapping(bytes4 => bool) countingStrategies;
    }

    struct TimelockQueue {
        uint256 timestamp;
    }

    struct ProposalStorage {
        // proposalId => ProposalCore
        mapping(uint256 => ProposalCore) proposals;
        // proposalId => voter address => voteBytes
        mapping(uint256 => mapping(address => bytes)) proposalVote;
        // proposalId => voter addresses (provides index)
        mapping(uint256 => address[]) proposalVoters;
        // proposalId => voter address => true if voted
        mapping(uint256 => mapping(address => bool)) proposalHasVoted;
        // proposalId => TimelockQueue
        mapping(uint256 => TimelockQueue) timelockQueue;
        // voter address => nonce
        mapping(address => uint256) nonces;
    }

    /**
     * @dev returns the ConfigStorage location.
     */
    function configStorage() internal pure returns (GovernorConfig storage gs) {
        bytes32 position = CONFIG_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            gs.slot := position
        }
    }

    /**
     * @dev determines if the provided token is the membership token or
     *  governance token. This is useful to ensure that functions that allow
     *  specifying a token address can't use unexpected tokens.
     * @param token the token address to check.
     * @return true if the token is the membership token or governance token.
     */
    function isConfiguredToken(address token) internal view returns (bool) {
        GovernorConfig storage cs = configStorage();
        return token == cs.membershipToken || token == cs.governanceToken;
    }

    /**
     * @notice determine if a counting strategy is enabled.
     * @param countingStrategy the counting strategy to check.
     * @return true if the counting strategy is enabled.
     */
    function isCountingStrategyEnabled(bytes4 countingStrategy) internal view returns (bool) {
        return configStorage().countingStrategies[countingStrategy];
    }

    /**
     * @notice determine if a token is enabled for proposal creation.
     * @param token the token address to check.
     * @return true if the token is enabled for proposal creation.
     */
    function isProposalTokenEnabled(address token) internal view returns (bool) {
        return configStorage().proposalTokens[token];
    }

    /**
     * @notice sets the default counting strategy.
     * @param newDefaultCountingStrategy the new default counting strategy address.
     * emits DefaultCountingStrategySet event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) internal {
        bytes4 oldDefaultCountingStrategy = configStorage().defaultCountingStrategy;
        configStorage().defaultCountingStrategy = newDefaultCountingStrategy;

        emit DefaultCountingStrategySet(oldDefaultCountingStrategy, newDefaultCountingStrategy);
    }

    /**
     * @notice sets the default proposal token.
     * @param newDefaultProposalToken the new default proposal token address.
     * emits DefaultProposalTokenSet event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) internal {
        address oldDefaultProposalToken = configStorage().defaultProposalToken;
        configStorage().defaultProposalToken = newDefaultProposalToken;

        emit DefaultProposalTokenSet(oldDefaultProposalToken, newDefaultProposalToken);
    }

    /**
     * @notice set proposal token validity
     * @param proposalToken the proposal token address.
     * @param enabled true if the proposal token is valid.
     * emits ProposalTokenEnabled event.
     */
    function enableProposalToken(address proposalToken, bool enabled) internal {
        require(isConfiguredToken(proposalToken), "Governor: proposal token must be a configured token");
        configStorage().proposalTokens[proposalToken] = enabled;

        emit ProposalTokenEnabled(proposalToken, enabled);
    }

    /**
     * @notice set counting strategy validity
     * @param countingStrategy the counting strategy selector.
     * @param enabled true if the counting strategy is valid.
     * emits CountingStrategyEnabled event.
     */
    function enableCountingStrategy(bytes4 countingStrategy, bool enabled) internal {
        // ensure it's a valid counting strategy selector
        require(TokenWeightStrategy.knownStrategy(countingStrategy), "Governor: counting strategy must be known");
        configStorage().countingStrategies[countingStrategy] = enabled;

        emit CountingStrategyEnabled(countingStrategy, enabled);
    }

    /**
     * @notice sets the Governance token.
     * @param newGovernanceToken the new governance token address.
     * emits GovernanceTokenSet event.
     */
    function setGovernanceToken(address newGovernanceToken) internal {
        address oldGovernanceToken = configStorage().governanceToken;
        configStorage().governanceToken = newGovernanceToken;

        emit GovernanceTokenSet(oldGovernanceToken, newGovernanceToken);
    }

    /**
     * @notice sets the Membership token.
     * @param newMembershipToken the new membership token address.
     * emits MembershipTokenSet event.
     */
    function setMembershipToken(address newMembershipToken) internal {
        address oldMembershipToken = configStorage().membershipToken;
        configStorage().membershipToken = newMembershipToken;

        emit MembershipTokenSet(oldMembershipToken, newMembershipToken);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * emits ProposalThresholdSet event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) internal {
        uint256 oldProposalThreshold = configStorage().proposalThreshold;
        configStorage().proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * emits ProposalThresholdTokenSet event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) internal {
        address oldProposalThresholdToken = configStorage().proposalThresholdToken;
        configStorage().proposalThresholdToken = newProposalThresholdToken;

        emit ProposalThresholdTokenSet(oldProposalThresholdToken, newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     * emits QuorumNumeratorSet event.
     */
    function setQuorumNumerator(uint128 newQuorumNumerator) internal {
        uint128 oldQuorumNumerator = configStorage().quorumNumerator;
        configStorage().quorumNumerator = newQuorumNumerator;

        emit QuorumNumeratorSet(oldQuorumNumerator, newQuorumNumerator);
    }

    /**
     * @notice Sets the quorum denominator.
     * @param newQuorumDenominator the new quorum denominator.
     * emits QuorumDenominatorSet event.
     */
    function setQuorumDenominator(uint128 newQuorumDenominator) internal {
        uint128 oldQuorumDenominator = configStorage().quorumDenominator;
        configStorage().quorumDenominator = newQuorumDenominator;

        emit QuorumDenominatorSet(oldQuorumDenominator, newQuorumDenominator);
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * emits VotingDelaySet event.
     */
    function setVotingDelay(uint64 newVotingDelay) internal {
        uint64 oldVotingDelay = configStorage().votingDelay;
        configStorage().votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, newVotingDelay);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * emits VotingPeriodSet event.
     */
    function setVotingPeriod(uint64 newVotingPeriod) internal {
        uint64 oldVotingPeriod = configStorage().votingPeriod;
        configStorage().votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, newVotingPeriod);
    }

    /**
     * @dev returns the ProposalStorage location.
     */
    function proposalStorage() internal pure returns (ProposalStorage storage ps) {
        bytes32 position = PROPOSAL_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            ps.slot := position
        }
    }

    /**
     * @notice creates a new proposal.
     * @param proposalId the proposal id.
     * @param proposalToken the proposal token.
     * @param countingStrategy the counting strategy.
     * @return ps the proposal core storage.
     */
    function createProposal(uint256 proposalId, address proposalToken, bytes4 countingStrategy)
        internal
        returns (ProposalCore storage ps)
    {
        // start populating the new ProposalCore struct
        ps = proposal(proposalId);
        GovernorConfig storage cs = configStorage();

        require(ps.snapshot == 0, "Governor: proposal already exists");

        ps.proposalToken = proposalToken;
        ps.countingStrategy = countingStrategy;
        ps.quorumNumerator = cs.quorumNumerator;
        ps.quorumDenominator = cs.quorumDenominator;
        // An epoch exceeding max UINT64 is 584,942,417,355 years from now.
        ps.snapshot = uint64(block.timestamp + cs.votingDelay);
        ps.deadline = ps.snapshot + cs.votingPeriod;

        return ps;
    }

    /**
     * @notice returns the proposal core storage.
     * @param proposalId the proposal id.
     * @return ps the proposal core storage.
     */
    function proposal(uint256 proposalId) internal view returns (ProposalCore storage) {
        return proposalStorage().proposals[proposalId];
    }

    /**
     * @notice returns the vote for an account on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @return the bytes representation of the vote
     */
    function proposalVote(uint256 proposalId, address account) internal view returns (bytes memory) {
        return proposalStorage().proposalVote[proposalId][account];
    }

    /**
     * @notice sets the vote for an account on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @param vote the bytes representation of the vote
     */
    function setProposalVote(uint256 proposalId, address account, bytes memory vote) internal {
        proposalStorage().proposalVote[proposalId][account] = vote;
    }

    /**
     * @notice returns the list of voters for a particular proposal.
     * @param proposalId the proposal id.
     * @return the list of voters.
     */
    function proposalVoters(uint256 proposalId) internal view returns (address[] storage) {
        return proposalStorage().proposalVoters[proposalId];
    }

    /**
     * @notice returns whether an account has voted on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @return true if the account has voted on the proposal.
     */
    function proposalHasVoted(uint256 proposalId, address account) internal view returns (bool) {
        return proposalStorage().proposalHasVoted[proposalId][account];
    }

    /**
     * @notice call to indicate that an account has voted on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     */
    function setProposalHasVoted(uint256 proposalId, address account) internal {
        proposalStorage().proposalHasVoted[proposalId][account] = true;
    }

    /**
     * @notice returns the account's current nonce.
     * @param account the account.
     * @return the account's nonce.
     */
    function getAccountNonce(address account) internal view returns (uint256) {
        return proposalStorage().nonces[account];
    }

    /**
     * @notice increments the account's nonce.
     * @param account the account.
     */
    function incrementAccountNonce(address account) internal {
        // This function is unchecked because it is virtually impossible to
        // overflow the nonce.  If a given account submitted one proposal per
        // second forever, it would take 5.44 septillion years to overflow.
        // ChatGPT agrees that's a long time.
        unchecked {
            GovernorStorage.proposalStorage().nonces[account]++;
        }
    }
}