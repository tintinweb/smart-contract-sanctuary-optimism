// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// SPDX-License-Identifier: GPL-3.0
// Modified version of a Implementation of contracts for ERC-4337 account abstraction via alternative mempool.
// Original code: https://github.com/eth-infinitism/account-abstraction/tree/releases/v0.4

pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */

import "../interfaces/IAccount.sol";
import "../interfaces/IPaymaster.sol";

import "../interfaces/IAggregatedAccount.sol";
import "../interfaces/IEntryPoint.sol";
import "./StakeManager.sol";
import "./SenderCreator.sol";

contract EntryPoint is IEntryPoint, StakeManager {
    using UserOperationLib for UserOperation;

    SenderCreator internal immutable senderCreator = new SenderCreator();

    // internal value used during simulation: need to query aggregator.
    address internal constant SIMULATE_FIND_AGGREGATOR = address(1);

    /**
     * for simulation purposes, validateUserOp (and validatePaymasterUserOp) must return this value
     * in case of signature failure, instead of revert.
     */
    uint256 public constant SIG_VALIDATION_FAILED = 1;

    uint256 public constant NONCE_VALIDATION_FAILED = 2;

    /**
     * compensate the caller's beneficiary address with the collected fees of all UserOperations.
     * @param beneficiary the address to receive the fees
     * @param amount amount to transfer.
     */
    function _compensate(address payable beneficiary, uint256 amount) internal {
        require(beneficiary != address(0), "AA90 invalid beneficiary");
        (bool success, ) = beneficiary.call{value: amount}("");
        require(success, "AA91 failed send to beneficiary");
    }

    /**
     * execute a user op
     * @param opIndex into into the opInfo array
     * @param userOp the userOp to execute
     * @param opInfo the opInfo filled by validatePrepayment for this userOp.
     * @return collected the total amount this userOp paid.
     */
    function _executeUserOp(
        uint256 opIndex,
        UserOperation calldata userOp,
        UserOpInfo memory opInfo
    ) internal returns (uint256 collected) {
        uint256 preGas = gasleft();
        bytes memory context = getMemoryBytesFromOffset(opInfo.contextOffset);

        try this.innerHandleOp(userOp.callData, opInfo, context) returns (
            uint256 _actualGasCost
        ) {
            collected = _actualGasCost;
        } catch {
            uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
            collected = _handlePostOp(
                opIndex,
                IPaymaster.PostOpMode.postOpReverted,
                opInfo,
                context,
                actualGas
            );
        }
    }

    /**
     * Execute a batch of UserOperation.
     * no signature aggregator is used.
     * if any account requires an aggregator (that is, it returned an "actualAggregator" when
     * performing simulateValidation), then handleAggregatedOps() must be used instead.
     * @param ops the operations to execute
     * @param beneficiary the address to receive the fees
     */
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) public virtual {
        uint256 opslen = ops.length;
        UserOpInfo[] memory opInfos = new UserOpInfo[](opslen);

        unchecked {
            for (uint256 i = 0; i < opslen; i++) {
                UserOpInfo memory opInfo = opInfos[i];
                (
                    uint256 deadline,
                    uint256 paymasterDeadline,

                ) = _validatePrepayment(i, ops[i], opInfo, address(0));
                _validateDeadline(i, opInfo, deadline, paymasterDeadline);
            }

            uint256 collected = 0;

            for (uint256 i = 0; i < opslen; i++) {
                collected += _executeUserOp(i, ops[i], opInfos[i]);
            }

            _compensate(beneficiary, collected);
        } //unchecked
    }

    /**
     * Execute a batch of UserOperation with Aggregators
     * @param opsPerAggregator the operations to execute, grouped by aggregator (or address(0) for no-aggregator accounts)
     * @param beneficiary the address to receive the fees
     */
    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata opsPerAggregator,
        address payable beneficiary
    ) public virtual {
        uint256 opasLen = opsPerAggregator.length;
        uint256 totalOps = 0;
        for (uint256 i = 0; i < opasLen; i++) {
            totalOps += opsPerAggregator[i].userOps.length;
        }

        UserOpInfo[] memory opInfos = new UserOpInfo[](totalOps);

        uint256 opIndex = 0;
        for (uint256 a = 0; a < opasLen; a++) {
            UserOpsPerAggregator calldata opa = opsPerAggregator[a];
            UserOperation[] calldata ops = opa.userOps;
            IAggregator aggregator = opa.aggregator;
            uint256 opslen = ops.length;
            for (uint256 i = 0; i < opslen; i++) {
                UserOpInfo memory opInfo = opInfos[opIndex];
                (
                    uint256 deadline,
                    uint256 paymasterDeadline,

                ) = _validatePrepayment(
                        opIndex,
                        ops[i],
                        opInfo,
                        address(aggregator)
                    );
                _validateDeadline(i, opInfo, deadline, paymasterDeadline);
                opIndex++;
            }

            if (address(aggregator) != address(0)) {
                // solhint-disable-next-line no-empty-blocks
                try aggregator.validateSignatures(ops, opa.signature) {} catch {
                    revert SignatureValidationFailed(address(aggregator));
                }
            }
        }

        uint256 collected = 0;
        opIndex = 0;
        for (uint256 a = 0; a < opasLen; a++) {
            UserOpsPerAggregator calldata opa = opsPerAggregator[a];
            emit SignatureAggregatorChanged(address(opa.aggregator));
            UserOperation[] calldata ops = opa.userOps;
            uint256 opslen = ops.length;

            for (uint256 i = 0; i < opslen; i++) {
                collected += _executeUserOp(opIndex, ops[i], opInfos[opIndex]);
                opIndex++;
            }
        }
        emit SignatureAggregatorChanged(address(0));

        _compensate(beneficiary, collected);
    }

    function simulateHandleOp(UserOperation calldata op) external override {
        UserOpInfo memory opInfo;

        (uint256 deadline, uint256 paymasterDeadline, ) = _validatePrepayment(
            0,
            op,
            opInfo,
            SIMULATE_FIND_AGGREGATOR
        );
        //ignore signature check failure
        if (deadline == SIG_VALIDATION_FAILED) {
            deadline = 0;
        }
        if (paymasterDeadline == SIG_VALIDATION_FAILED) {
            paymasterDeadline = 0;
        }
        _validateDeadline(0, opInfo, deadline, paymasterDeadline);
        numberMarker();
        uint256 paid = _executeUserOp(0, op, opInfo);
        revert ExecutionResult(
            opInfo.preOpGas,
            paid,
            deadline,
            paymasterDeadline
        );
    }

    //a memory copy of UserOp fields (except that dynamic byte arrays: callData, initCode and signature
    struct MemoryUserOp {
        address sender;
        uint256 nonce;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        address paymaster;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
    }

    struct UserOpInfo {
        MemoryUserOp mUserOp;
        bytes32 userOpHash;
        uint256 prefund;
        uint256 contextOffset;
        uint256 preOpGas;
    }

    /**
     * inner function to handle a UserOperation.
     * Must be declared "external" to open a call context, but it can only be called by handleOps.
     */
    function innerHandleOp(
        bytes calldata callData,
        UserOpInfo memory opInfo,
        bytes calldata context
    ) external returns (uint256 actualGasCost) {
        uint256 preGas = gasleft();
        require(msg.sender == address(this), "AA92 internal call only");
        MemoryUserOp memory mUserOp = opInfo.mUserOp;

        IPaymaster.PostOpMode mode;

        (bool success, bytes memory result) = address(mUserOp.sender).call{
            gas: mUserOp.callGasLimit
        }(callData);
        if (!success) {
            emit UserOperationRevertReason(
                opInfo.userOpHash,
                mUserOp.sender,
                mUserOp.nonce,
                result
            );
            mode = IPaymaster.PostOpMode.opReverted;
        } else {
            mode = IPaymaster.PostOpMode.opSucceeded;
        }

        unchecked {
            //note: opIndex is ignored (relevant only if mode==postOpReverted, which is only possible outside of innerHandleOp)
            return
                _handlePostOp(
                    0,
                    mode,
                    opInfo,
                    context,
                    preGas - gasleft() + opInfo.preOpGas
                );
        }
    }

    /**
     * generate a request Id - unique identifier for this request.
     * the request ID is a hash over the content of the userOp (except the signature), the entrypoint and the chainid.
     */
    function getUserOpHash(
        UserOperation calldata userOp
    ) public view returns (bytes32) {
        return
            keccak256(abi.encode(userOp.hash(), address(this), block.chainid));
    }

    /**
     * copy general fields from userOp into the memory opInfo structure.
     */
    function _copyUserOpToMemory(
        UserOperation calldata userOp,
        MemoryUserOp memory mUserOp
    ) internal pure {
        mUserOp.sender = userOp.sender;
        mUserOp.nonce = userOp.nonce;
        mUserOp.callGasLimit = userOp.callGasLimit;
        mUserOp.verificationGasLimit = userOp.verificationGasLimit;
        mUserOp.preVerificationGas = userOp.preVerificationGas;
        mUserOp.maxFeePerGas = userOp.maxFeePerGas;
        mUserOp.maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes calldata paymasterAndData = userOp.paymasterAndData;
        if (paymasterAndData.length > 0) {
            require(
                paymasterAndData.length >= 20,
                "AA93 invalid paymasterAndData"
            );
            mUserOp.paymaster = address(bytes20(paymasterAndData[:20]));
        } else {
            mUserOp.paymaster = address(0);
        }
    }

    /**
     * Simulate a call to account.validateUserOp and paymaster.validatePaymasterUserOp.
     * @dev this method always revert. Successful result is ValidationResult error. other errors are failures.
     * @dev The node must also verify it doesn't use banned opcodes, and that it doesn't reference storage outside the account's data.
     * @param userOp the user operation to validate.
     */
    function simulateValidation(UserOperation calldata userOp) external {
        UserOpInfo memory outOpInfo;

        (
            uint256 deadline,
            uint256 paymasterDeadline,
            address aggregator
        ) = _validatePrepayment(0, userOp, outOpInfo, SIMULATE_FIND_AGGREGATOR);
        StakeInfo memory paymasterInfo = getStakeInfo(
            outOpInfo.mUserOp.paymaster
        );
        StakeInfo memory senderInfo = getStakeInfo(outOpInfo.mUserOp.sender);
        bytes calldata initCode = userOp.initCode;
        address factory = initCode.length >= 20
            ? address(bytes20(initCode[0:20]))
            : address(0);
        StakeInfo memory factoryInfo = getStakeInfo(factory);

        ReturnInfo memory returnInfo = ReturnInfo(
            outOpInfo.preOpGas,
            outOpInfo.prefund,
            deadline,
            paymasterDeadline,
            getMemoryBytesFromOffset(outOpInfo.contextOffset)
        );

        if (aggregator != address(0)) {
            AggregatorStakeInfo memory aggregatorInfo = AggregatorStakeInfo(
                aggregator,
                getStakeInfo(aggregator)
            );
            revert ValidationResultWithAggregation(
                returnInfo,
                senderInfo,
                factoryInfo,
                paymasterInfo,
                aggregatorInfo
            );
        }
        revert ValidationResult(
            returnInfo,
            senderInfo,
            factoryInfo,
            paymasterInfo
        );
    }

    function _getRequiredPrefund(
        MemoryUserOp memory mUserOp
    ) internal view returns (uint256 requiredPrefund) {
        unchecked {
            //when using a Paymaster, the verificationGasLimit is used also to as a limit for the postOp call.
            // our security model might call postOp eventually twice
            uint256 mul = mUserOp.paymaster != address(0) ? 3 : 1;
            uint256 requiredGas = mUserOp.callGasLimit +
                mUserOp.verificationGasLimit *
                mul +
                mUserOp.preVerificationGas;

            // TODO: copy logic of gasPrice?
            requiredPrefund = requiredGas * getUserOpGasPrice(mUserOp);
        }
    }

    // create the sender's contract if needed.
    function _createSenderIfNeeded(
        uint256 opIndex,
        UserOpInfo memory opInfo,
        bytes calldata initCode
    ) internal {
        if (initCode.length != 0) {
            address sender = opInfo.mUserOp.sender;
            if (sender.code.length != 0)
                revert FailedOp(
                    opIndex,
                    address(0),
                    "AA10 sender already constructed"
                );
            address sender1 = senderCreator.createSender{
                gas: opInfo.mUserOp.verificationGasLimit
            }(initCode);
            if (sender1 == address(0))
                revert FailedOp(
                    opIndex,
                    address(0),
                    "AA13 initCode failed or OOG"
                );
            if (sender1 != sender)
                revert FailedOp(
                    opIndex,
                    address(0),
                    "AA14 initCode must return sender"
                );
            if (sender1.code.length == 0)
                revert FailedOp(
                    opIndex,
                    address(0),
                    "AA15 initCode must create sender"
                );
            address factory = address(bytes20(initCode[0:20]));
            emit AccountDeployed(
                opInfo.userOpHash,
                sender,
                factory,
                opInfo.mUserOp.paymaster
            );
        }
    }

    /**
     * Get counterfactual sender address.
     *  Calculate the sender contract address that will be generated by the initCode and salt in the UserOperation.
     * this method always revert, and returns the address in SenderAddressResult error
     * @param initCode the constructor code to be passed into the UserOperation.
     */
    function getSenderAddress(bytes calldata initCode) public {
        revert SenderAddressResult(senderCreator.createSender(initCode));
    }

    /**
     * call account.validateUserOp.
     * revert (with FailedOp) in case validateUserOp reverts, or account didn't send required prefund.
     * decrement account's deposit if needed
     */
    function _validateAccountPrepayment(
        uint256 opIndex,
        UserOperation calldata op,
        UserOpInfo memory opInfo,
        address aggregator,
        uint256 requiredPrefund
    )
        internal
        returns (
            uint256 gasUsedByValidateAccountPrepayment,
            address actualAggregator,
            uint256 deadline
        )
    {
        unchecked {
            uint256 preGas = gasleft();
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            address sender = mUserOp.sender;
            _createSenderIfNeeded(opIndex, opInfo, op.initCode);
            if (aggregator == SIMULATE_FIND_AGGREGATOR) {
                numberMarker();

                if (sender.code.length == 0) {
                    // it would revert anyway. but give a meaningful message
                    revert FailedOp(0, address(0), "AA20 account not deployed");
                }
                if (
                    mUserOp.paymaster != address(0) &&
                    mUserOp.paymaster.code.length == 0
                ) {
                    // it would revert anyway. but give a meaningful message
                    revert FailedOp(
                        0,
                        address(0),
                        "AA30 paymaster not deployed"
                    );
                }
                // during simulation, we don't use given aggregator,
                // but query the account for its aggregator
                try IAggregatedAccount(sender).getAggregator() returns (
                    address userOpAggregator
                ) {
                    aggregator = actualAggregator = userOpAggregator;
                } catch {
                    aggregator = actualAggregator = address(0);
                }
            }
            uint256 missingAccountFunds = 0;
            address paymaster = mUserOp.paymaster;
            if (paymaster == address(0)) {
                uint256 bal = balanceOf(sender);
                missingAccountFunds = bal > requiredPrefund
                    ? 0
                    : requiredPrefund - bal;
            }

            try
                IAccount(sender).validateUserOp{
                    gas: mUserOp.verificationGasLimit
                }(op, opInfo.userOpHash, aggregator, missingAccountFunds)
            returns (uint256 _deadline) {
                deadline = _deadline;
            } catch Error(string memory revertReason) {
                revert FailedOp(opIndex, address(0), revertReason);
            } catch {
                revert FailedOp(opIndex, address(0), "AA23 reverted (or OOG)");
            }
            if (paymaster == address(0)) {
                DepositInfo storage senderInfo = deposits[sender];
                uint256 deposit = senderInfo.deposit;
                if (requiredPrefund > deposit) {
                    revert FailedOp(
                        opIndex,
                        address(0),
                        "AA21 didn't pay prefund"
                    );
                }
                senderInfo.deposit = uint112(deposit - requiredPrefund);
            }
            gasUsedByValidateAccountPrepayment = preGas - gasleft();
        }
    }

    /**
     * in case the request has a paymaster:
     * validate paymaster is staked and has enough deposit.
     * call paymaster.validatePaymasterUserOp.
     * revert with proper FailedOp in case paymaster reverts.
     * decrement paymaster's deposit
     */
    function _validatePaymasterPrepayment(
        uint256 opIndex,
        UserOperation calldata op,
        UserOpInfo memory opInfo,
        uint256 requiredPreFund,
        uint256 gasUsedByValidateAccountPrepayment
    ) internal returns (bytes memory context, uint256 deadline) {
        unchecked {
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            address paymaster = mUserOp.paymaster;
            uint256 verificationGasLimit = mUserOp.verificationGasLimit;
            if (verificationGasLimit <= gasUsedByValidateAccountPrepayment) {
                revert FailedOp(
                    opIndex,
                    paymaster,
                    "AA41 too little verificationGas"
                );
            }

            uint256 gas = verificationGasLimit -
                gasUsedByValidateAccountPrepayment;

            DepositInfo storage paymasterInfo = deposits[paymaster];
            uint256 deposit = paymasterInfo.deposit;
            if (deposit < requiredPreFund) {
                revert FailedOp(
                    opIndex,
                    paymaster,
                    "AA31 paymaster deposit too low"
                );
            }
            paymasterInfo.deposit = uint112(deposit - requiredPreFund);
            try
                IPaymaster(paymaster).validatePaymasterUserOp{gas: gas}(
                    op,
                    opInfo.userOpHash,
                    requiredPreFund
                )
            returns (bytes memory _context, uint256 _deadline) {
                context = _context;
                deadline = _deadline;
            } catch Error(string memory revertReason) {
                revert FailedOp(opIndex, paymaster, revertReason);
            } catch {
                revert FailedOp(opIndex, paymaster, "AA33 reverted (or OOG)");
            }
        }
    }

    /**
     * revert if either account deadline or paymaster deadline is expired
     */
    function _validateDeadline(
        uint256 opIndex,
        UserOpInfo memory opInfo,
        uint256 deadline,
        uint256 paymasterDeadline
    ) internal view {
        //we want to treat "zero" as "maxint", so we subtract one, ignoring underflow
        unchecked {
            // solhint-disable-next-line not-rely-on-time
            if (deadline < block.timestamp) {
                if (deadline == SIG_VALIDATION_FAILED) {
                    revert FailedOp(
                        opIndex,
                        address(0),
                        "AA24 signature error"
                    );
                } else if (deadline == NONCE_VALIDATION_FAILED) {
                    revert FailedOp(opIndex, address(0), "AA25 nonce error");
                } else {
                    revert FailedOp(opIndex, address(0), "AA22 expired");
                }
            }
            // solhint-disable-next-line not-rely-on-time
            if (paymasterDeadline != 0 && paymasterDeadline < block.timestamp) {
                address paymaster = opInfo.mUserOp.paymaster;
                if (paymasterDeadline == SIG_VALIDATION_FAILED) {
                    revert FailedOp(opIndex, paymaster, "AA34 signature error");
                } else {
                    revert FailedOp(
                        opIndex,
                        paymaster,
                        "AA32 paymaster expired"
                    );
                }
            }
        }
    }

    /**
     * validate account and paymaster (if defined).
     * also make sure total validation doesn't exceed verificationGasLimit
     * this method is called off-chain (simulateValidation()) and on-chain (from handleOps)
     * @param opIndex the index of this userOp into the "opInfos" array
     * @param userOp the userOp to validate
     */
    function _validatePrepayment(
        uint256 opIndex,
        UserOperation calldata userOp,
        UserOpInfo memory outOpInfo,
        address aggregator
    )
        internal
        returns (
            uint256 deadline,
            uint256 paymasterDeadline,
            address actualAggregator
        )
    {
        uint256 preGas = gasleft();
        MemoryUserOp memory mUserOp = outOpInfo.mUserOp;
        _copyUserOpToMemory(userOp, mUserOp);
        outOpInfo.userOpHash = getUserOpHash(userOp);

        // validate all numeric values in userOp are well below 128 bit, so they can safely be added
        // and multiplied without causing overflow
        uint256 maxGasValues = mUserOp.preVerificationGas |
            mUserOp.verificationGasLimit |
            mUserOp.callGasLimit |
            userOp.maxFeePerGas |
            userOp.maxPriorityFeePerGas;
        require(maxGasValues <= type(uint120).max, "AA94 gas values overflow");

        uint256 gasUsedByValidateAccountPrepayment;
        uint256 requiredPreFund = _getRequiredPrefund(mUserOp);

        (
            gasUsedByValidateAccountPrepayment,
            actualAggregator,
            deadline
        ) = _validateAccountPrepayment(
            opIndex,
            userOp,
            outOpInfo,
            aggregator,
            requiredPreFund
        );
        //a "marker" where account opcode validation is done and paymaster opcode validation is about to start
        // (used only by off-chain simulateValidation)
        numberMarker();

        bytes memory context;
        if (mUserOp.paymaster != address(0)) {
            (context, paymasterDeadline) = _validatePaymasterPrepayment(
                opIndex,
                userOp,
                outOpInfo,
                requiredPreFund,
                gasUsedByValidateAccountPrepayment
            );
        }

        unchecked {
            if (userOp.verificationGasLimit < preGas - gasleft()) {
                revert FailedOp(
                    opIndex,
                    mUserOp.paymaster,
                    "AA40 over verificationGasLimit"
                );
            }

            outOpInfo.prefund = requiredPreFund;
            outOpInfo.contextOffset = getOffsetOfMemoryBytes(context);
            outOpInfo.preOpGas = preGas - gasleft() + userOp.preVerificationGas;
        }
    }

    /**
     * process post-operation.
     * called just after the callData is executed.
     * if a paymaster is defined and its validation returned a non-empty context, its postOp is called.
     * the excess amount is refunded to the account (or paymaster - if it is was used in the request)
     * @param opIndex index in the batch
     * @param mode - whether is called from innerHandleOp, or outside (postOpReverted)
     * @param opInfo userOp fields and info collected during validation
     * @param context the context returned in validatePaymasterUserOp
     * @param actualGas the gas used so far by this user operation
     */
    function _handlePostOp(
        uint256 opIndex,
        IPaymaster.PostOpMode mode,
        UserOpInfo memory opInfo,
        bytes memory context,
        uint256 actualGas
    ) internal returns (uint256 actualGasCost) {
        uint256 preGas = gasleft();
        unchecked {
            address refundAddress;
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            uint256 gasPrice = getUserOpGasPrice(mUserOp);

            address paymaster = mUserOp.paymaster;
            if (paymaster == address(0)) {
                refundAddress = mUserOp.sender;
            } else {
                refundAddress = paymaster;
                if (context.length > 0) {
                    actualGasCost = actualGas * gasPrice;
                    if (mode != IPaymaster.PostOpMode.postOpReverted) {
                        IPaymaster(paymaster).postOp{
                            gas: mUserOp.verificationGasLimit
                        }(mode, context, actualGasCost);
                    } else {
                        // solhint-disable-next-line no-empty-blocks
                        try
                            IPaymaster(paymaster).postOp{
                                gas: mUserOp.verificationGasLimit
                            }(mode, context, actualGasCost)
                        {} catch Error(string memory reason) {
                            revert FailedOp(opIndex, paymaster, reason);
                        } catch {
                            revert FailedOp(
                                opIndex,
                                paymaster,
                                "AA50 postOp revert"
                            );
                        }
                    }
                }
            }

            actualGas += preGas - gasleft();
            actualGasCost = actualGas * gasPrice;
            if (opInfo.prefund < actualGasCost) {
                revert FailedOp(
                    opIndex,
                    paymaster,
                    "AA51 prefund below actualGasCost"
                );
            }

            {
                uint256 refund = opInfo.prefund - actualGasCost;
                if (paymaster == address(0)) {
                    refundDeposit(payable(refundAddress), refund);
                } else {
                    internalIncrementDeposit(refundAddress, refund);
                }
            }

            emit UserOperationEvent(
                opInfo.userOpHash,
                mUserOp.sender,
                mUserOp.paymaster,
                mUserOp.nonce,
                mode == IPaymaster.PostOpMode.opSucceeded,
                actualGasCost,
                actualGas
            );
        } // unchecked
    }

    /**
     * the gas price this UserOp agrees to pay.
     * relayer/block builder might submit the TX with higher priorityFee, but the user should not
     */
    function getUserOpGasPrice(
        MemoryUserOp memory mUserOp
    ) internal view returns (uint256) {
        unchecked {
            return
                mUserOp.maxFeePerGas == mUserOp.maxPriorityFeePerGas
                    ? mUserOp.maxFeePerGas
                    : min(
                        mUserOp.maxFeePerGas,
                        mUserOp.maxPriorityFeePerGas + block.basefee
                    );
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function getOffsetOfMemoryBytes(
        bytes memory data
    ) internal pure returns (uint256 offset) {
        assembly {
            offset := data
        }
    }

    function getMemoryBytesFromOffset(
        uint256 offset
    ) internal pure returns (bytes memory data) {
        assembly {
            data := offset
        }
    }

    //place the NUMBER opcode in the code.
    // this is used as a marker during simulation, as this OP is completely banned from the simulated code of the
    // account and paymaster.
    function numberMarker() internal view {
        assembly {
            mstore(0, number())
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
// Original code: https://github.com/eth-infinitism/account-abstraction/tree/releases/v0.4
pragma solidity ^0.8.12;

/**
 * helper contract for EntryPoint, to call userOp.initCode from a "neutral" address,
 * which is explicitly not the entryPoint itself.
 */
contract SenderCreator {
    /**
     * call the "initCode" factory to create and return the sender account address
     * @param initCode the initCode value from a UserOp. contains 20 bytes of factory address, followed by calldata
     * @return sender the returned address of the created account, or zero address on failure.
     */
    function createSender(
        bytes calldata initCode
    ) external returns (address sender) {
        address initAddress = address(bytes20(initCode[0:20]));
        bytes memory initCallData = initCode[20:];
        bool success;
        /* solhint-disable no-inline-assembly */
        assembly {
            success := call(
                gas(),
                initAddress,
                0,
                add(initCallData, 0x20),
                mload(initCallData),
                0,
                32
            )
            sender := mload(0)
        }
        if (!success) {
            sender = address(0);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
// Modified version of a Implementation of contracts for ERC-4337 account abstraction via alternative mempool.
// Original code: https://github.com/eth-infinitism/account-abstraction/tree/releases/v0.4
pragma solidity ^0.8.12;

import "../interfaces/IStakeManager.sol";

abstract contract StakeManager is IStakeManager {
    /// maps paymaster to their deposits and stakes
    mapping(address => DepositInfo) public deposits;

    function getDepositInfo(
        address account
    ) public view returns (DepositInfo memory info) {
        return deposits[account];
    }

    // internal method to return just the stake info
    function getStakeInfo(
        address addr
    ) internal view returns (StakeInfo memory info) {
        DepositInfo storage depositInfo = deposits[addr];
        info.stake = depositInfo.stake;
        info.unstakeDelaySec = depositInfo.unstakeDelaySec;
    }

    /// return the deposit (for gas payment) of the account
    function balanceOf(address account) public view returns (uint256) {
        return deposits[account].deposit;
    }

    receive() external payable {
        depositTo(msg.sender);
    }

    function internalIncrementDeposit(
        address account,
        uint256 amount
    ) internal {
        DepositInfo storage info = deposits[account];
        uint256 newAmount = info.deposit + amount;
        require(newAmount <= type(uint112).max, "deposit overflow");
        info.deposit = uint112(newAmount);
    }

    /**
     * add to the deposit of the given account
     */
    function depositTo(address account) public payable {
        internalIncrementDeposit(account, msg.value);
        DepositInfo storage info = deposits[account];
        emit Deposited(
            msg.sender,
            address(this),
            account,
            msg.value,
            info.deposit
        );
    }

    /**
     * withdraw from the deposit.
     * @param withdrawAddress the address to send withdrawn value.
     * @param withdrawAmount the amount to withdraw.
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external {
        DepositInfo storage info = deposits[msg.sender];
        require(withdrawAmount <= info.deposit, "Withdraw amount too large");
        info.deposit = uint112(info.deposit - withdrawAmount);
        emit Withdrawn(msg.sender, withdrawAddress, withdrawAmount);
        (bool success, ) = withdrawAddress.call{value: withdrawAmount}("");
        require(success, "failed to withdraw");
    }

    function refundDeposit(
        address payable refundAddress,
        uint256 refundAmount
    ) internal {
        (bool success, ) = refundAddress.call{value: refundAmount, gas: 4500}(
            ""
        );

        if (success) {
            emit RefundDeposit(msg.sender, refundAddress, refundAmount);
        } else {
            internalIncrementDeposit(refundAddress, refundAmount);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./EntryPointSimulations.sol";

contract EntryPoint is EntryPointSimulations {
    constructor(address owner) EntryPointSimulations(owner) {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "../interfaces/IEntryPointLogic.sol";
import {EntryPoint as EntryPoint0_4} from "../@eth-infinitism-v0.4/EntryPoint.sol";
import "./Storage.sol";

contract EntryPointLogic is IEntryPointLogic, EntryPoint0_4, Storage {
    constructor(address owner) {
        _transferOwnership(owner);
    }

    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) public override(EntryPoint0_4, IEntryPoint) {
        uint256 opslen = ops.length;

        if (!officialBundlerWhiteList[msg.sender]) {
            require(
                unrestrictedBundler && msg.sender == tx.origin,
                "called by illegal bundler"
            );
            require(opslen == 1, "only support one op");
        }

        UserOpInfo[] memory opInfos = new UserOpInfo[](opslen);
        uint256 collected;
        unchecked {
            for (uint256 i = 0; i < opslen; ++i) {
                try this.handleOp(i, ops[i], opInfos[i], address(0)) returns (
                    uint256 gasUsed
                ) {
                    collected += gasUsed;
                } catch (bytes memory revertReason) {
                    emit HandleUserOpRevertReason(
                        ops[i].sender,
                        ops[i].nonce,
                        revertReason
                    );
                }
            }
            _compensate(beneficiary, collected);
        }
    }

    function handleOps(UserOperation[] calldata ops) public override {
        handleOps(ops, payable(msg.sender));
    }

    function handleOp(
        uint256 opIndex,
        UserOperation calldata userOp,
        UserOpInfo memory outOpInfo,
        address aggregator
    ) external returns (uint256) {
        require(msg.sender == address(this), "can only call by handleOps");

        (uint256 deadline, uint256 paymasterDeadline, ) = _validatePrepayment(
            opIndex,
            userOp,
            outOpInfo,
            aggregator
        );

        _validateDeadline(opIndex, outOpInfo, deadline, paymasterDeadline);

        return _executeUserOp(opIndex, userOp, outOpInfo);
    }

    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata,
        address payable
    ) public pure override(EntryPoint0_4, IEntryPoint) {
        revert("Not support aggregator yet");
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "../interfaces/IEntryPointSimulations.sol";
import "../interfaces/IAccount.sol";
import "./EntryPointLogic.sol";
import "../library/UserOperation.sol";

contract EntryPointSimulations is IEntryPointSimulations, EntryPointLogic {
    constructor(address owner) EntryPointLogic(owner) {}

    function simulateValidationWithWalletWhitelistValidate(
        UserOperation calldata op
    ) external {
        UserOpInfo memory opInfo;

        (uint256 deadline, uint256 paymasterDeadline, ) = _validatePrepayment(
            0,
            op,
            opInfo,
            SIMULATE_FIND_AGGREGATOR
        );

        _validateDeadline(0, opInfo, deadline, paymasterDeadline);

        validateWalletWhitelist(op.sender);

        (
            uint256 actualGasCost,
            uint256 callGasEstimate,
            IPaymaster.PostOpMode mode,
            bytes memory excuteResult
        ) = _executeUserOpWithResult(0, op, opInfo);

        uint256 gasPrice = getUserOpGasPrice(opInfo.mUserOp);

        revert SimulateHandleOpResult(
            opInfo.preOpGas,
            mode,
            excuteResult,
            gasPrice > 0 ? actualGasCost / gasPrice : 0,
            callGasEstimate,
            gasPrice,
            deadline,
            paymasterDeadline
        );
    }

    function simulateHandleOpWithoutSig(
        UserOperation calldata op
    ) external override {
        UserOpInfo memory opInfo;

        (
            uint256 deadline,
            uint256 paymasterDeadline,

        ) = _validatePrepaymentWithoutSig(0, op, opInfo, address(0));

        _validateDeadline(0, opInfo, deadline, paymasterDeadline);

        validateWalletWhitelist(op.sender);

        (
            uint256 actualGasCost,
            uint256 callGasEstimate,
            IPaymaster.PostOpMode mode,
            bytes memory excuteResult
        ) = _executeUserOpWithResult(0, op, opInfo);

        uint256 gasPrice = getUserOpGasPrice(opInfo.mUserOp);

        revert SimulateHandleOpResult(
            opInfo.preOpGas,
            mode,
            excuteResult,
            gasPrice > 0 ? actualGasCost / gasPrice : 0,
            callGasEstimate,
            gasPrice,
            deadline,
            paymasterDeadline
        );
    }

    function _validatePrepaymentWithoutSig(
        uint256 opIndex,
        UserOperation calldata userOp,
        UserOpInfo memory outOpInfo,
        address aggregator
    )
        internal
        returns (
            uint256 deadline,
            uint256 paymasterDeadline,
            address actualAggregator
        )
    {
        uint256 preGas = gasleft();
        MemoryUserOp memory mUserOp = outOpInfo.mUserOp;
        _copyUserOpToMemory(userOp, mUserOp);
        outOpInfo.userOpHash = getUserOpHash(userOp);

        // validate all numeric values in userOp are well below 128 bit, so they can safely be added
        // and multiplied without causing overflow
        uint256 maxGasValues = mUserOp.preVerificationGas |
            mUserOp.verificationGasLimit |
            mUserOp.callGasLimit |
            userOp.maxFeePerGas |
            userOp.maxPriorityFeePerGas;
        require(maxGasValues <= type(uint120).max, "AA94 gas values overflow");

        uint256 gasUsedByValidateAccountPrepayment;
        uint256 requiredPreFund = _getRequiredPrefund(mUserOp);
        (
            gasUsedByValidateAccountPrepayment,
            actualAggregator,
            deadline
        ) = _validateAccountPrepaymentWithoutSig(
            opIndex,
            userOp,
            outOpInfo,
            aggregator,
            requiredPreFund
        );
        //a "marker" where account opcode validation is done and paymaster opcode validation is about to start
        // (used only by off-chain simulateValidation)
        numberMarker();

        bytes memory context;
        if (mUserOp.paymaster != address(0)) {
            (
                context,
                paymasterDeadline
            ) = _validatePaymasterPrepaymentWithoutSig(
                opIndex,
                userOp,
                outOpInfo,
                requiredPreFund,
                gasUsedByValidateAccountPrepayment
            );
        }
        unchecked {
            uint256 gasUsed = preGas - gasleft();

            if (userOp.verificationGasLimit < gasUsed) {
                revert FailedOp(
                    opIndex,
                    mUserOp.paymaster,
                    "AA40 over verificationGasLimit"
                );
            }
            outOpInfo.prefund = requiredPreFund;
            outOpInfo.contextOffset = getOffsetOfMemoryBytes(context);
            outOpInfo.preOpGas = preGas - gasleft() + userOp.preVerificationGas;
        }
    }

    function _validateAccountPrepaymentWithoutSig(
        uint256 opIndex,
        UserOperation calldata op,
        UserOpInfo memory opInfo,
        address aggregator,
        uint256 requiredPrefund
    )
        internal
        returns (
            uint256 gasUsedByValidateAccountPrepayment,
            address actualAggregator,
            uint256 deadline
        )
    {
        unchecked {
            uint256 preGas = gasleft();
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            address sender = mUserOp.sender;
            _createSenderIfNeeded(opIndex, opInfo, op.initCode);

            if (sender.code.length == 0) {
                // it would revert anyway. but give a meaningful message
                revert FailedOp(0, address(0), "AA20 account not deployed");
            }

            if (
                mUserOp.paymaster != address(0) &&
                mUserOp.paymaster.code.length == 0
            ) {
                // it would revert anyway. but give a meaningful message
                revert FailedOp(0, address(0), "AA30 paymaster not deployed");
            }

            uint256 missingAccountFunds = 0;
            address paymaster = mUserOp.paymaster;

            if (paymaster == address(0)) {
                uint256 bal = balanceOf(sender);
                missingAccountFunds = bal > requiredPrefund
                    ? 0
                    : requiredPrefund - bal;
            }

            try
                IAccount(sender).validateUserOpWithoutSig{
                    gas: mUserOp.verificationGasLimit
                }(op, opInfo.userOpHash, aggregator, missingAccountFunds)
            returns (uint256 _deadline) {
                deadline = _deadline;
            } catch Error(string memory revertReason) {
                revert FailedOp(opIndex, address(0), revertReason);
            } catch {
                revert FailedOp(opIndex, address(0), "AA23 reverted (or OOG)");
            }

            if (paymaster == address(0)) {
                DepositInfo storage senderInfo = deposits[sender];
                uint256 deposit = senderInfo.deposit;
                if (requiredPrefund > deposit) {
                    revert FailedOp(
                        opIndex,
                        address(0),
                        "AA21 didn't pay prefund"
                    );
                }
                senderInfo.deposit = uint112(deposit - requiredPrefund);
            }
            gasUsedByValidateAccountPrepayment = preGas - gasleft();
        }
    }

    function _validatePaymasterPrepaymentWithoutSig(
        uint256 opIndex,
        UserOperation calldata op,
        UserOpInfo memory opInfo,
        uint256 requiredPreFund,
        uint256 gasUsedByValidateAccountPrepayment
    ) internal returns (bytes memory context, uint256 deadline) {
        unchecked {
            MemoryUserOp memory mUserOp = opInfo.mUserOp;
            uint256 verificationGasLimit = mUserOp.verificationGasLimit;
            require(
                verificationGasLimit > gasUsedByValidateAccountPrepayment,
                "AA41 too little verificationGas"
            );
            uint256 gas = verificationGasLimit -
                gasUsedByValidateAccountPrepayment;

            address paymaster = mUserOp.paymaster;
            DepositInfo storage paymasterInfo = deposits[paymaster];
            uint256 deposit = paymasterInfo.deposit;
            if (deposit < requiredPreFund) {
                revert FailedOp(
                    opIndex,
                    paymaster,
                    "AA31 paymaster deposit too low"
                );
            }
            paymasterInfo.deposit = uint112(deposit - requiredPreFund);

            try
                IPaymaster(paymaster).validatePaymasterUserOpWithoutSig{
                    gas: gas
                }(op, opInfo.userOpHash, requiredPreFund)
            returns (bytes memory _context, uint256 _deadline) {
                context = _context;
                deadline = _deadline;
            } catch Error(string memory revertReason) {
                revert FailedOp(opIndex, paymaster, revertReason);
            } catch {
                revert FailedOp(opIndex, paymaster, "AA33 reverted (or OOG)");
            }
        }
    }

    function _executeUserOpWithResult(
        uint256 opIndex,
        UserOperation calldata userOp,
        UserOpInfo memory opInfo
    )
        internal
        returns (
            uint256 collected,
            uint256 callGasCost,
            IPaymaster.PostOpMode mode,
            bytes memory excuteResult
        )
    {
        uint256 preGas = gasleft();
        bytes memory context = getMemoryBytesFromOffset(opInfo.contextOffset);

        try
            this.innerHandleOpWithResult(userOp.callData, opInfo, context)
        returns (
            uint256 _actualGasCost,
            uint256 _callGasCost,
            IPaymaster.PostOpMode _mode,
            bytes memory _excuteResult
        ) {
            collected = _actualGasCost;
            callGasCost = _callGasCost;
            mode = _mode;
            excuteResult = _excuteResult;
        } catch {
            uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
            collected = _handlePostOp(
                opIndex,
                IPaymaster.PostOpMode.postOpReverted,
                opInfo,
                context,
                actualGas
            );
            mode = IPaymaster.PostOpMode.postOpReverted;
        }
    }

    function innerHandleOpWithResult(
        bytes calldata callData,
        UserOpInfo memory opInfo,
        bytes calldata context
    )
        external
        returns (
            uint256 actualGasCost,
            uint256 callGasCost,
            IPaymaster.PostOpMode postOpMode,
            bytes memory excuteResult
        )
    {
        uint256 preGas = gasleft();
        require(msg.sender == address(this), "AA92 internal call only");
        MemoryUserOp memory mUserOp = opInfo.mUserOp;

        IPaymaster.PostOpMode mode = IPaymaster.PostOpMode.opSucceeded;
        if (callData.length > 0) {
            (bool success, bytes memory result) = address(mUserOp.sender).call{
                gas: mUserOp.callGasLimit
            }(callData);
            callGasCost = preGas - gasleft();
            if (!success) {
                if (result.length > 0) {
                    emit UserOperationRevertReason(
                        opInfo.userOpHash,
                        mUserOp.sender,
                        mUserOp.nonce,
                        result
                    );
                }
                mode = IPaymaster.PostOpMode.opReverted;
            }

            excuteResult = result;
        }

        unchecked {
            uint256 actualGas = preGas - gasleft() + opInfo.preOpGas;
            //note: opIndex is ignored (relevant only if mode==postOpReverted, which is only possible outside of innerHandleOp)
            actualGasCost = _handlePostOp(0, mode, opInfo, context, actualGas);
            postOpMode = mode;
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IStorage.sol";
import "../interfaces/ISmartAccountProxy.sol";
import "../interfaces/ISmartAccountProxyFactory.sol";

contract Storage is Ownable, IStorage {
    bool public unrestrictedWallet;
    bool public unrestrictedBundler;
    bool public unrestrictedModule;

    address public walletProxyFactory;

    mapping(address => bool) public officialBundlerWhiteList;
    mapping(address => bool) public moduleWhiteList;

    function setUnrestrictedWallet(bool allowed) public onlyOwner {
        unrestrictedWallet = allowed;
        emit UnrestrictedWalletSet(allowed);
    }

    function setUnrestrictedBundler(bool allowed) public onlyOwner {
        unrestrictedBundler = allowed;
        emit UnrestrictedBundlerSet(allowed);
    }

    function setUnrestrictedModule(bool allowed) public onlyOwner {
        unrestrictedModule = allowed;
        emit UnrestrictedModuleSet(allowed);
    }

    function setBundlerOfficialWhitelist(
        address bundler,
        bool allowed
    ) public onlyOwner {
        officialBundlerWhiteList[bundler] = allowed;
        emit BundlerWhitelistSet(bundler, allowed);
    }

    function setWalletProxyFactoryWhitelist(
        address walletFactory
    ) public onlyOwner {
        require(walletProxyFactory == address(0), "already set");
        walletProxyFactory = walletFactory;
        emit WalletFactoryWhitelistSet(walletFactory);
    }

    function setModuleWhitelist(address module, bool allowed) public onlyOwner {
        moduleWhiteList[module] = allowed;
        emit ModuleWhitelistSet(module, allowed);
    }

    function validateModuleWhitelist(address module) public view {
        if (!moduleWhiteList[module]) {
            require(unrestrictedModule, "not allowed module");
        }
    }

    function validateWalletWhitelist(address sender) public view {
        if (!unrestrictedWallet) {
            require(
                ISmartAccountProxyFactory(walletProxyFactory).walletWhiteList(
                    sender
                ),
                "sender not created by whitelist factory"
            );

            require(
                ISmartAccountProxyFactory(walletProxyFactory).safeSingleton(
                    ISmartAccountProxy(sender).masterCopy()
                ),
                "sender implement not in whitelist"
            );
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "../library/UserOperation.sol";

interface IAccount {
    /**
     * Validate user's signature and nonce
     * the entryPoint will make the call to the recipient only if this validation call returns successfully.
     * signature failure should be reported by returning SIG_VALIDATION_FAILED (1).
     * This allows making a "simulation call" without a valid signature
     * Other failures (e.g. nonce mismatch, or invalid signature format) should still revert to signal failure.
     *
     * @dev Must validate caller is the entryPoint.
     *      Must validate the signature and nonce
     * @param userOp the operation that is about to be executed.
     * @param userOpHash hash of the user's request data. can be used as the basis for signature.
     * @param aggregator the aggregator used to validate the signature. NULL for non-aggregated signature accounts.
     * @param missingAccountFunds missing funds on the account's deposit in the entrypoint.
     *      This is the minimum amount to transfer to the sender(entryPoint) to be able to make the call.
     *      The excess is left as a deposit in the entrypoint, for future calls.
     *      can be withdrawn anytime using "entryPoint.withdrawTo()"
     *      In case there is a paymaster in the request (or the current deposit is high enough), this value will be zero.
     * @return deadline the last block timestamp this operation is valid, or zero if it is valid indefinitely.
     *      signature failure is returned as SIG_VALIDATION_FAILED value (1)
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address aggregator,
        uint256 missingAccountFunds
    ) external returns (uint256 deadline);

    function validateUserOpWithoutSig(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address aggregator,
        uint256 missingAccountFunds
    ) external returns (uint256 deadline);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "../library/UserOperation.sol";
import "./IAccount.sol";
import "./IAggregator.sol";

/**
 * Aggregated account, that support IAggregator.
 * - the validateUserOp will be called only after the aggregator validated this account (with all other accounts of this aggregator).
 * - the validateUserOp MUST valiate the aggregator parameter, and MAY ignore the userOp.signature field.
 */
interface IAggregatedAccount is IAccount {
    /**
     * return the address of the signature aggregator the account supports.
     */
    function getAggregator() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "../library/UserOperation.sol";

/**
 * Aggregated Signatures validator.
 */
interface IAggregator {
    /**
     * validate aggregated signature.
     * revert if the aggregated signature does not match the given list of operations.
     */
    function validateSignatures(
        UserOperation[] calldata userOps,
        bytes calldata signature
    ) external view;

    /**
     * validate signature of a single userOp
     * This method is should be called by bundler after EntryPoint.simulateValidation() returns (reverts) with ValidationResultWithAggregation
     * First it validates the signature over the userOp. then it return data to be used when creating the handleOps:
     * @param userOp the userOperation received from the user.
     * @return sigForUserOp the value to put into the signature field of the userOp when calling handleOps.
     *    (usually empty, unless account and aggregator support some kind of "multisig"
     */
    function validateUserOpSignature(
        UserOperation calldata userOp
    ) external view returns (bytes memory sigForUserOp);

    /**
     * aggregate multiple signatures into a single value.
     * This method is called off-chain to calculate the signature to pass with handleOps()
     * bundler MAY use optimized custom code perform this aggregation
     * @param userOps array of UserOperations to collect the signatures from.
     * @return aggregatesSignature the aggregated signature
     */
    function aggregateSignatures(
        UserOperation[] calldata userOps
    ) external view returns (bytes memory aggregatesSignature);
}

// SPDX-License-Identifier: GPL-3.0
// Modified version of a Implementation of contracts for ERC-4337 account abstraction via alternative mempool.
// Original code: https://github.com/eth-infinitism/account-abstraction/tree/releases/v0.4
pragma solidity ^0.8.12;

import "../library/UserOperation.sol";
import "./IStakeManager.sol";
import "./IAggregator.sol";

interface IEntryPoint is IStakeManager {
    /***
     * An event emitted after each successful request
     * @param userOpHash - unique identifier for the request (hash its entire content, except signature).
     * @param sender - the account that generates this request.
     * @param paymaster - if non-null, the paymaster that pays for this request.
     * @param nonce - the nonce value from the request
     * @param actualGasCost - actual amount paid (by account or paymaster) for this UserOperation
     * @param actualGasUsed - total gas used by this UserOperation (including preVerification, creation, validation and execution)
     * @param success - true if the sender transaction succeeded, false if reverted.
     */
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );

    /**
     * account "sender" was deployed.
     * @param userOpHash the userOp that deployed this account. UserOperationEvent will follow.
     * @param sender the account that is deployed
     * @param factory the factory used to deploy this account (in the initCode)
     * @param paymaster the paymaster used by this UserOp
     */
    event AccountDeployed(
        bytes32 indexed userOpHash,
        address indexed sender,
        address factory,
        address paymaster
    );

    /**
     * An event emitted if the UserOperation "callData" reverted with non-zero length
     * @param userOpHash the request unique identifier.
     * @param sender the sender of this request
     * @param nonce the nonce used in the request
     * @param revertReason - the return bytes from the (reverted) call to "callData".
     */
    event UserOperationRevertReason(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 nonce,
        bytes revertReason
    );

    /**
     * signature aggregator used by the following UserOperationEvents within this bundle.
     */
    event SignatureAggregatorChanged(address aggregator);

    /**
     * a custom revert error of handleOps, to identify the offending op.
     *  NOTE: if simulateValidation passes successfully, there should be no reason for handleOps to fail on it.
     *  @param opIndex - index into the array of ops to the failed one (in simulateValidation, this is always zero)
     *  @param paymaster - if paymaster.validatePaymasterUserOp fails, this will be the paymaster's address. if validateUserOp failed,
     *       this value will be zero (since it failed before accessing the paymaster)
     *  @param reason - revert reason
     *   Should be caught in off-chain handleOps simulation and not happen on-chain.
     *   Useful for mitigating DoS attempts against batchers or for troubleshooting of account/paymaster reverts.
     */
    error FailedOp(uint256 opIndex, address paymaster, string reason);

    /**
     * error case when a signature aggregator fails to verify the aggregated signature it had created.
     */
    error SignatureValidationFailed(address aggregator);

    //UserOps handled, per aggregator
    struct UserOpsPerAggregator {
        UserOperation[] userOps;
        // aggregator address
        IAggregator aggregator;
        // aggregated signature
        bytes signature;
    }

    /**
     * Execute a batch of UserOperation.
     * no signature aggregator is used.
     * if any account requires an aggregator (that is, it returned an "actualAggregator" when
     * performing simulateValidation), then handleAggregatedOps() must be used instead.
     * @param ops the operations to execute
     * @param beneficiary the address to receive the fees
     */
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external;

    /**
     * Execute a batch of UserOperation with Aggregators
     * @param opsPerAggregator the operations to execute, grouped by aggregator (or address(0) for no-aggregator accounts)
     * @param beneficiary the address to receive the fees
     */
    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata opsPerAggregator,
        address payable beneficiary
    ) external;

    /**
     * generate a request Id - unique identifier for this request.
     * the request ID is a hash over the content of the userOp (except the signature), the entrypoint and the chainid.
     */
    function getUserOpHash(
        UserOperation calldata userOp
    ) external view returns (bytes32);

    /**
     * Simulate a call to account.validateUserOp and paymaster.validatePaymasterUserOp.
     * @dev this method always revert. Successful result is ValidationResult error. other errors are failures.
     * @dev The node must also verify it doesn't use banned opcodes, and that it doesn't reference storage outside the account's data.
     * @param userOp the user operation to validate.
     */
    function simulateValidation(UserOperation calldata userOp) external;

    /**
     * Successful result from simulateValidation.
     * @param returnInfo gas and deadlines returned values
     * @param senderInfo stake information about the sender
     * @param factoryInfo stake information about the factor (if any)
     * @param paymasterInfo stake information about the paymaster (if any)
     */
    error ValidationResult(
        ReturnInfo returnInfo,
        StakeInfo senderInfo,
        StakeInfo factoryInfo,
        StakeInfo paymasterInfo
    );

    /**
     * Successful result from simulateValidation, if the account returns a signature aggregator
     * @param returnInfo gas and deadlines returned values
     * @param senderInfo stake information about the sender
     * @param factoryInfo stake information about the factor (if any)
     * @param paymasterInfo stake information about the paymaster (if any)
     * @param aggregatorInfo signature aggregation info (if the account requires signature aggregator)
     *      bundler MUST use it to verify the signature, or reject the UserOperation
     */
    error ValidationResultWithAggregation(
        ReturnInfo returnInfo,
        StakeInfo senderInfo,
        StakeInfo factoryInfo,
        StakeInfo paymasterInfo,
        AggregatorStakeInfo aggregatorInfo
    );

    /**
     * gas and deadlines returned during simulation
     * @param preOpGas the gas used for validation (including preValidationGas)
     * @param prefund the required prefund for this operation
     * @param deadline validateUserOp's deadline (or SIG_VALIDATION_FAILED for signature failure)
     * @param paymasterDeadline validatePaymasterUserOp's deadline (or SIG_VALIDATION_FAILED for signature failure)
     * @param paymasterContext returned by validatePaymasterUserOp (to be passed into postOp)
     */
    struct ReturnInfo {
        uint256 preOpGas;
        uint256 prefund;
        uint256 deadline;
        uint256 paymasterDeadline;
        bytes paymasterContext;
    }

    /**
     * returned aggregated signature info.
     * the aggregator returned by the account, and its current stake.
     */
    struct AggregatorStakeInfo {
        address actualAggregator;
        StakeInfo stakeInfo;
    }

    /**
     * Get counterfactual sender address.
     *  Calculate the sender contract address that will be generated by the initCode and salt in the UserOperation.
     * this method always revert, and returns the address in SenderAddressResult error
     * @param initCode the constructor code to be passed into the UserOperation.
     */
    function getSenderAddress(bytes memory initCode) external;

    /**
     * return value of getSenderAddress
     */
    error SenderAddressResult(address sender);

    /**
     * simulate full execution of a UserOperation (including both validation and target execution)
     * this method will always revert. it performs full validation of the UserOperation, but ignores
     * signature error.
     * Note that in order to collect the the success/failure of the target call, it must be executed
     * with trace enabled to track the emitted events.
     */
    function simulateHandleOp(UserOperation calldata op) external;

    error ExecutionResult(
        uint256 preOpGas,
        uint256 paid,
        uint256 deadline,
        uint256 paymasterDeadline
    );
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./IEntryPoint.sol";
import "./IPaymaster.sol";

interface IEntryPointLogic is IEntryPoint {
    event HandleUserOpRevertReason(
        address sender,
        uint256 nonce,
        bytes revertReason
    );

    function handleOps(UserOperation[] calldata ops) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./IEntryPoint.sol";
import "./IPaymaster.sol";

interface IEntryPointSimulations {
    function simulateHandleOpWithoutSig(UserOperation calldata op) external;

    error SimulateHandleOpResult(
        uint256 preOpGas,
        IPaymaster.PostOpMode,
        bytes result,
        uint256 paid,
        uint256 callGasCost,
        uint256 gasPrice,
        uint256 deadline,
        uint256 paymasterDeadline
    );
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "../library/UserOperation.sol";

/**
 * the interface exposed by a paymaster contract, who agrees to pay the gas for user's operations.
 * a paymaster must hold a stake to cover the required entrypoint stake and also the gas for the transaction.
 */
interface IPaymaster {
    /**
     * payment validation: check if paymaster agree to pay.
     * Must verify sender is the entryPoint.
     * Revert to reject this request.
     * Note that bundlers will reject this method if it changes the state, unless the paymaster is trusted (whitelisted)
     * The paymaster pre-pays using its deposit, and receive back a refund after the postOp method returns.
     * @param userOp the user operation
     * @param userOpHash hash of the user's request data.
     * @param maxCost the maximum cost of this transaction (based on maximum gas and gas price from userOp)
     * @return context value to send to a postOp
     *  zero length to signify postOp is not required.
     * @return sigTimeRange signature and time-range of this operation, encoded the same as the return value of validateUserOperation
     *      <byte> sigFailure - (1) to mark signature failure (needed only if paymaster uses signature-based validation,)
     *      <4-byte> validUntil - last timestamp this operation is valid. 0 for "indefinite"
     *      <4-byte> validAfter - first timestamp this operation is valid
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 sigTimeRange);

    function validatePaymasterUserOpWithoutSig(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 sigTimeRange);

    /**
     * post-operation handler.
     * Must verify sender is the entryPoint
     * @param mode enum with the following options:
     *      opSucceeded - user operation succeeded.
     *      opReverted  - user op reverted. still has to pay for gas.
     *      postOpReverted - user op succeeded, but caused postOp (in mode=opSucceeded) to revert.
     *                       Now this is the 2nd call, after user's op was deliberately reverted.
     * @param context - the context value returned by validatePaymasterUserOp
     * @param actualGasCost - actual gas used so far (without this postOp call).
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external;

    enum PostOpMode {
        opSucceeded, // user op succeeded
        opReverted, // user op reverted. still has to pay for gas.
        postOpReverted //user op succeeded, but caused postOp to revert. Now its a 2nd call, after user's op was deliberately reverted.
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/**
 * A wrapper factory contract to deploy SmartAccount as an Account-Abstraction wallet contract.
 */
interface ISmartAccountProxy {
    function masterCopy() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface ISmartAccountProxyFactory {
    function safeSingleton(address singleton) external view returns (bool);

    function walletWhiteList(address wallet) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.12;

/**
 * manage deposits and stakes.
 * deposit is just a balance used to pay for UserOperations (either by a paymaster or an account)
 * stake is value locked for at least "unstakeDelay" by a paymaster.
 */
interface IStakeManager {
    event Deposited(
        address from,
        address to,
        address account,
        uint256 increaseDeposit,
        uint256 totalDeposit
    );

    event Withdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    event RefundDeposit(address from, address to, uint256 refundAmount);

    /// Emitted once a stake is scheduled for withdrawal
    event StakeLocked(
        address indexed account,
        uint256 totalStaked,
        uint256 withdrawTime
    );

    /// Emitted once a stake is scheduled for withdrawal
    event StakeUnlocked(address indexed account, uint256 withdrawTime);

    event StakeWithdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    /**
     * @param deposit the account's deposit
     * @param staked true if this account is staked as a paymaster
     * @param stake actual amount of ether staked for this paymaster.
     * @param unstakeDelaySec minimum delay to withdraw the stake. must be above the global unstakeDelaySec
     * @param withdrawTime - first block timestamp where 'withdrawStake' will be callable, or zero if already locked
     * @dev sizes were chosen so that (deposit,staked) fit into one cell (used during handleOps)
     *    and the rest fit into a 2nd cell.
     *    112 bit allows for 2^15 eth
     *    64 bit for full timestamp
     *    32 bit allow 150 years for unstake delay
     */
    struct DepositInfo {
        uint112 deposit;
        bool staked;
        uint112 stake;
        uint32 unstakeDelaySec;
        uint64 withdrawTime;
    }

    //API struct used by getStakeInfo and simulateValidation
    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    function getDepositInfo(
        address account
    ) external view returns (DepositInfo memory info);

    /// return the deposit (for gas payment) of the account
    function balanceOf(address account) external view returns (uint256);

    /**
     * add to the deposit of the given account
     */
    function depositTo(address account) external payable;

    /**
     * withdraw from the deposit.
     * @param withdrawAddress the address to send withdrawn value.
     * @param withdrawAmount the amount to withdraw.
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface IStorage {
    struct bundlerInformation {
        address bundler;
        uint256 registeTime;
    }
    event UnrestrictedWalletSet(bool allowed);
    event UnrestrictedBundlerSet(bool allowed);
    event UnrestrictedModuleSet(bool allowed);
    event WalletFactoryWhitelistSet(address walletProxyFactory);
    event BundlerWhitelistSet(address indexed bundler, bool allowed);
    event ModuleWhitelistSet(address indexed module, bool allowed);

    function officialBundlerWhiteList(
        address bundler
    ) external view returns (bool);

    function moduleWhiteList(address module) external view returns (bool);

    function setUnrestrictedWallet(bool allowed) external;

    function setUnrestrictedBundler(bool allowed) external;

    function setUnrestrictedModule(bool allowed) external;

    function setBundlerOfficialWhitelist(
        address bundler,
        bool allowed
    ) external;

    function setWalletProxyFactoryWhitelist(address walletFactory) external;

    function setModuleWhitelist(address module, bool allowed) external;

    function validateModuleWhitelist(address module) external;

    function validateWalletWhitelist(address sender) external view;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable no-inline-assembly */

/**
 * User Operation struct
 * @param sender the sender account of this request
 * @param nonce unique value the sender uses to verify it is not a replay.
 * @param initCode if set, the account contract will be created by this constructor
 * @param callData the method call to execute on this account.
 * @param verificationGasLimit gas used for validateUserOp and validatePaymasterUserOp
 * @param preVerificationGas gas not calculated by the handleOps method, but added to the gas paid. Covers batch overhead.
 * @param maxFeePerGas same as EIP-1559 gas parameter
 * @param maxPriorityFeePerGas same as EIP-1559 gas parameter
 * @param paymasterAndData if set, this field hold the paymaster address and "paymaster-specific-data". the paymaster will pay for the transaction instead of the sender
 * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

library UserOperationLib {
    function getSender(
        UserOperation calldata userOp
    ) internal pure returns (address) {
        address data;
        //read sender from userOp, which is first userOp member (saves 800 gas...)
        assembly {
            data := calldataload(userOp)
        }
        return address(uint160(data));
    }

    //relayer/block builder might submit the TX with higher priorityFee, but the user should not
    // pay above what he signed for.
    function gasPrice(
        UserOperation calldata userOp
    ) internal view returns (uint256) {
        unchecked {
            uint256 maxFeePerGas = userOp.maxFeePerGas;
            uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
            if (maxFeePerGas == maxPriorityFeePerGas) {
                //legacy mode (for networks that don't support basefee opcode)
                return maxFeePerGas;
            }
            return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
        }
    }

    function pack(
        UserOperation calldata userOp
    ) internal pure returns (bytes memory ret) {
        address sender = getSender(userOp);
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = calldataKeccak(userOp.initCode);
        bytes32 hashCallData = calldataKeccak(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = calldataKeccak(userOp.paymasterAndData);

        return
            abi.encode(
                sender,
                nonce,
                hashInitCode,
                hashCallData,
                callGasLimit,
                verificationGasLimit,
                preVerificationGas,
                maxFeePerGas,
                maxPriorityFeePerGas,
                hashPaymasterAndData
            );
    }

    function calldataKeccak(
        bytes calldata data
    ) internal pure returns (bytes32 ret) {
        assembly {
            let mem := mload(0x40)
            let len := data.length
            calldatacopy(mem, data.offset, len)
            ret := keccak256(mem, len)
        }
    }

    function hash(
        UserOperation calldata userOp
    ) internal pure returns (bytes32) {
        return keccak256(pack(userOp));
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}