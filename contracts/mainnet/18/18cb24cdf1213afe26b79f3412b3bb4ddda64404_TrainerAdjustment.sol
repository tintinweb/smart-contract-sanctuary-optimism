/**
 *Submitted for verification at optimistic.etherscan.io on 2022-07-02
*/

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// File: @openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;


/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC721.sol


// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;


// File: contracts/TrainerAdjustment.sol


pragma solidity ^0.8.0;

/// @title Contract for adjusting trainers based on new .02 ETH price. Mints and Sends 3 new Dragon Trainers to current(02/07/2022 snapshot) holders.
/// @author 0xNaut



contract TrainerAdjustment is ERC721Holder {

    address public dragonTrainer = 0x9e925d6D3c35Fe70DD164D4D39bdb12533b143f5;
    // address[] public holders = ["0x08637Dc61F195412E85A2c1014772083fFF5A76B","0x648D4460e717618C1a179f703D10612d774c5CEC","0x6960d1fA290F0a60896D23Fc3b533a9b0de03644","0x808FAACb4a502060A73dE1F0f4B094eedbc60c08","0x808FAACb4a502060A73dE1F0f4B094eedbc60c08","0xbD3b9559f86ce3714413D66D6868f8518ef0cfBA","0x1b3510fc2d2884DD6C93f88946699f0d2D648fE9","0x94520E2F86afD790263715f727d0d35F533f2A36","0xbc23F5187D2554468DF3c93C30B0fB0100647Ea6","0x65Dcfec3453384301D978f410Cc7EFe6495597dD","0xFdB796C1c16511E42C0573230604ABbAc6a88c82","0xcf34a7Fc102CB4c7B9D10986299635D8A853daB9","0xeC0D280929ed4a08F367CAD07bc5A3Bb4BB07687","0xcf34a7Fc102CB4c7B9D10986299635D8A853daB9","0x8F55072E20bBbFDAab52e4852A7C435b2154E5a4","0x8F55072E20bBbFDAab52e4852A7C435b2154E5a4","0x8F55072E20bBbFDAab52e4852A7C435b2154E5a4","0x2BA1D521595C5B31B177fD5263F8B002F570E92a","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0x000a6457cD56F92bA4824344e1d16923762725e7","0x204BD968d6fBc2119b573D339409006d552bd278","0x9A608d9F416518b5F11acf3dC5594C90D6998e2c","0x8951dEecF8731aA1d61E42183425Fcc609CB9123","0xD3244ccDe52969b6bDFE226E7d99174F43ed9AbD","0x7f25555A0C85B53Cb8934960D0e4ae2DF65CeCaB","0x96b7B58936a4D74bd453C313fe7866Cb95a7e79b","0x05F761AacD63e4e96Bf98f0fE5614De5Ba90856C","0x243baE7765023FF1c25f6063177a5811C68C9A65","0x6485BE49C4CBC827fe71c06B3b4f4cb1e1221B9A","0x547d7Ef04c005a44a3cC89109D2CC78c85679586","0xDe59A8870160DE5220706Ce88E86a907878e6B60","0xAdC24d7b630759A3AF7f52716d91299c999a2213","0xDe59A8870160DE5220706Ce88E86a907878e6B60","0xC0F90E81E6c89D7581C55dAdE471FFf8Fd3Cff60","0xEEad1396fe5f0daec6DbC04d8a43E85dDE4d97DA","0xDe59A8870160DE5220706Ce88E86a907878e6B60","0xDe59A8870160DE5220706Ce88E86a907878e6B60","0x6aB3CC188599Ddc67500e4Dad5f435598Bd2f14a","0xDe59A8870160DE5220706Ce88E86a907878e6B60","0x4e521c48aD5Db406507B6EB5D010A224DC2e71D6","0xbFDEE6344AF7743a7C8b5006eB1cF85148248fF4","0x8D369B83A974B5Dc595eB29bEB63C5b285109312","0xB9581d8311cc3b9E677aF6b0c55f1B93b69aD6f6","0x24B1bF98402c33a78c96178b833F89dbde7E76a7","0x24B1bF98402c33a78c96178b833F89dbde7E76a7","0x24B1bF98402c33a78c96178b833F89dbde7E76a7","0x33D66941465ac776C38096cb1bc496C673aE7390","0x47bFF18E462912Ab61a465b2bc229e3857491AA6","0x47bFF18E462912Ab61a465b2bc229e3857491AA6","0x5E014aa0649102E07c074f498845F01BCD520317","0xEcf3515a589979e98Fc8cb8473F631b5F287c002","0xdE8F8849579F06a30C0dd3ae3d5408EbDaAaBCF7","0xc22493D981E39223bAFB371A604B7dD4bF5cCd9A","0xEcf3515a589979e98Fc8cb8473F631b5F287c002","0x62e6a9A0804868932bC592a2ECfeB5ef6143D5D1","0x62e6a9A0804868932bC592a2ECfeB5ef6143D5D1","0x6d86a73A7511523671F2D44811945ffC3143a714","0xEcf3515a589979e98Fc8cb8473F631b5F287c002","0xEcf3515a589979e98Fc8cb8473F631b5F287c002","0xd5Cf44F59D0079bE8764d1041c5D238864E7A28B","0x68575571E75D2CfA4222e0F8E7053F056EB91d6C","0xDed86dB976fc9aE590B75D52b53212f586A45DB2","0xDc7F990EC4D2F2470BdeAfcABb9aE2C17Cc11312","0xf3Fbb2c0A711529eF9b81fE59a5Ef5b8f1E0eB27","0x4256bec5031Ff6445bDAaAb49Cd627Ac3cF0bd06","0x1e0d4A10a3D2b2eFCaB3BD98fA046bDf6132D676","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0xf4E14d778c2dbD6fd1A04F08721941Eb3E1c9d6C","0xFFF6801942A9e628E38CEcB5F14B1B06504cFCbD","0xFFF6801942A9e628E38CEcB5F14B1B06504cFCbD","0x029B26298DEf18fcb009E709375F091Da8d07d36","0x685723B9dC89BDF28BA5F98F9A8c0aC899bD6E77","0x685723B9dC89BDF28BA5F98F9A8c0aC899bD6E77","0x685723B9dC89BDF28BA5F98F9A8c0aC899bD6E77","0xc25fef376784E9BcaD3E1472575c1E10079c56d1","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0xa5A25ADcFd24b980E480f875Aa2086571047e14D","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0x9af03e7bB447Bb92e29ff8F54C6da3f8A5F88BCA","0x6aB3CC188599Ddc67500e4Dad5f435598Bd2f14a","0xCD8E9278975E66e5E3e7861D9f44DD159Fc4dBB1","0xfE2f873CC0ADd0C3E76D4932a0d8B099231Fd6f0","0x622b9Ee601A434E32d52DCDb70391FeD7B2fC4a6","0xAA27a46998eFC1b27B25cD1Fb5B88D3b45Bc873D","0xC7A3F400cdDe42cf52f240e46ae83d59F3dF1303","0x1b35fcb58F5E1e2a42fF8E66ddf5646966aBf08C","0x8aF0A5658776B68912b22ec954a91b9C20D3F8AA","0x7453019b806919563EaC33870Fe5f8e5154fdF38","0x8DE3c3891268502F77DB7E876d727257DEc0F852","0x8DE3c3891268502F77DB7E876d727257DEc0F852","0x441f4Ff29Af0F0D35DfA81868E9C303857ac75b0","0x95F9C76f016E88533615a18Ed75EF7384E42BeE6","0xdE206bC0Fde2eF5C8BB6A1d552a64F82A2407Be4","0xdE206bC0Fde2eF5C8BB6A1d552a64F82A2407Be4","0xfa2aa9C082c2B79bb3f15627DE75D24cac840fe8","0xAb769309EbCEEDa984E666ab727b36211bA02A8a","0xe824ADFE01A0c07972a9AA7e59eF601CA9Da04FA","0x18C6A47AcA1c6a237e53eD2fc3a8fB392c97169b","0x18C6A47AcA1c6a237e53eD2fc3a8fB392c97169b"];

    function adjustmentMints(address[] calldata list) public payable {
        for(uint i = 0; i < list.length; i++) {
            IDragonTrainer(dragonTrainer).mint{value: .06 ether}(3);
            IDragonTrainer(dragonTrainer).safeTransferFrom(address(this), list[i], IDragonTrainer(dragonTrainer).tokenOfOwnerByIndex(address(this), 0));
            IDragonTrainer(dragonTrainer).safeTransferFrom(address(this), list[i], IDragonTrainer(dragonTrainer).tokenOfOwnerByIndex(address(this), 0));
            IDragonTrainer(dragonTrainer).safeTransferFrom(address(this), list[i], IDragonTrainer(dragonTrainer).tokenOfOwnerByIndex(address(this), 0));
        }
    }
}

interface IDragonTrainer {
    function mint(uint256 amount) external payable;
    function tokenOfOwnerByIndex(address sender, uint256 i) external view returns (uint256 tokenId);
    function safeTransferFrom(address sender, address recip, uint256 id) external;
}