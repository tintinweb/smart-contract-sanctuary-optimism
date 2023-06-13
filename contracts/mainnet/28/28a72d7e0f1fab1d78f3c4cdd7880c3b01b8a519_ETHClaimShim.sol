// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

/**
 * Lazy Payable Claim interface
 */
interface ILazyPayableClaim {
    enum StorageProtocol { INVALID, NONE, ARWEAVE, IPFS }
    
    event ClaimInitialized(address indexed creatorContract, uint256 indexed instanceId, address initializer);
    event ClaimUpdated(address indexed creatorContract, uint256 indexed instanceId);
    event ClaimMint(address indexed creatorContract, uint256 indexed instanceId);
    event ClaimMintBatch(address indexed creatorContract, uint256 indexed instanceId, uint16 mintCount);
    event ClaimMintProxy(address indexed creatorContract, uint256 indexed instanceId, uint16 mintCount, address proxy, address mintFor);

    /**
     * @notice Withdraw funds
     */
    function withdraw(address payable receiver, uint256 amount) external;

    /**
     * @notice Set the Manifold Membership address
     */
    function setMembershipAddress(address membershipAddress) external;

    /**
     * @notice check if a mint index has been consumed or not (only for merkle claims)
     *
     * @param creatorContractAddress    the address of the creator contract for the claim
     * @param instanceId                the claim instanceId for the creator contract
     * @param mintIndex                 the mint claim instance
     * @return                          whether or not the mint index was consumed
     */
    function checkMintIndex(address creatorContractAddress, uint256 instanceId, uint32 mintIndex) external view returns(bool);

    /**
     * @notice check if multiple mint indices has been consumed or not (only for merkle claims)
     *
     * @param creatorContractAddress    the address of the creator contract for the claim
     * @param instanceId                the claim instanceId for the creator contract
     * @param mintIndices               the mint claim instance
     * @return                          whether or not the mint index was consumed
     */
    function checkMintIndices(address creatorContractAddress, uint256 instanceId, uint32[] calldata mintIndices) external view returns(bool[] memory);

    /**
     * @notice get mints made for a wallet (only for non-merkle claims with walletMax)
     *
     * @param minter                    the address of the minting address
     * @param creatorContractAddress    the address of the creator contract for the claim
     * @param instanceId                the claim instance for the creator contract
     * @return                          how many mints the minter has made
     */
    function getTotalMints(address minter, address creatorContractAddress, uint256 instanceId) external view returns(uint32);

    /**
     * @notice allow a wallet to lazily claim a token according to parameters
     * @param creatorContractAddress    the creator contract address
     * @param instanceId                the claim instanceId for the creator contract
     * @param mintIndex                 the mint index (only needed for merkle claims)
     * @param merkleProof               if the claim has a merkleRoot, verifying merkleProof ensures that address + minterValue was used to construct it  (only needed for merkle claims)
     * @param mintFor                   mintFor must be the msg.sender or a delegate wallet address (in the case of merkle based mints)
     */
    function mint(address creatorContractAddress, uint256 instanceId, uint32 mintIndex, bytes32[] calldata merkleProof, address mintFor) external payable;

    /**
     * @notice allow a wallet to lazily claim a token according to parameters
     * @param creatorContractAddress    the creator contract address
     * @param instanceId                the claim instanceId for the creator contract
     * @param mintCount                 the number of claims to mint
     * @param mintIndices               the mint index (only needed for merkle claims)
     * @param merkleProofs              if the claim has a merkleRoot, verifying merkleProof ensures that address + minterValue was used to construct it  (only needed for merkle claims)
     * @param mintFor                   mintFor must be the msg.sender or a delegate wallet address (in the case of merkle based mints)
     */
    function mintBatch(address creatorContractAddress, uint256 instanceId, uint16 mintCount, uint32[] calldata mintIndices, bytes32[][] calldata merkleProofs, address mintFor) external payable;

    /**
     * @notice allow a proxy to mint a token for another address
     * @param creatorContractAddress    the creator contract address
     * @param instanceId                the claim instanceId for the creator contract
     * @param mintCount                 the number of claims to mint
     * @param mintIndices               the mint index (only needed for merkle claims)
     * @param merkleProofs              if the claim has a merkleRoot, verifying merkleProof ensures that address + minterValue was used to construct it  (only needed for merkle claims)
     * @param mintFor                   the address to mint for
     */
    function mintProxy(address creatorContractAddress, uint256 instanceId, uint16 mintCount, uint32[] calldata mintIndices, bytes32[][] calldata merkleProofs, address mintFor) external payable;

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.19;

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
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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

pragma solidity ^0.8.19;

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    ILazyPayableClaim
} from "creator-core-extensions-solidity/packages/manifold/contracts/lazyclaim/ILazyPayableClaim.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";

contract ETHClaimShim is Ownable {
    address public immutable claimExtensionAddress;
    bytes32 public immutable claimInstanceHash;
    uint256 public immutable airdropAmount;

    error InvalidClaimInstance();
    error UnableToTransferETH();

    constructor(
        address initialOwner,
        address claimExtensionAddress_,
        address creatorContractAddress,
        uint256 instanceId,
        uint256 airdropAmount_
    ) Ownable(initialOwner) {
        claimExtensionAddress = claimExtensionAddress_;
        claimInstanceHash = keccak256(
            abi.encodePacked(creatorContractAddress, instanceId)
        );
        airdropAmount = airdropAmount_;
        _transferOwnership(initialOwner);
    }

    modifier isValidClaimInstance(
        address creatorContractAddress,
        uint256 instanceId
    ) {
        if (
            keccak256(abi.encodePacked(creatorContractAddress, instanceId)) !=
            claimInstanceHash
        ) {
            revert InvalidClaimInstance();
        }
        _;
    }

    function mint(
        address creatorContractAddress,
        uint256 instanceId,
        uint32 mintIndex,
        bytes32[] calldata merkleProof,
        address mintFor
    )
        external
        payable
        isValidClaimInstance(creatorContractAddress, instanceId)
    {
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = merkleProof;

        uint32[] memory mintIndices = new uint32[](1);
        mintIndices[0] = mintIndex;

        _mintProxy(
            creatorContractAddress,
            instanceId,
            1,
            mintIndices,
            merkleProofs,
            mintFor
        );
    }

    function mintBatch(
        address creatorContractAddress,
        uint256 instanceId,
        uint16 mintCount,
        uint32[] calldata mintIndices,
        bytes32[][] calldata merkleProofs,
        address mintFor
    )
        external
        payable
        isValidClaimInstance(creatorContractAddress, instanceId)
    {
        _mintProxy(
            creatorContractAddress,
            instanceId,
            mintCount,
            mintIndices,
            merkleProofs,
            mintFor
        );
    }

    function mintProxy(
        address creatorContractAddress,
        uint256 instanceId,
        uint16 mintCount,
        uint32[] calldata mintIndices,
        bytes32[][] calldata merkleProofs,
        address mintFor
    ) public payable isValidClaimInstance(creatorContractAddress, instanceId) {
        _mintProxy(
            creatorContractAddress,
            instanceId,
            mintCount,
            mintIndices,
            merkleProofs,
            mintFor
        );
    }

    function _mintProxy(
        address creatorContractAddress,
        uint256 instanceId,
        uint16 mintCount,
        uint32[] memory mintIndices,
        bytes32[][] memory merkleProofs,
        address mintFor
    ) internal {
        ILazyPayableClaim(claimExtensionAddress).mintProxy{ value: msg.value }(
            creatorContractAddress,
            instanceId,
            mintCount,
            mintIndices,
            merkleProofs,
            mintFor
        );

        // NOTE: Explcitly not handling airdrop claim checks as that is gated by the claim instance
        (bool success, ) = mintFor.call{ value: airdropAmount }("");
        if (!success) {
            revert UnableToTransferETH();
        }
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}