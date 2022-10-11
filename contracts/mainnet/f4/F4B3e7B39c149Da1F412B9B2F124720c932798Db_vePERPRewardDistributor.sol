// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { IRewardDelegate } from "@perp/voting-escrow/contracts/interface/IRewardDelegate.sol";
import { MerkleRedeemUpgradeSafe } from "./Balancer/MerkleRedeemUpgradeSafe.sol";
import { IvePERP } from "./interface/IvePERP.sol";

contract vePERPRewardDistributor is MerkleRedeemUpgradeSafe {
    using AddressUpgradeable for address;

    /// @notice Emitted when vePERP address is changed.
    /// @param oldValue Old vePERP address
    /// @param newValue New vePERP address
    event VePERPChanged(address oldValue, address newValue);

    /// @notice Emitted when minimum lock duration is changed.
    /// @param oldValue Old minimum lock time
    /// @param newValue New minimum lock time
    event MinLockDurationChanged(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when rewardDelegate is changed.
    /// @param oldValue Old address of rewardDelegate
    /// @param newValue New address of rewardDelegate
    event RewardDelegateChanged(address oldValue, address newValue);

    /// @notice Emitted when seed allocation on a week
    /// @param week Week number
    /// @param totalAllocation Total allocation on the week
    event AllocationSeeded(uint256 indexed week, uint256 totalAllocation);

    /// @dev After supporting delegation, this event is deprecated, use VePERPClaimedV2 instead
    /// @notice Emitted when user claim vePERP reward
    /// @param claimant Claimant address
    /// @param week Week number
    /// @param balance Amount of vePERP reward claimed
    event VePERPClaimed(address indexed claimant, uint256 indexed week, uint256 balance);

    /// @notice Emitted when user claim vePERP reward
    /// @param claimant Claimant address
    /// @param week Week number
    /// @param balance Amount of vePERP reward claimed
    /// @param recipient The address who actually receives vePERP reward
    ///        could be another address if the claimant delegates
    event VePERPClaimedV2(address indexed claimant, uint256 indexed week, uint256 balance, address recipient);

    uint256 internal constant _WEEK = 7 * 86400; // a week in seconds

    //**********************************************************//
    //    The below state variables can not change the order    //
    //**********************************************************//
    // array of week (keep this public for backward compatibility)
    uint256[] public merkleRootIndexes;

    uint256 internal _minLockDuration;
    address internal _vePERP;
    //**********************************************************//
    //    The above state variables can not change the order    //
    //**********************************************************//

    address internal _rewardDelegate;

    //
    // MODIFIER
    //

    /// @notice Modifier to check if the caller's vePERP lock time is over minLockDuration
    modifier userLockTimeCheck(address user) {
        address beneficiary = _getBeneficiary(user);

        uint256 currentEpochStartTimestamp = (block.timestamp / _WEEK) * _WEEK; // round down to the start of the epoch
        uint256 userLockEndTimestamp = IvePERP(_vePERP).locked__end(beneficiary);

        // vePRD_LTM: vePERP lock time is less than minLockDuration
        require(userLockEndTimestamp >= currentEpochStartTimestamp + _minLockDuration, "vePRD_LTM");
        _;
    }

    //
    // ONLY OWNER
    //

    function initialize(
        address tokenArg,
        address vePERPArg,
        address rewardDelegateArg,
        uint256 minLockDurationArg
    ) external initializer {
        // vePRD_TNC: token is not a contract
        require(tokenArg.isContract(), "vePRD_TNC");

        __MerkleRedeem_init(tokenArg);

        setVePERP(vePERPArg);
        setMinLockDuration(minLockDurationArg);
        setRewardDelegate(rewardDelegateArg);

        // approve the vePERP contract to spend the PERP token
        token.approve(vePERPArg, type(uint256).max);
    }

    function seedAllocations(
        uint256 week,
        bytes32 merkleRoot,
        uint256 totalAllocation
    ) public override onlyOwner {
        super.seedAllocations(week, merkleRoot, totalAllocation);
        merkleRootIndexes.push(week);
        emit AllocationSeeded(week, totalAllocation);
    }

    /// @dev In case of vePERP migration, unclaimed PERP would be able to be deposited to the new contract instead
    function setVePERP(address vePERPArg) public onlyOwner {
        // vePRD_vePNC: vePERP is not a contract
        require(vePERPArg.isContract(), "vePRD_vePNC");

        address oldVePERP = _vePERP;
        _vePERP = vePERPArg;
        emit VePERPChanged(oldVePERP, vePERPArg);
    }

    function setMinLockDuration(uint256 minLockDurationArg) public onlyOwner {
        uint256 oldMinLockDuration = _minLockDuration;
        _minLockDuration = minLockDurationArg;
        emit MinLockDurationChanged(oldMinLockDuration, minLockDurationArg);
    }

    function setRewardDelegate(address rewardDelegateArg) public onlyOwner {
        // vePRD_RDNC: RewardDelegate is not a contract
        require(rewardDelegateArg.isContract(), "vePRD_RDNC");

        address oldRewardDelegate = _rewardDelegate;
        _rewardDelegate = rewardDelegateArg;
        emit RewardDelegateChanged(oldRewardDelegate, rewardDelegateArg);
    }

    //
    // PUBLIC NON-VIEW
    //

    /// @notice Claim vePERP reward for a week
    /// @dev Overwrite the parent's function because vePERP distributor doesn't follow the inherited behaviors
    ///      from its parent. More specifically, it uses deposit_for() instead of transfer() to distribute the rewards.
    /// @param liquidityProvider Liquidity provider address
    /// @param week Week number of the reward claimed
    /// @param claimedBalance Amount of vePERP reward claimed
    /// @param merkleProof Merkle proof of the week's allocation
    function claimWeek(
        address liquidityProvider,
        uint256 week,
        uint256 claimedBalance,
        bytes32[] calldata merkleProof
    ) public override userLockTimeCheck(liquidityProvider) {
        // vePRD_CA: claimed already
        require(!claimed[week][liquidityProvider], "vePRD_CA");

        // vePRD_IMP: invalid merkle proof
        require(verifyClaim(liquidityProvider, week, claimedBalance, merkleProof), "vePRD_IMP");

        claimed[week][liquidityProvider] = true;

        address beneficiary = _getBeneficiary(liquidityProvider);
        _distribute(beneficiary, claimedBalance);
        emit VePERPClaimedV2(liquidityProvider, week, claimedBalance, beneficiary);
    }

    /// @notice Claim vePERP reward for multiple weeks
    /// @dev Overwrite the parent's function because vePERP distributor doesn't follow the inherited behaviors
    ///      from its parent. More specifically, it uses deposit_for() instead of transfer() to distribute the rewards.
    /// @param liquidityProvider Liquidity provider address
    /// @param claims Array of Claim structs
    function claimWeeks(address liquidityProvider, Claim[] calldata claims)
        public
        override
        userLockTimeCheck(liquidityProvider)
    {
        uint256 totalBalance = 0;
        uint256 length = claims.length;
        Claim calldata claim;
        address beneficiary = _getBeneficiary(liquidityProvider);

        for (uint256 i = 0; i < length; i++) {
            claim = claims[i];

            // vePRD_CA: claimed already
            require(!claimed[claim.week][liquidityProvider], "vePRD_CA");

            // vePRD_IMP: invalid merkle proof
            require(verifyClaim(liquidityProvider, claim.week, claim.balance, claim.merkleProof), "vePRD_IMP");

            totalBalance += claim.balance;
            claimed[claim.week][liquidityProvider] = true;
            emit VePERPClaimedV2(liquidityProvider, claim.week, claim.balance, beneficiary);
        }
        _distribute(beneficiary, totalBalance);
    }

    //
    // EXTERNAL VIEW
    //

    /// @notice Get the merkleRootIndexes length
    /// @return length The length of merkleRootIndexes
    function getLengthOfMerkleRoots() external view returns (uint256 length) {
        return merkleRootIndexes.length;
    }

    /// @notice Get `vePERP` address
    /// @return vePERP The address of vePERP
    function getVePerp() external view returns (address vePERP) {
        return _vePERP;
    }

    /// @notice Get minLockDuration
    /// @return minLockDuration The minimum lock duration time
    function getMinLockDuration() external view returns (uint256 minLockDuration) {
        return _minLockDuration;
    }

    /// @notice Get `rewardDelegate` address
    /// @return rewardDelegate The address of RewardDelegate
    function getRewardDelegate() external view returns (address rewardDelegate) {
        return _rewardDelegate;
    }

    //
    // INTERNAL NON-VIEW
    //

    /// @dev Replace parent function disburse() because vePERP distributor uses deposit_for() instead of transfer()
    ///      to distribute the rewards
    function _distribute(address beneficiary, uint256 balance) internal {
        if (balance > 0) {
            IvePERP(_vePERP).deposit_for(beneficiary, balance);
        }
    }

    /// @dev Get the beneficiary address from `RewardDelegate` contract
    ///      if user didn't have delegate, will return the user address itself
    function _getBeneficiary(address user) internal view returns (address beneficiary) {
        (beneficiary, ) = IRewardDelegate(_rewardDelegate).getBeneficiaryAndQualifiedMultiplier(user);
        return beneficiary;
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IRewardDelegate {
    event BeneficiarySet(address indexed truster, address indexed beneficiary);

    event BeneficiaryCleared(address indexed truster, address indexed beneficiary);

    function setBeneficiaryCandidate(address candidate) external;

    function updateBeneficiary(address truster) external;

    function clearBeneficiary(address beneficiary) external;

    function getBeneficiaryCandidate(address truster) external view returns (address);

    function getBeneficiaryAndQualifiedMultiplier(address truster) external view returns (address, uint256);
}

// source: https://github.com/balancer-labs/erc20-redeemable/blob/master/merkle/contracts/MerkleRedeem.sol
// changes:
// 1. add license and update solidity version to 0.7.6
// 2. make it upgradeable

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { MerkleProofUpgradeable } from "@openzeppelin/contracts-upgradeable/cryptography/MerkleProofUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PerpOwnableUpgrade } from "../utils/PerpOwnableUpgrade.sol";
import { IMerkleRedeem } from "../interface/IMerkleRedeem.sol";

contract MerkleRedeemUpgradeSafe is IMerkleRedeem, PerpOwnableUpgrade {
    //**********************************************************//
    //    The below state variables can not change the order    //
    //**********************************************************//
    // Recorded weeks
    mapping(uint256 => bytes32) public weekMerkleRoots;
    mapping(uint256 => mapping(address => bool)) public claimed;

    IERC20 internal token;

    //**********************************************************//
    //    The above state variables can not change the order    //
    //**********************************************************//

    //◥◤◥◤◥◤◥◤◥◤◥◤◥◤◥◤ add state variables below ◥◤◥◤◥◤◥◤◥◤◥◤◥◤◥◤//

    //◢◣◢◣◢◣◢◣◢◣◢◣◢◣◢◣ add state variables above ◢◣◢◣◢◣◢◣◢◣◢◣◢◣◢◣//
    uint256[50] private __gap;

    //
    // FUNCTIONS
    //

    function __MerkleRedeem_init(address _token) internal initializer {
        __Ownable_init();
        __MerkleRedeem_init_unchained(_token);
    }

    function __MerkleRedeem_init_unchained(address _token) internal initializer {
        token = IERC20(_token);
    }

    function disburse(address _liquidityProvider, uint256 _balance) private {
        if (_balance > 0) {
            emit Claimed(_liquidityProvider, _balance);
            require(token.transfer(_liquidityProvider, _balance), "ERR_TRANSFER_FAILED");
        }
    }

    function claimWeek(
        address _liquidityProvider,
        uint256 _week,
        uint256 _claimedBalance,
        bytes32[] calldata _merkleProof
    ) public virtual override {
        require(!claimed[_week][_liquidityProvider], "Claimed already");
        require(verifyClaim(_liquidityProvider, _week, _claimedBalance, _merkleProof), "Incorrect merkle proof");

        claimed[_week][_liquidityProvider] = true;
        disburse(_liquidityProvider, _claimedBalance);
    }

    function claimWeeks(address _liquidityProvider, Claim[] calldata claims) public virtual override {
        uint256 totalBalance = 0;
        Claim calldata claim;
        for (uint256 i = 0; i < claims.length; i++) {
            claim = claims[i];

            require(!claimed[claim.week][_liquidityProvider], "Claimed already");
            require(
                verifyClaim(_liquidityProvider, claim.week, claim.balance, claim.merkleProof),
                "Incorrect merkle proof"
            );

            totalBalance += claim.balance;
            claimed[claim.week][_liquidityProvider] = true;
        }
        disburse(_liquidityProvider, totalBalance);
    }

    function claimStatus(
        address _liquidityProvider,
        uint256 _begin,
        uint256 _end
    ) external view override returns (bool[] memory) {
        uint256 size = 1 + _end - _begin;
        bool[] memory arr = new bool[](size);
        for (uint256 i = 0; i < size; i++) {
            arr[i] = claimed[_begin + i][_liquidityProvider];
        }
        return arr;
    }

    function merkleRoots(uint256 _begin, uint256 _end) external view override returns (bytes32[] memory) {
        uint256 size = 1 + _end - _begin;
        bytes32[] memory arr = new bytes32[](size);
        for (uint256 i = 0; i < size; i++) {
            arr[i] = weekMerkleRoots[_begin + i];
        }
        return arr;
    }

    function verifyClaim(
        address _liquidityProvider,
        uint256 _week,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) public view virtual override returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_liquidityProvider, _claimedBalance));
        return MerkleProofUpgradeable.verify(_merkleProof, weekMerkleRoots[_week], leaf);
    }

    function seedAllocations(
        uint256 _week,
        bytes32 _merkleRoot,
        uint256 _totalAllocation
    ) public virtual override {
        require(weekMerkleRoots[_week] == bytes32(0), "cannot rewrite merkle root");
        weekMerkleRoots[_week] = _merkleRoot;

        require(token.transferFrom(msg.sender, address(this), _totalAllocation), "ERR_TRANSFER_FAILED");
    }

    function getToken() external view override returns (address) {
        return address(token);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IvePERP {
    struct Point {
        int128 bias;
        int128 slope;
        uint256 ts;
        uint256 blk;
        uint256 perp_amt;
    }

    function epoch() external view returns (uint256 currentEpoch);

    function point_history(uint256 epoch) external view returns (Point memory);

    function locked__end(address user) external view returns (uint256 userLockEndTimestamp);

    function balanceOfUnweighted(address user, uint256 timestamp) external view returns (uint256 unweightedVotingPower);

    function totalSupplyUnweighted(uint256 timestamp) external view returns (uint256 unweightedTotalVotingPower);

    function deposit_for(address user, uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProofUpgradeable {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

// copy from openzeppelin Ownable, only modify how the owner transfer
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
contract PerpOwnableUpgrade is ContextUpgradeable {
    address private _owner;
    address private _candidate;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */

    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    function candidate() public view returns (address) {
        return _candidate;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "PerpFiOwnableUpgrade: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
        _candidate = address(0);
    }

    /**
     * @dev Set ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function setOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "PerpFiOwnableUpgrade: zero address");
        require(newOwner != _owner, "PerpFiOwnableUpgrade: same as original");
        require(newOwner != _candidate, "PerpFiOwnableUpgrade: same as candidate");
        _candidate = newOwner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`_candidate`).
     * Can only be called by the new owner.
     */
    function updateOwner() public {
        require(_candidate != address(0), "PerpFiOwnableUpgrade: candidate is zero address");
        require(_candidate == _msgSender(), "PerpFiOwnableUpgrade: not the new owner");

        emit OwnershipTransferred(_owner, _candidate);
        _owner = _candidate;
        _candidate = address(0);
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IMerkleRedeem {
    event Claimed(address _claimant, uint256 _balance);

    struct Claim {
        uint256 week;
        uint256 balance;
        bytes32[] merkleProof;
    }

    function claimWeek(
        address _liquidityProvider,
        uint256 _week,
        uint256 _claimedBalance,
        bytes32[] calldata _merkleProof
    ) external;

    function claimWeeks(address _liquidityProvider, Claim[] calldata claims) external;

    function claimStatus(
        address _liquidityProvider,
        uint256 _begin,
        uint256 _end
    ) external view returns (bool[] memory);

    function merkleRoots(uint256 _begin, uint256 _end) external view returns (bytes32[] memory);

    function seedAllocations(
        uint256 _week,
        bytes32 _merkleRoot,
        uint256 _totalAllocation
    ) external;

    function verifyClaim(
        address _liquidityProvider,
        uint256 _week,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) external view returns (bool valid);

    function getToken() external view returns (address token);
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