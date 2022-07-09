//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/proxy/UUPSImplementation.sol";
import "@synthetixio/core-contracts/contracts/ownership/Ownable.sol";
import "@synthetixio/core-contracts/contracts/token/ERC721.sol";

contract CouncilToken is Ownable, UUPSImplementation, ERC721 {
    error TokenIsNotTransferable();

    function initialize(string memory tokenName, string memory tokenSymbol) public onlyOwner {
        _initialize(tokenName, tokenSymbol, "");
    }

    function upgradeTo(address newImplementation) public override onlyOwner {
        _upgradeTo(newImplementation);
    }

    function mint(address to, uint256 tokenId) public virtual onlyOwner {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual onlyOwner {
        _burn(tokenId);
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override {
        revert TokenIsNotTransferable();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override {
        revert TokenIsNotTransferable();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IUUPSImplementation.sol";
import "../errors/AddressError.sol";
import "../errors/ChangeError.sol";
import "../utils/AddressUtil.sol";
import "./ProxyStorage.sol";

abstract contract UUPSImplementation is IUUPSImplementation, ProxyStorage {
    event Upgraded(address implementation);

    error ImplementationIsSterile(address implementation);
    error UpgradeSimulationFailed();

    function _upgradeTo(address newImplementation) internal virtual {
        if (newImplementation == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (!AddressUtil.isContract(newImplementation)) {
            revert AddressError.NotAContract(newImplementation);
        }

        ProxyStore storage store = _proxyStore();

        if (newImplementation == store.implementation) {
            revert ChangeError.NoChange();
        }

        if (!store.simulatingUpgrade && _implementationIsSterile(newImplementation)) {
            revert ImplementationIsSterile(newImplementation);
        }

        store.implementation = newImplementation;

        emit Upgraded(newImplementation);
    }

    function _implementationIsSterile(address candidateImplementation) internal virtual returns (bool) {
        (bool simulationReverted, bytes memory simulationResponse) = address(this).delegatecall(
            abi.encodeCall(this.simulateUpgradeTo, (candidateImplementation))
        );

        return
            !simulationReverted &&
            keccak256(abi.encodePacked(simulationResponse)) == keccak256(abi.encodePacked(UpgradeSimulationFailed.selector));
    }

    function simulateUpgradeTo(address newImplementation) public override {
        ProxyStore storage store = _proxyStore();

        store.simulatingUpgrade = true;

        address currentImplementation = store.implementation;
        store.implementation = newImplementation;

        (bool rollbackSuccessful, ) = newImplementation.delegatecall(
            abi.encodeCall(this.upgradeTo, (currentImplementation))
        );

        if (!rollbackSuccessful || _proxyStore().implementation != currentImplementation) {
            revert UpgradeSimulationFailed();
        }

        store.simulatingUpgrade = false;

        // solhint-disable-next-line reason-string
        revert();
    }

    function getImplementation() external view override returns (address) {
        return _proxyStore().implementation;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OwnableMixin.sol";
import "../interfaces/IOwnable.sol";
import "../errors/AddressError.sol";
import "../errors/ChangeError.sol";

contract Ownable is IOwnable, OwnableMixin {
    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);

    error NotNominated(address addr);

    function acceptOwnership() public override {
        OwnableStore storage store = _ownableStore();

        address currentNominatedOwner = store.nominatedOwner;
        if (msg.sender != currentNominatedOwner) {
            revert NotNominated(msg.sender);
        }

        emit OwnerChanged(store.owner, currentNominatedOwner);
        store.owner = currentNominatedOwner;

        store.nominatedOwner = address(0);
    }

    function nominateNewOwner(address newNominatedOwner) public override onlyOwnerIfSet {
        OwnableStore storage store = _ownableStore();

        if (newNominatedOwner == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (newNominatedOwner == store.nominatedOwner) {
            revert ChangeError.NoChange();
        }

        store.nominatedOwner = newNominatedOwner;
        emit OwnerNominated(newNominatedOwner);
    }

    function renounceNomination() external override {
        OwnableStore storage store = _ownableStore();

        if (store.nominatedOwner != msg.sender) {
            revert NotNominated(msg.sender);
        }

        store.nominatedOwner = address(0);
    }

    function owner() external view override returns (address) {
        return _ownableStore().owner;
    }

    function nominatedOwner() external view override returns (address) {
        return _ownableStore().nominatedOwner;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721Receiver.sol";
import "../errors/AddressError.sol";
import "../errors/AccessError.sol";
import "../errors/InitError.sol";
import "./ERC721Storage.sol";
import "../utils/AddressUtil.sol";
import "../utils/StringUtil.sol";

/*
    Reference implementations:
    * OpenZeppelin - https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol
*/

contract ERC721 is IERC721, IERC721Metadata, ERC721Storage {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    error CannotSelfApprove(address);
    error InvalidTransferRecipient(address);
    error TokenDoesNotExist(uint256);
    error TokenAlreadyMinted(uint256);

    function _initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory baseTokenURI
    ) internal virtual {
        ERC721Store storage store = _erc721Store();
        if (bytes(store.name).length > 0 || bytes(store.symbol).length > 0 || bytes(store.baseTokenURI).length > 0) {
            revert InitError.AlreadyInitialized();
        }

        store.name = tokenName;
        store.symbol = tokenSymbol;
        store.baseTokenURI = baseTokenURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == this.supportsInterface.selector || // ERC165
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    function balanceOf(address holder) public view virtual override returns (uint) {
        if (holder == address(0)) {
            revert AddressError.ZeroAddress();
        }

        return _erc721Store().balanceOf[holder];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }

        return _erc721Store().ownerOf[tokenId];
    }

    function name() external view virtual override returns (string memory) {
        return _erc721Store().name;
    }

    function symbol() external view virtual override returns (string memory) {
        return _erc721Store().symbol;
    }

    function tokenURI(uint256 tokenId) external view virtual override returns (string memory) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }

        string memory baseURI = _erc721Store().baseTokenURI;

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, StringUtil.uintToString(tokenId))) : "";
    }

    function approve(address to, uint256 tokenId) public virtual override {
        ERC721Store storage store = _erc721Store();
        address holder = store.ownerOf[tokenId];

        if (to == holder) {
            revert CannotSelfApprove(to);
        }

        if (msg.sender != holder && !isApprovedForAll(holder, msg.sender)) {
            revert AccessError.Unauthorized(msg.sender);
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }

        return _erc721Store().tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (msg.sender == operator) {
            revert CannotSelfApprove(operator);
        }

        _erc721Store().operatorApprovals[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address holder, address operator) public view virtual override returns (bool) {
        return _erc721Store().operatorApprovals[holder][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert AccessError.Unauthorized(msg.sender);
        }

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert AccessError.Unauthorized(msg.sender);
        }

        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, data)) {
            revert InvalidTransferRecipient(to);
        }
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _erc721Store().ownerOf[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address holder = ownerOf(tokenId);

        // Not checking tokenId existence since it is checked in ownerOf() and getApproved()

        return (spender == holder || getApproved(tokenId) == spender || isApprovedForAll(holder, spender));
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        ERC721Store storage store = _erc721Store();
        if (to == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (_exists(tokenId)) {
            revert TokenAlreadyMinted(tokenId);
        }

        store.balanceOf[to] += 1;
        store.ownerOf[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        ERC721Store storage store = _erc721Store();
        address holder = store.ownerOf[tokenId];

        _approve(address(0), tokenId);

        store.balanceOf[holder] -= 1;
        delete store.ownerOf[tokenId];

        emit Transfer(holder, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        ERC721Store storage store = _erc721Store();

        if (ownerOf(tokenId) != from) {
            revert AccessError.Unauthorized(from);
        }

        if (to == address(0)) {
            revert AddressError.ZeroAddress();
        }

        // Clear approvals from the previous holder
        _approve(address(0), tokenId);

        store.balanceOf[from] -= 1;
        store.balanceOf[to] += 1;
        store.ownerOf[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _erc721Store().tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (AddressUtil.isContract(to)) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        } else {
            return true;
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUUPSImplementation {
    function upgradeTo(address newImplementation) external;

    function simulateUpgradeTo(address newImplementation) external;

    function getImplementation() external view returns (address);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressError {
    error ZeroAddress();
    error NotAContract(address contr);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ChangeError {
    error NoChange();
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressUtil {
    function isContract(address account) internal view returns (bool) {
        uint256 size;

        assembly {
            size := extcodesize(account)
        }

        return size > 0;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProxyStorage {
    struct ProxyStore {
        address implementation;
        bool simulatingUpgrade;
    }

    function _proxyStore() internal pure returns (ProxyStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.v3.proxy")) - 1)
            store.slot := 0x32402780481dd8149e50baad867f01da72e2f7d02639a6fe378dbd80b6bb446e
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OwnableStorage.sol";
import "../errors/AccessError.sol";

contract OwnableMixin is OwnableStorage {
    modifier onlyOwner() {
        _onlyOwner();

        _;
    }

    modifier onlyOwnerIfSet() {
        address owner = _getOwner();

        // if owner is set then check if msg.sender is the owner
        if (owner != address(0)) {
            _onlyOwner();
        }

        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != _getOwner()) {
            revert AccessError.Unauthorized(msg.sender);
        }
    }

    function _getOwner() internal view returns (address) {
        return _ownableStore().owner;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOwnable {
    function acceptOwnership() external;

    function nominateNewOwner(address newNominatedOwner) external;

    function renounceNomination() external;

    function owner() external view returns (address);

    function nominatedOwner() external view returns (address);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OwnableStorage {
    struct OwnableStore {
        bool initialized;
        address owner;
        address nominatedOwner;
    }

    function _ownableStore() internal pure returns (OwnableStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.ownable")) - 1)
            store.slot := 0x66d20a9eef910d2df763b9de0d390f3cc67f7d52c6475118cd57fa98be8cf6cb
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AccessError {
    error Unauthorized(address addr);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address approved, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";

interface IERC721Metadata is IERC165 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) external returns (bytes4);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library InitError {
    error AlreadyInitialized();
    error NotInitialized();
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC721Storage {
    struct ERC721Store {
        string name;
        string symbol;
        string baseTokenURI;
        mapping(uint256 => address) ownerOf;
        mapping(address => uint256) balanceOf;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
    }

    function _erc721Store() internal pure returns (ERC721Store storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.ERC721")) - 1)
            store.slot := 0xcff586616dbfd8fcbd4d6ec876c80f6e96179ad989cea8424b590d1e270e5bcf
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    Reference implementations:
    * OpenZeppelin - https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
*/

library StringUtil {
    function uintToString(uint value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}