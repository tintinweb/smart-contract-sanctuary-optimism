// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { BlockContext } from "../base/BlockContext.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/drafts/EIP712Upgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { PerpMath } from "@perp/curie-contract/contracts/lib/PerpMath.sol";
import { PerpSafeCast } from "@perp/curie-contract/contracts/lib/PerpSafeCast.sol";
import { ILimitOrderBook } from "../interface/ILimitOrderBook.sol";
import { ILimitOrderRewardVault } from "../interface/ILimitOrderRewardVault.sol";
import { LimitOrderBookStorageV1 } from "../storage/LimitOrderBookStorage.sol";
import { OwnerPausable } from "../base/OwnerPausable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IClearingHouse } from "@perp/curie-contract/contracts/interface/IClearingHouse.sol";
import { IAccountBalance } from "@perp/curie-contract/contracts/interface/IAccountBalance.sol";
import { IBaseToken } from "@perp/curie-contract/contracts/interface/IBaseToken.sol";
import { ChainlinkPriceFeed } from "@perp/perp-oracle-contract/contracts/ChainlinkPriceFeed.sol";

contract LimitOrderBook is
    ILimitOrderBook,
    BlockContext,
    ReentrancyGuardUpgradeable,
    OwnerPausable,
    EIP712Upgradeable,
    LimitOrderBookStorageV1
{
    using AddressUpgradeable for address;
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using SignedSafeMathUpgradeable for int256;
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint8;

    // NOTE: remember to update typehash if you change LimitOrder struct
    // NOTE: cannot use `OrderType orderType` here, use `uint8 orderType` for enum instead
    // solhint-disable-next-line max-line-length
    // keccak256("LimitOrder(uint8 orderType,uint256 salt,address trader,address baseToken,bool isBaseToQuote,bool isExactInput,uint256 amount,uint256 oppositeAmountBound,uint256 deadline,uint160 sqrtPriceLimitX96,bytes32 referralCode,bool reduceOnly,uint80 roundIdWhenCreated,uint256 triggerPrice)");

    // solhint-disable-next-line func-name-mixedcase
    bytes32 public constant LIMIT_ORDER_TYPEHASH = 0x54ea8c184890b5a7f7321f45a2ae952f0af50e3467b2216418a683566bf57c30;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(
        string memory name,
        string memory version,
        address clearingHouseArg,
        address limitOrderRewardVaultArg,
        uint256 minOrderValueArg
    ) external initializer {
        __ReentrancyGuard_init();
        __OwnerPausable_init();
        __EIP712_init(name, version); // ex: "PerpCurieLimitOrder" and "1"

        // LOB_CHINC: ClearingHouse Is Not Contract
        require(clearingHouseArg.isContract(), "LOB_CHINC");
        clearingHouse = clearingHouseArg;

        // LOB_ABINC: AccountBalance Is Not Contract
        address accountBalanceArg = IClearingHouse(clearingHouse).getAccountBalance();
        require(accountBalanceArg.isContract(), "LOB_ABINC");
        accountBalance = accountBalanceArg;

        // LOB_LOFVINC: LimitOrderRewardVault Is Not Contract
        require(limitOrderRewardVaultArg.isContract(), "LOB_LOFVINC");
        limitOrderRewardVault = limitOrderRewardVaultArg;

        // LOB_MOVMBGT0: MinOrderValue Must Be Greater Than Zero
        require(minOrderValueArg > 0, "LOB_MOVMBGT0");
        minOrderValue = minOrderValueArg;
    }

    function setClearingHouse(address clearingHouseArg) external onlyOwner {
        // LOB_CHINC: ClearingHouse Is Not Contract
        require(clearingHouseArg.isContract(), "LOB_CHINC");
        clearingHouse = clearingHouseArg;

        // LOB_ABINC: AccountBalance Is Not Contract
        address accountBalanceArg = IClearingHouse(clearingHouse).getAccountBalance();
        require(accountBalanceArg.isContract(), "LOB_ABINC");
        accountBalance = accountBalanceArg;

        emit ClearingHouseChanged(clearingHouseArg);
    }

    function setMinOrderValue(uint256 minOrderValueArg) external onlyOwner {
        // LOB_MOVMBGT0: MinOrderValue Must Be Greater Than Zero
        require(minOrderValueArg > 0, "LOB_MOVMBGT0");
        minOrderValue = minOrderValueArg;

        emit MinOrderValueChanged(minOrderValueArg);
    }

    function setLimitOrderRewardVault(address limitOrderRewardVaultArg) external onlyOwner {
        // LOB_LOFVINC: LimitOrderRewardVault Is Not Contract
        require(limitOrderRewardVaultArg.isContract(), "LOB_LOFVINC");
        limitOrderRewardVault = limitOrderRewardVaultArg;

        emit LimitOrderRewardVaultChanged(limitOrderRewardVaultArg);
    }

    /// @inheritdoc ILimitOrderBook
    function fillLimitOrder(
        LimitOrder memory order,
        bytes memory signature,
        uint80 roundIdWhenTriggered
    ) external override nonReentrant {
        address sender = _msgSender();

        // short term solution: mitigate that attacker can drain LimitOrderRewardVault
        // LOB_SMBE: Sender Must Be EOA
        require(!sender.isContract(), "LOB_SMBE");

        (, bytes32 orderHash) = _verifySigner(order, signature);

        // LOB_OMBU: Order Must Be Unfilled
        require(_ordersStatus[orderHash] == ILimitOrderBook.OrderStatus.Unfilled, "LOB_OMBU");

        (int256 exchangedPositionSize, int256 exchangedPositionNotional, uint256 fee) = _fillLimitOrder(
            order,
            roundIdWhenTriggered
        );

        _ordersStatus[orderHash] = ILimitOrderBook.OrderStatus.Filled;

        ILimitOrderRewardVault(limitOrderRewardVault).disburse(sender, orderHash);

        emit LimitOrderFilled(
            order.trader,
            order.baseToken,
            orderHash,
            uint8(order.orderType),
            sender, // keeper
            exchangedPositionSize,
            exchangedPositionNotional,
            fee
        );
    }

    /// @inheritdoc ILimitOrderBook
    function cancelLimitOrder(LimitOrder memory order) external override {
        // LOB_OSMBS: Order's Signer Must Be Sender
        require(_msgSender() == order.trader, "LOB_OSMBS");

        // we didn't require `signature` as input like fillLimitOrder(),
        // so trader can actually cancel an order that is not existed
        bytes32 orderHash = getOrderHash(order);

        // LOB_OMBU: Order Must Be Unfilled
        require(_ordersStatus[orderHash] == ILimitOrderBook.OrderStatus.Unfilled, "LOB_OMBU");

        _ordersStatus[orderHash] = ILimitOrderBook.OrderStatus.Cancelled;

        int256 positionSize;
        int256 positionNotional;
        if (order.isBaseToQuote) {
            if (order.isExactInput) {
                positionSize = order.amount.neg256();
                positionNotional = order.oppositeAmountBound.toInt256();
            } else {
                positionSize = order.oppositeAmountBound.neg256();
                positionNotional = order.amount.toInt256();
            }
        } else {
            if (order.isExactInput) {
                positionSize = order.oppositeAmountBound.toInt256();
                positionNotional = order.amount.neg256();
            } else {
                positionSize = order.amount.toInt256();
                positionNotional = order.oppositeAmountBound.neg256();
            }
        }

        emit LimitOrderCancelled(
            order.trader,
            order.baseToken,
            orderHash,
            uint8(order.orderType),
            positionSize,
            positionNotional
        );
    }

    //
    // PUBLIC VIEW
    //

    function getOrderHash(LimitOrder memory order) public view override returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(LIMIT_ORDER_TYPEHASH, order)));
    }

    function getOrderStatus(bytes32 orderHash) external view override returns (ILimitOrderBook.OrderStatus) {
        return _ordersStatus[orderHash];
    }

    //
    // INTERNAL NON-VIEW
    //

    function _fillLimitOrder(LimitOrder memory order, uint80 roundIdWhenTriggered)
        internal
        returns (
            int256,
            int256,
            uint256
        )
    {
        _verifyTriggerPrice(order, roundIdWhenTriggered);

        int256 oldTakerPositionSize = IAccountBalance(accountBalance).getTakerPositionSize(
            order.trader,
            order.baseToken
        );

        (uint256 base, uint256 quote, uint256 fee) = IClearingHouse(clearingHouse).openPositionFor(
            order.trader,
            IClearingHouse.OpenPositionParams({
                baseToken: order.baseToken,
                isBaseToQuote: order.isBaseToQuote,
                isExactInput: order.isExactInput,
                amount: order.amount,
                oppositeAmountBound: order.oppositeAmountBound,
                deadline: order.deadline,
                sqrtPriceLimitX96: order.sqrtPriceLimitX96,
                referralCode: order.referralCode
            })
        );

        // LOB_OVTS: Order Value Too Small
        require(quote >= minOrderValue, "LOB_OVTS");

        if (order.reduceOnly) {
            // LOB_ROINS: ReduceOnly Is Not Satisfied
            require(
                oldTakerPositionSize != 0 &&
                    oldTakerPositionSize < 0 != order.isBaseToQuote &&
                    base <= oldTakerPositionSize.abs(),
                "LOB_ROINS"
            );

            // if trader has no position, order will get reverted
            // if trader has short position, trader can only open a long position
            // => oldTakerPositionSize < 0 != order.isBaseToQuote => true != false
            // if trader has long position, trader can only open a short position
            // => oldTakerPositionSize < 0 != order.isBaseToQuote => false != true
        }

        int256 exchangedPositionSize;
        int256 exchangedPositionNotional;
        if (order.isBaseToQuote) {
            exchangedPositionSize = base.neg256();
            exchangedPositionNotional = quote.toInt256().add(fee.toInt256());
        } else {
            exchangedPositionSize = base.toInt256();
            exchangedPositionNotional = quote.neg256().add(fee.toInt256());
        }

        return (exchangedPositionSize, exchangedPositionNotional, fee);
    }

    //
    // INTERNAL VIEW
    //

    function _verifySigner(LimitOrder memory order, bytes memory signature) internal view returns (address, bytes32) {
        bytes32 orderHash = getOrderHash(order);
        address signer = ECDSAUpgradeable.recover(orderHash, signature);

        // LOB_SINT: Signer Is Not Trader
        require(signer == order.trader, "LOB_SINT");

        return (signer, orderHash);
    }

    function _verifyTriggerPrice(LimitOrder memory order, uint80 roundIdWhenTriggered) internal view {
        if (order.orderType == ILimitOrderBook.OrderType.LimitOrder) {
            return;
        }

        // NOTE: Chainlink proxy's roundId is always increased
        // https://docs.chain.link/docs/historical-price-data/

        // LOB_IRI: Invalid RoundId
        require(order.roundIdWhenCreated > 0 && roundIdWhenTriggered >= order.roundIdWhenCreated, "LOB_IRI");

        // LOB_ITP: Invalid Trigger Price
        require(order.triggerPrice > 0, "LOB_ITP");

        // NOTE: we can only support stop/take-profit limit order for markets that use ChainlinkPriceFeed
        uint256 triggeredPrice = _getPriceByRoundId(order.baseToken, roundIdWhenTriggered);

        // we need to make sure the price has reached trigger price.
        // however, we can only know whether index price has reached trigger price,
        // we didn't know whether market price has reached trigger price

        // rules of advanced order types
        // https://help.ftx.com/hc/en-us/articles/360031896592-Advanced-Order-Types
        if (order.orderType == ILimitOrderBook.OrderType.StopLossLimitOrder) {
            if (order.isBaseToQuote) {
                // LOB_SSLOTPNM: Sell Stop Limit Order Trigger Price Not Matched
                require(triggeredPrice <= order.triggerPrice, "LOB_SSLOTPNM");
            } else {
                // LOB_BSLOTPNM: Buy Stop Limit Order Trigger Price Not Matched
                require(triggeredPrice >= order.triggerPrice, "LOB_BSLOTPNM");
            }
        } else if (order.orderType == ILimitOrderBook.OrderType.TakeProfitLimitOrder) {
            if (order.isBaseToQuote) {
                // LOB_STLOTPNM: Sell Take-profit Limit Order Trigger Price Not Matched
                require(triggeredPrice >= order.triggerPrice, "LOB_STLOTPNM");
            } else {
                // LOB_BTLOTPNM: Buy Take-profit Limit Order Trigger Price Not Matched
                require(triggeredPrice <= order.triggerPrice, "LOB_BTLOTPNM");
            }
        }
    }

    function _getPriceByRoundId(address baseToken, uint80 roundId) internal view returns (uint256) {
        ChainlinkPriceFeed chainlinkPriceFeed = ChainlinkPriceFeed(IBaseToken(baseToken).getPriceFeed());
        (uint256 price, ) = chainlinkPriceFeed.getRoundData(roundId);
        return _formatDecimals(price, chainlinkPriceFeed.decimals(), 18);
    }

    function _formatDecimals(
        uint256 price,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        // LOB_ID: Invalid Decimals
        require(fromDecimals <= toDecimals, "LOB_ID");

        return price.mul(10**(toDecimals.sub(fromDecimals)));
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

abstract contract BlockContext {
    function _blockTimestamp() internal view virtual returns (uint256) {
        // Reply from Arbitrum
        // block.timestamp returns timestamp at the time at which the sequencer receives the tx.
        // It may not actually correspond to a particular L1 block
        return block.timestamp;
    }

    function _blockNumber() internal view virtual returns (uint256) {
        return block.number;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return recover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover-bytes32-bytes-} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign[`eth_sign`]
     * JSON-RPC method.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712Upgradeable is Initializable {
    /* solhint-disable var-name-mixedcase */
    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;
    bytes32 private constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_init(string memory name, string memory version) internal initializer {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal initializer {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash());
    }

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                name,
                version,
                _getChainId(),
                address(this)
            )
        );
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    function _getChainId() private view returns (uint256 chainId) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712NameHash() internal virtual view returns (bytes32) {
        return _HASHED_NAME;
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712VersionHash() internal virtual view returns (bytes32) {
        return _HASHED_VERSION;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMathUpgradeable {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

library PerpMath {
    using PerpSafeCast for int256;
    using SignedSafeMathUpgradeable for int256;
    using SafeMathUpgradeable for uint256;

    function formatSqrtPriceX96ToPriceX96(uint160 sqrtPriceX96) internal pure returns (uint256) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    function formatX10_18ToX96(uint256 valueX10_18) internal pure returns (uint256) {
        return FullMath.mulDiv(valueX10_18, FixedPoint96.Q96, 1 ether);
    }

    function formatX96ToX10_18(uint256 valueX96) internal pure returns (uint256) {
        return FullMath.mulDiv(valueX96, 1 ether, FixedPoint96.Q96);
    }

    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    function abs(int256 value) internal pure returns (uint256) {
        return value >= 0 ? value.toUint256() : neg256(value).toUint256();
    }

    function neg256(int256 a) internal pure returns (int256) {
        require(a > -2**255, "PerpMath: inversion overflow");
        return -a;
    }

    function neg256(uint256 a) internal pure returns (int256) {
        return -PerpSafeCast.toInt256(a);
    }

    function neg128(int128 a) internal pure returns (int128) {
        require(a > -2**127, "PerpMath: inversion overflow");
        return -a;
    }

    function neg128(uint128 a) internal pure returns (int128) {
        return -PerpSafeCast.toInt128(a);
    }

    function divBy10_18(int256 value) internal pure returns (int256) {
        // no overflow here
        return value / (1 ether);
    }

    function divBy10_18(uint256 value) internal pure returns (uint256) {
        // no overflow here
        return value / (1 ether);
    }

    function subRatio(uint24 a, uint24 b) internal pure returns (uint24) {
        require(b <= a, "PerpMath: subtraction overflow");
        return a - b;
    }

    function mulRatio(uint256 value, uint24 ratio) internal pure returns (uint256) {
        return FullMath.mulDiv(value, ratio, 1e6);
    }

    function divRatio(uint256 value, uint24 ratio) internal pure returns (uint256) {
        return FullMath.mulDiv(value, 1e6, ratio);
    }

    /// @param denominator cannot be 0 and is checked in FullMath.mulDiv()
    function mulDiv(
        int256 a,
        int256 b,
        uint256 denominator
    ) internal pure returns (int256 result) {
        uint256 unsignedA = a < 0 ? uint256(neg256(a)) : uint256(a);
        uint256 unsignedB = b < 0 ? uint256(neg256(b)) : uint256(b);
        bool negative = ((a < 0 && b > 0) || (a > 0 && b < 0)) ? true : false;

        uint256 unsignedResult = FullMath.mulDiv(unsignedA, unsignedB, denominator);

        result = negative ? neg256(unsignedResult) : PerpSafeCast.toInt256(unsignedResult);

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

/**
 * @dev copy from "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol"
 * and rename to avoid naming conflict with uniswap
 */
library PerpSafeCast {
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
    function toUint128(uint256 value) internal pure returns (uint128 returnValue) {
        require(((returnValue = uint128(value)) == value), "SafeCast: value doesn't fit in 128 bits");
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
    function toUint64(uint256 value) internal pure returns (uint64 returnValue) {
        require(((returnValue = uint64(value)) == value), "SafeCast: value doesn't fit in 64 bits");
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
    function toUint32(uint256 value) internal pure returns (uint32 returnValue) {
        require(((returnValue = uint32(value)) == value), "SafeCast: value doesn't fit in 32 bits");
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
    function toUint16(uint256 value) internal pure returns (uint16 returnValue) {
        require(((returnValue = uint16(value)) == value), "SafeCast: value doesn't fit in 16 bits");
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
    function toUint8(uint256 value) internal pure returns (uint8 returnValue) {
        require(((returnValue = uint8(value)) == value), "SafeCast: value doesn't fit in 8 bits");
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
    function toInt128(int256 value) internal pure returns (int128 returnValue) {
        require(((returnValue = int128(value)) == value), "SafeCast: value doesn't fit in 128 bits");
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
    function toInt64(int256 value) internal pure returns (int64 returnValue) {
        require(((returnValue = int64(value)) == value), "SafeCast: value doesn't fit in 64 bits");
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
    function toInt32(int256 value) internal pure returns (int32 returnValue) {
        require(((returnValue = int32(value)) == value), "SafeCast: value doesn't fit in 32 bits");
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
    function toInt16(int256 value) internal pure returns (int16 returnValue) {
        require(((returnValue = int16(value)) == value), "SafeCast: value doesn't fit in 16 bits");
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
    function toInt8(int256 value) internal pure returns (int8 returnValue) {
        require(((returnValue = int8(value)) == value), "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }

    /**
     * @dev Returns the downcasted uint24 from int256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0 and into 24 bit.
     */
    function toUint24(int256 value) internal pure returns (uint24 returnValue) {
        require(
            ((returnValue = uint24(value)) == value),
            "SafeCast: value must be positive or value doesn't fit in an 24 bits"
        );
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 returnValue) {
        require(((returnValue = int24(value)) == value), "SafeCast: value doesn't fit in an 24 bits");
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface ILimitOrderBook {
    // Do NOT change the order of enum values because it will break backwards compatibility
    enum OrderType {
        LimitOrder,
        StopLossLimitOrder,
        TakeProfitLimitOrder
    }

    // Do NOT change the order of enum values because it will break backwards compatibility
    enum OrderStatus {
        Unfilled,
        Filled,
        Cancelled
    }

    /// @param orderType The enum of order type (LimitOrder, StopLossLimitOrder, ...)
    /// @param salt An unique number for creating orders with the same parameters
    /// @param trader The address of trader who creates the order (must be signer)
    /// @param baseToken The address of baseToken (vETH, vBTC, ...)
    /// @param isBaseToQuote B2Q (short) if true, otherwise Q2B (long)
    /// @param isExactInput Exact input if true, otherwise exact output
    /// @param amount The input amount if isExactInput is true, otherwise the output amount
    /// @param oppositeAmountBound
    // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    /// @param deadline The block timestamp that the order will expire at (in seconds)
    /// @param sqrtPriceLimitX96 tx will fill until it reaches this price but WON'T REVERT
    /// @param referralCode The referral code
    /// @param reduceOnly The order will only reduce/close positions if true
    /// @param roundIdWhenCreated Chainlink `roundId` when the limit order is created
    // Only available if orderType is StopLossLimitOrder/TakeProfitLimitOrder, otherwise set to 0
    /// @param triggerPrice The trigger price of the limit order
    // Only available if orderType is StopLossLimitOrder/TakeProfitLimitOrder, otherwise set to 0
    struct LimitOrder {
        OrderType orderType;
        uint256 salt;
        address trader;
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        bytes32 referralCode;
        bool reduceOnly;
        uint80 roundIdWhenCreated;
        uint256 triggerPrice;
    }

    /// @notice Emitted when clearingHouse is changed
    /// @param clearingHouseArg The new address of clearingHouse
    event ClearingHouseChanged(address indexed clearingHouseArg);

    /// @notice Emitted when limitOrderRewardVault is changed
    /// @param limitOrderRewardVaultArg The new address of limitOrderRewardVault
    event LimitOrderRewardVaultChanged(address indexed limitOrderRewardVaultArg);

    /// @notice Emitted when minOrderValue is changed
    /// @param minOrderValueArg The minimum limit order value in USD
    event MinOrderValueChanged(uint256 minOrderValueArg);

    /// @notice Emitted when the limit order is filled
    /// @param trader The address of trader who created the limit order
    /// @param baseToken The address of baseToken (vETH, vBTC, ...)
    /// @param orderHash The hash of the filled limit order
    /// @param orderType The enum of order type (LimitOrder, StopLossLimitOrder, ...)
    /// @param keeper The address of keeper
    /// @param exchangedPositionSize The exchanged position size
    /// @param exchangedPositionNotional The exchanged position notional
    /// @param fee The trading fee
    event LimitOrderFilled(
        address indexed trader,
        address indexed baseToken,
        bytes32 orderHash,
        uint8 orderType,
        address keeper,
        int256 exchangedPositionSize,
        int256 exchangedPositionNotional,
        uint256 fee
    );

    /// @notice Emitted when the limit order is cancelled
    /// @param trader The address of trader who cancelled the limit order
    /// @param baseToken The address of baseToken (vETH, vBTC, ...)
    /// @param orderHash The hash of the cancelled limit order
    /// @param orderType The enum of order type (LimitOrder, StopLossLimitOrder, ...)
    /// @param positionSize The position size
    /// @param positionNotional The position notional
    event LimitOrderCancelled(
        address indexed trader,
        address indexed baseToken,
        bytes32 orderHash,
        uint8 orderType,
        int256 positionSize,
        int256 positionNotional
    );

    /// @param order LimitOrder struct
    /// @param signature The EIP-712 signature of `order` generated from `eth_signTypedData_V4`
    /// @param roundIdWhenTriggered Chainlink `roundId` when triggerPrice is satisfied
    // Only available if orderType is StopLossLimitOrder/TakeProfitLimitOrder, otherwise set to 0
    function fillLimitOrder(
        LimitOrder memory order,
        bytes memory signature,
        uint80 roundIdWhenTriggered
    ) external;

    /// @param order LimitOrder struct
    function cancelLimitOrder(LimitOrder memory order) external;

    function getOrderStatus(bytes32 orderHash) external view returns (ILimitOrderBook.OrderStatus);

    function getOrderHash(LimitOrder memory order) external view returns (bytes32);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface ILimitOrderRewardVault {
    /// @notice Emitted when rewardToken is changed
    /// @param rewardToken The new address of rewardToken
    event RewardTokenChanged(address rewardToken);

    /// @notice Emitted when limitOrderBook is changed
    /// @param limitOrderBook The new address of limitOrderBook
    event LimitOrderBookChanged(address limitOrderBook);

    /// @notice Emitted when rewardAmount is changed
    /// @param rewardAmount The new rewardAmount
    event RewardAmountChanged(uint256 rewardAmount);

    /// @notice Emitted when keeper reward is disbursed
    /// @param orderHash The hash of the limit order
    /// @param keeper The address of keeper
    /// @param token The rewardToken
    /// @param amount The reward to keeper
    event Disbursed(bytes32 orderHash, address keeper, address token, uint256 amount);

    /// @notice Emitted when token is withdrawn
    /// @param to The address of who withdrawn the token
    /// @param token The address of token withdrawn
    /// @param amount The amount of token withdrawn
    event Withdrawn(address to, address token, uint256 amount);

    /// @param keeper The address of keeper
    function disburse(address keeper, bytes32 orderHash) external returns (uint256);

    /// @param amount The amount of rewardToken to withdraw
    function withdraw(uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { ILimitOrderBook } from "../interface/ILimitOrderBook.sol";

/// @notice For future upgrades, do not change LimitOrderBookStorageV1. Create a new
/// contract which implements LimitOrderBookStorageV1 and following the naming convention
/// LimitOrderBookStorageVX.

abstract contract LimitOrderBookStorageV1 {
    mapping(bytes32 => ILimitOrderBook.OrderStatus) internal _ordersStatus;
    address public clearingHouse;
    address public accountBalance;
    address public limitOrderRewardVault;
    uint256 public minOrderValue;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { SafeOwnable } from "./SafeOwnable.sol";

abstract contract OwnerPausable is SafeOwnable, PausableUpgradeable {
    // __gap is reserved storage
    uint256[50] private __gap;

    // solhint-disable-next-line func-order
    function __OwnerPausable_init() internal initializer {
        __SafeOwnable_init();
        __Pausable_init();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _msgSender() internal view virtual override returns (address payable) {
        return super._msgSender();
    }

    function _msgData() internal view virtual override returns (bytes memory) {
        return super._msgData();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IClearingHouse {
    /// @param useTakerBalance only accept false now
    struct AddLiquidityParams {
        address baseToken;
        uint256 base;
        uint256 quote;
        int24 lowerTick;
        int24 upperTick;
        uint256 minBase;
        uint256 minQuote;
        bool useTakerBalance;
        uint256 deadline;
    }

    /// @param liquidity collect fee when 0
    struct RemoveLiquidityParams {
        address baseToken;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 fee;
        uint256 liquidity;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 fee;
    }

    /// @param oppositeAmountBound
    // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    // when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
    // when it's over or under the bound, it will be reverted
    /// @param sqrtPriceLimitX96
    // B2Q: the price cannot be less than this value after the swap
    // Q2B: the price cannot be greater than this value after the swap
    // it will fill the trade until it reaches the price limit but WON'T REVERT
    // when it's set to 0, it will disable price limit;
    // when it's 0 and exact output, the output amount is required to be identical to the param amount
    struct OpenPositionParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        bytes32 referralCode;
    }

    struct ClosePositionParams {
        address baseToken;
        uint160 sqrtPriceLimitX96;
        uint256 oppositeAmountBound;
        uint256 deadline;
        bytes32 referralCode;
    }

    struct CollectPendingFeeParams {
        address trader;
        address baseToken;
        int24 lowerTick;
        int24 upperTick;
    }

    /// @notice Emitted when open position with non-zero referral code
    /// @param referralCode The referral code by partners
    event ReferredPositionChanged(bytes32 indexed referralCode);

    /// @notice Emitted when taker position is being liquidated
    /// @param trader The trader who has been liquidated
    /// @param baseToken Virtual base token(ETH, BTC, etc...) address
    /// @param positionNotional The cost of position
    /// @param positionSize The size of position
    /// @param liquidationFee The fee of liquidate
    /// @param liquidator The address of liquidator
    event PositionLiquidated(
        address indexed trader,
        address indexed baseToken,
        uint256 positionNotional,
        uint256 positionSize,
        uint256 liquidationFee,
        address liquidator
    );

    /// @notice Emitted when maker's liquidity of a order changed
    /// @param maker The one who provide liquidity
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param quoteToken The address of virtual USD token
    /// @param lowerTick The lower tick of the position in which to add liquidity
    /// @param upperTick The upper tick of the position in which to add liquidity
    /// @param base The amount of base token added (> 0) / removed (< 0) as liquidity; fees not included
    /// @param quote The amount of quote token added ... (same as the above)
    /// @param liquidity The amount of liquidity unit added (> 0) / removed (< 0)
    /// @param quoteFee The amount of quote token the maker received as fees
    event LiquidityChanged(
        address indexed maker,
        address indexed baseToken,
        address indexed quoteToken,
        int24 lowerTick,
        int24 upperTick,
        int256 base,
        int256 quote,
        int128 liquidity,
        uint256 quoteFee
    );

    /// @notice Emitted when taker's position is being changed
    /// @param trader Trader address
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param exchangedPositionSize The actual amount swap to uniswapV3 pool
    /// @param exchangedPositionNotional The cost of position, include fee
    /// @param fee The fee of open/close position
    /// @param openNotional The cost of open/close position, < 0: long, > 0: short
    /// @param realizedPnl The realized Pnl after open/close position
    /// @param sqrtPriceAfterX96 The sqrt price after swap, in X96
    event PositionChanged(
        address indexed trader,
        address indexed baseToken,
        int256 exchangedPositionSize,
        int256 exchangedPositionNotional,
        uint256 fee,
        int256 openNotional,
        int256 realizedPnl,
        uint256 sqrtPriceAfterX96
    );

    /// @notice Emitted when taker close her position in closed market
    /// @param trader Trader address
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param closedPositionSize Trader's position size in closed market
    /// @param closedPositionNotional Trader's position notional in closed market, based on closed price
    /// @param openNotional The cost of open/close position, < 0: long, > 0: short
    /// @param realizedPnl The realized Pnl after close position
    /// @param closedPrice The close price of position
    event PositionClosed(
        address indexed trader,
        address indexed baseToken,
        int256 closedPositionSize,
        int256 closedPositionNotional,
        int256 openNotional,
        int256 realizedPnl,
        uint256 closedPrice
    );

    /// @notice Emitted when settling a trader's funding payment
    /// @param trader The address of trader
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param fundingPayment The fundingPayment of trader on baseToken market, > 0: payment, < 0 : receipt
    event FundingPaymentSettled(address indexed trader, address indexed baseToken, int256 fundingPayment);

    /// @notice Emitted when trusted forwarder address changed
    /// @dev TrustedForward is only used for metaTx
    /// @param forwarder The trusted forwarder address
    event TrustedForwarderChanged(address indexed forwarder);

    /// @notice Emitted when DelegateApproval address changed
    /// @param delegateApproval The address of DelegateApproval
    event DelegateApprovalChanged(address indexed delegateApproval);

    /// @notice Maker can call `addLiquidity` to provide liquidity on Uniswap V3 pool
    /// @dev Tx will fail if adding `base == 0 && quote == 0` / `liquidity == 0`
    /// @dev - `AddLiquidityParams.useTakerBalance` is only accept `false` now
    /// @param params AddLiquidityParams struct
    /// @return response AddLiquidityResponse struct
    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory response);

    /// @notice Maker can call `removeLiquidity` to remove liquidity
    /// @dev remove liquidity will transfer maker impermanent position to taker position,
    /// if `liquidity` of RemoveLiquidityParams struct is zero, the action will collect fee from
    /// pool to maker
    /// @param params RemoveLiquidityParams struct
    /// @return response RemoveLiquidityResponse struct
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        returns (RemoveLiquidityResponse memory response);

    /// @notice Settle all markets fundingPayment to owedRealized Pnl
    /// @param trader The address of trader
    function settleAllFunding(address trader) external;

    /// @notice Trader can call `openPosition` to long/short on baseToken market
    /// @dev - `OpenPositionParams.oppositeAmountBound`
    ///     - B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    ///     - B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    ///     - Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    ///     - Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    ///     > when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
    ///     > when it's over or under the bound, it will be reverted
    /// @dev - `OpenPositionParams.sqrtPriceLimitX96`
    ///     - B2Q: the price cannot be less than this value after the swap
    ///     - Q2B: the price cannot be greater than this value after the swap
    ///     > it will fill the trade until it reaches the price limit but WON'T REVERT
    ///     > when it's set to 0, it will disable price limit;
    ///     > when it's 0 and exact output, the output amount is required to be identical to the param amount
    /// @param params OpenPositionParams struct
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    function openPosition(OpenPositionParams memory params) external returns (uint256 base, uint256 quote);

    /// @param trader The address of trader
    /// @param params OpenPositionParams struct is the same as `openPosition()`
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    /// @return fee The trading fee
    function openPositionFor(address trader, OpenPositionParams memory params)
        external
        returns (
            uint256 base,
            uint256 quote,
            uint256 fee
        );

    /// @notice Close trader's position
    /// @param params ClosePositionParams struct
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    function closePosition(ClosePositionParams calldata params) external returns (uint256 base, uint256 quote);

    /// @notice If trader is underwater, any one can call `liquidate` to liquidate this trader
    /// @dev If trader has open orders, need to call `cancelAllExcessOrders` first
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @param oppositeAmountBound please check OpenPositionParams
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    /// @return isPartialClose when it's over price limit return true and only liquidate 25% of the position
    function liquidate(
        address trader,
        address baseToken,
        uint256 oppositeAmountBound
    )
        external
        returns (
            uint256 base,
            uint256 quote,
            bool isPartialClose
        );

    /// @notice If trader is underwater, any one can call `liquidate` to liquidate this trader
    /// @dev This function will be deprecated in the future, recommend to use the function `liquidate()` above
    /// @dev If trader has open orders, need to call `cancelAllExcessOrders` first
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    function liquidate(address trader, address baseToken) external;

    /// @notice Cancel excess order of a maker
    /// @dev Order id can get from `OrderBook.getOpenOrderIds`
    /// @param maker The address of Maker
    /// @param baseToken The address of baseToken
    /// @param orderIds The id of the order
    function cancelExcessOrders(
        address maker,
        address baseToken,
        bytes32[] calldata orderIds
    ) external;

    /// @notice Cancel all excess orders of a maker if the maker is underwater
    /// @dev This function won't fail if the maker has no order but fails when maker is not underwater
    /// @param maker The address of maker
    /// @param baseToken The address of baseToken
    function cancelAllExcessOrders(address maker, address baseToken) external;

    /// @notice Close all positions of a trader in the closed market
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return base The amount of base token that is closed
    /// @return quote The amount of quote token that is closed
    function quitMarket(address trader, address baseToken) external returns (uint256 base, uint256 quote);

    /// @notice Get account value of trader
    /// @dev accountValue = totalCollateralValue + totalUnrealizedPnl, in 18 decimals
    /// @param trader The address of trader
    /// @return accountValue The account value of trader
    function getAccountValue(address trader) external view returns (int256 accountValue);

    /// @notice Get QuoteToken address
    /// @return quoteToken The quote token address
    function getQuoteToken() external view returns (address quoteToken);

    /// @notice Get UniswapV3Factory address
    /// @return factory UniswapV3Factory address
    function getUniswapV3Factory() external view returns (address factory);

    /// @notice Get ClearingHouseConfig address
    /// @return clearingHouseConfig ClearingHouseConfig address
    function getClearingHouseConfig() external view returns (address clearingHouseConfig);

    /// @notice Get `Vault` address
    /// @return vault `Vault` address
    function getVault() external view returns (address vault);

    /// @notice Get `Exchange` address
    /// @return exchange `Exchange` address
    function getExchange() external view returns (address exchange);

    /// @notice Get `OrderBook` address
    /// @return orderBook `OrderBook` address
    function getOrderBook() external view returns (address orderBook);

    /// @notice Get AccountBalance address
    /// @return accountBalance `AccountBalance` address
    function getAccountBalance() external view returns (address accountBalance);

    /// @notice Get `InsuranceFund` address
    /// @return insuranceFund `InsuranceFund` address
    function getInsuranceFund() external view returns (address insuranceFund);

    /// @notice Get `DelegateApproval` address
    /// @return delegateApproval `DelegateApproval` address
    function getDelegateApproval() external view returns (address delegateApproval);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AccountMarket } from "../lib/AccountMarket.sol";

interface IAccountBalance {
    /// @param vault The address of the vault contract
    event VaultChanged(address indexed vault);

    /// @dev Emit whenever a trader's `owedRealizedPnl` is updated
    /// @param trader The address of the trader
    /// @param amount The amount changed
    event PnlRealized(address indexed trader, int256 amount);

    /// @notice Modify trader account balance
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the baseToken
    /// @param base Modified amount of base
    /// @param quote Modified amount of quote
    /// @return takerPositionSize Taker position size after modified
    /// @return takerOpenNotional Taker open notional after modified
    function modifyTakerBalance(
        address trader,
        address baseToken,
        int256 base,
        int256 quote
    ) external returns (int256 takerPositionSize, int256 takerOpenNotional);

    /// @notice Modify trader owedRealizedPnl
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param amount Modified amount of owedRealizedPnl
    function modifyOwedRealizedPnl(address trader, int256 amount) external;

    /// @notice Settle owedRealizedPnl
    /// @dev Only used by `Vault.withdraw()`
    /// @param trader The address of the trader
    /// @return pnl Settled owedRealizedPnl
    function settleOwedRealizedPnl(address trader) external returns (int256 pnl);

    /// @notice Modify trader owedRealizedPnl
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the baseToken
    /// @param amount Settled quote amount
    function settleQuoteToOwedRealizedPnl(
        address trader,
        address baseToken,
        int256 amount
    ) external;

    /// @notice Settle account balance and deregister base token
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the baseToken
    /// @param takerBase Modified amount of taker base
    /// @param takerQuote Modified amount of taker quote
    /// @param realizedPnl Amount of pnl realized
    /// @param makerFee Amount of maker fee collected from pool
    function settleBalanceAndDeregister(
        address trader,
        address baseToken,
        int256 takerBase,
        int256 takerQuote,
        int256 realizedPnl,
        int256 makerFee
    ) external;

    /// @notice Every time a trader's position value is checked, the base token list of this trader will be traversed;
    /// thus, this list should be kept as short as possible
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the trader's base token
    function registerBaseToken(address trader, address baseToken) external;

    /// @notice Deregister baseToken from trader accountInfo
    /// @dev Only used by `ClearingHouse` contract, this function is expensive, due to for loop
    /// @param trader The address of the trader
    /// @param baseToken The address of the trader's base token
    function deregisterBaseToken(address trader, address baseToken) external;

    /// @notice Update trader Twap premium info
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @param lastTwPremiumGrowthGlobalX96 The last Twap Premium
    function updateTwPremiumGrowthGlobal(
        address trader,
        address baseToken,
        int256 lastTwPremiumGrowthGlobalX96
    ) external;

    /// @notice Settle trader's PnL in closed market
    /// @dev Only used by `ClearingHouse`
    /// @param trader The address of the trader
    /// @param baseToken The address of the trader's base token
    /// @return positionNotional Taker's position notional settled with closed price
    /// @return openNotional Taker's open notional
    /// @return realizedPnl Settled realized pnl
    /// @return closedPrice The closed price of the closed market
    function settlePositionInClosedMarket(address trader, address baseToken)
        external
        returns (
            int256 positionNotional,
            int256 openNotional,
            int256 realizedPnl,
            uint256 closedPrice
        );

    /// @notice Get `ClearingHouseConfig` address
    /// @return clearingHouseConfig The address of ClearingHouseConfig
    function getClearingHouseConfig() external view returns (address clearingHouseConfig);

    /// @notice Get `OrderBook` address
    /// @return orderBook The address of OrderBook
    function getOrderBook() external view returns (address orderBook);

    /// @notice Get `Vault` address
    /// @return vault The address of Vault
    function getVault() external view returns (address vault);

    /// @notice Get trader registered baseTokens
    /// @param trader The address of trader
    /// @return baseTokens The array of baseToken address
    function getBaseTokens(address trader) external view returns (address[] memory baseTokens);

    /// @notice Get trader account info
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return traderAccountInfo The baseToken account info of trader
    function getAccountInfo(address trader, address baseToken)
        external
        view
        returns (AccountMarket.Info memory traderAccountInfo);

    /// @notice Get taker cost of trader's baseToken
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return openNotional The taker cost of trader's baseToken
    function getTakerOpenNotional(address trader, address baseToken) external view returns (int256 openNotional);

    /// @notice Get total cost of trader's baseToken
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return totalOpenNotional the amount of quote token paid for a position when opening
    function getTotalOpenNotional(address trader, address baseToken) external view returns (int256 totalOpenNotional);

    /// @notice Get total debt value of trader
    /// @param trader The address of trader
    /// @dev Total debt value will relate to `Vault.getFreeCollateral()`
    /// @return totalDebtValue The debt value of trader
    function getTotalDebtValue(address trader) external view returns (uint256 totalDebtValue);

    /// @notice Get margin requirement to check whether trader will be able to liquidate
    /// @dev This is different from `Vault._getTotalMarginRequirement()`, which is for freeCollateral calculation
    /// @param trader The address of trader
    /// @return marginRequirementForLiquidation It is compared with `ClearingHouse.getAccountValue` which is also an int
    function getMarginRequirementForLiquidation(address trader)
        external
        view
        returns (int256 marginRequirementForLiquidation);

    /// @notice Get owedRealizedPnl, unrealizedPnl and pending fee
    /// @param trader The address of trader
    /// @return owedRealizedPnl the pnl realized already but stored temporarily in AccountBalance
    /// @return unrealizedPnl the pnl not yet realized
    /// @return pendingFee the pending fee of maker earned
    function getPnlAndPendingFee(address trader)
        external
        view
        returns (
            int256 owedRealizedPnl,
            int256 unrealizedPnl,
            uint256 pendingFee
        );

    /// @notice Check trader has open order in open/closed market.
    /// @param trader The address of trader
    /// @return hasOrder True of false
    function hasOrder(address trader) external view returns (bool hasOrder);

    /// @notice Get trader base amount
    /// @dev `base amount = takerPositionSize - orderBaseDebt`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return baseAmount The base amount of trader's baseToken market
    function getBase(address trader, address baseToken) external view returns (int256 baseAmount);

    /// @notice Get trader quote amount
    /// @dev `quote amount = takerOpenNotional - orderQuoteDebt`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return quoteAmount The quote amount of trader's baseToken market
    function getQuote(address trader, address baseToken) external view returns (int256 quoteAmount);

    /// @notice Get taker position size of trader's baseToken market
    /// @dev This will only has taker position, can get maker impermanent position through `getTotalPositionSize`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return takerPositionSize The taker position size of trader's baseToken market
    function getTakerPositionSize(address trader, address baseToken) external view returns (int256 takerPositionSize);

    /// @notice Get total position size of trader's baseToken market
    /// @dev `total position size = taker position size + maker impermanent position size`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return totalPositionSize The total position size of trader's baseToken market
    function getTotalPositionSize(address trader, address baseToken) external view returns (int256 totalPositionSize);

    /// @notice Get total position value of trader's baseToken market
    /// @dev A negative returned value is only be used when calculating pnl,
    /// @dev we use `15 mins` twap to calc position value
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return totalPositionValue Total position value of trader's baseToken market
    function getTotalPositionValue(address trader, address baseToken) external view returns (int256 totalPositionValue);

    /// @notice Get all market position abs value of trader
    /// @param trader The address of trader
    /// @return totalAbsPositionValue Sum up positions value of every market
    function getTotalAbsPositionValue(address trader) external view returns (uint256 totalAbsPositionValue);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IBaseToken {
    // Do NOT change the order of enum values because it will break backwards compatibility
    enum Status { Open, Paused, Closed }

    event PriceFeedChanged(address indexed priceFeed);
    event StatusUpdated(Status indexed status);

    function close() external;

    /// @notice Update the cached index price of the token.
    /// @param interval The twap interval.
    function cacheTwap(uint256 interval) external;

    /// @notice Get the price feed address
    /// @return priceFeed the current price feed
    function getPriceFeed() external view returns (address priceFeed);

    function getPausedTimestamp() external view returns (uint256);

    function getPausedIndexPrice() external view returns (uint256);

    function getClosedPrice() external view returns (uint256);

    function isOpen() external view returns (bool);

    function isPaused() external view returns (bool);

    function isClosed() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import { IChainlinkPriceFeed } from "./interface/IChainlinkPriceFeed.sol";
import { IPriceFeed } from "./interface/IPriceFeed.sol";
import { BlockContext } from "./base/BlockContext.sol";

contract ChainlinkPriceFeed is IChainlinkPriceFeed, IPriceFeed, BlockContext {
    using SafeMath for uint256;
    using Address for address;

    AggregatorV3Interface private immutable _aggregator;

    constructor(AggregatorV3Interface aggregator) {
        // CPF_ANC: Aggregator address is not contract
        require(address(aggregator).isContract(), "CPF_ANC");

        _aggregator = aggregator;
    }

    function decimals() external view override returns (uint8) {
        return _aggregator.decimals();
    }

    function getAggregator() external view override returns (address) {
        return address(_aggregator);
    }

    function getRoundData(uint80 roundId) external view override returns (uint256, uint256) {
        // NOTE: aggregator will revert if roundId is invalid (but there might not be a revert message sometimes)
        // will return (roundId, 0, 0, 0, roundId) if round is not complete (not existed yet)
        // https://docs.chain.link/docs/historical-price-data/
        (, int256 price, , uint256 updatedAt, ) = _aggregator.getRoundData(roundId);

        // CPF_IP: Invalid Price
        require(price > 0, "CPF_IP");

        // CPF_RINC: Round Is Not Complete
        require(updatedAt > 0, "CPF_RINC");

        return (uint256(price), updatedAt);
    }

    function getPrice(uint256 interval) external view override returns (uint256) {
        // there are 3 timestamps: base(our target), previous & current
        // base: now - _interval
        // current: the current round timestamp from aggregator
        // previous: the previous round timestamp from aggregator
        // now >= previous > current > = < base
        //
        //  while loop i = 0
        //  --+------+-----+-----+-----+-----+-----+
        //         base                 current  now(previous)
        //
        //  while loop i = 1
        //  --+------+-----+-----+-----+-----+-----+
        //         base           current previous now

        (uint80 round, uint256 latestPrice, uint256 latestTimestamp) = _getLatestRoundData();
        uint256 timestamp = _blockTimestamp();
        uint256 baseTimestamp = timestamp.sub(interval);

        // if the latest timestamp <= base timestamp, which means there's no new price, return the latest price
        if (interval == 0 || round == 0 || latestTimestamp <= baseTimestamp) {
            return latestPrice;
        }

        // rounds are like snapshots, latestRound means the latest price snapshot; follow Chainlink's namings here
        uint256 previousTimestamp = latestTimestamp;
        uint256 cumulativeTime = timestamp.sub(previousTimestamp);
        uint256 weightedPrice = latestPrice.mul(cumulativeTime);
        uint256 timeFraction;
        while (true) {
            if (round == 0) {
                // to prevent from div 0 error, return the latest price if `cumulativeTime == 0`
                return cumulativeTime == 0 ? latestPrice : weightedPrice.div(cumulativeTime);
            }

            round = round - 1;
            (, uint256 currentPrice, uint256 currentTimestamp) = _getRoundData(round);

            // check if the current round timestamp is earlier than the base timestamp
            if (currentTimestamp <= baseTimestamp) {
                // the weighted time period is (base timestamp - previous timestamp)
                // ex: now is 1000, interval is 100, then base timestamp is 900
                // if timestamp of the current round is 970, and timestamp of NEXT round is 880,
                // then the weighted time period will be (970 - 900) = 70 instead of (970 - 880)
                weightedPrice = weightedPrice.add(currentPrice.mul(previousTimestamp.sub(baseTimestamp)));
                break;
            }

            timeFraction = previousTimestamp.sub(currentTimestamp);
            weightedPrice = weightedPrice.add(currentPrice.mul(timeFraction));
            cumulativeTime = cumulativeTime.add(timeFraction);
            previousTimestamp = currentTimestamp;
        }

        return weightedPrice == 0 ? latestPrice : weightedPrice.div(interval);
    }

    function _getLatestRoundData()
        private
        view
        returns (
            uint80,
            uint256 finalPrice,
            uint256
        )
    {
        (uint80 round, int256 latestPrice, , uint256 latestTimestamp, ) = _aggregator.latestRoundData();
        finalPrice = uint256(latestPrice);
        if (latestPrice < 0) {
            _requireEnoughHistory(round);
            (round, finalPrice, latestTimestamp) = _getRoundData(round - 1);
        }
        return (round, finalPrice, latestTimestamp);
    }

    function _getRoundData(uint80 _round)
        private
        view
        returns (
            uint80,
            uint256,
            uint256
        )
    {
        (uint80 round, int256 latestPrice, , uint256 latestTimestamp, ) = _aggregator.getRoundData(_round);
        while (latestPrice < 0) {
            _requireEnoughHistory(round);
            round = round - 1;
            (, latestPrice, , latestTimestamp, ) = _aggregator.getRoundData(round);
        }
        return (round, uint256(latestPrice), latestTimestamp);
    }

    function _requireEnoughHistory(uint80 _round) private pure {
        // CPF_NEH: no enough history
        require(_round > 0, "CPF_NEH");
    }
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = -denominator & denominator;
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ContextUpgradeable.sol";
import "../proxy/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal initializer {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

abstract contract SafeOwnable is ContextUpgradeable {
    address private _owner;
    address private _candidate;

    // __gap is reserved storage
    uint256[50] private __gap;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        // caller not owner
        require(owner() == _msgSender(), "SO_CNO");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */

    function __SafeOwnable_init() internal initializer {
        __Context_init();
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external virtual onlyOwner {
        // emitting event first to avoid caching values
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
        _candidate = address(0);
    }

    /**
     * @dev Set ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function setOwner(address newOwner) external onlyOwner {
        // newOwner is 0
        require(newOwner != address(0), "SO_NW0");
        // same as original
        require(newOwner != _owner, "SO_SAO");
        // same as candidate
        require(newOwner != _candidate, "SO_SAC");

        _candidate = newOwner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`_candidate`).
     * Can only be called by the new owner.
     */
    function updateOwner() external {
        // candidate is zero
        require(_candidate != address(0), "SO_C0");
        // caller is not candidate
        require(_candidate == _msgSender(), "SO_CNC");

        // emitting event first to avoid caching values
        emit OwnershipTransferred(_owner, _candidate);
        _owner = _candidate;
        _candidate = address(0);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the candidate that can become the owner.
     */
    function candidate() external view returns (address) {
        return _candidate;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

library AccountMarket {
    /// @param lastTwPremiumGrowthGlobalX96 the last time weighted premiumGrowthGlobalX96
    struct Info {
        int256 takerPositionSize;
        int256 takerOpenNotional;
        int256 lastTwPremiumGrowthGlobalX96;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IChainlinkPriceFeed {
    function getAggregator() external view returns (address);

    /// @param roundId The roundId that fed into Chainlink aggregator.
    function getRoundData(uint80 roundId) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IPriceFeed {
    function decimals() external view returns (uint8);

    /// @dev Returns the index price of the token.
    /// @param interval The interval represents twap interval.
    function getPrice(uint256 interval) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

abstract contract BlockContext {
    function _blockTimestamp() internal view virtual returns (uint256) {
        // Reply from Arbitrum
        // block.timestamp returns timestamp at the time at which the sequencer receives the tx.
        // It may not actually correspond to a particular L1 block
        return block.timestamp;
    }

    function _blockNumber() internal view virtual returns (uint256) {
        return block.number;
    }
}