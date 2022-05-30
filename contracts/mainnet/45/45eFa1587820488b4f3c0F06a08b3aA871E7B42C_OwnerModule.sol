//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnerModule as BaseOwnerModule} from "@synthetixio/core-modules/contracts/modules/OwnerModule.sol";

// solhint-disable-next-line no-empty-blocks
contract OwnerModule is BaseOwnerModule {

}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/ownership/Ownable.sol";
import "@synthetixio/core-contracts/contracts/initializable/InitializableMixin.sol";
import "../interfaces/IOwnerModule.sol";

// solhint-disable-next-line no-empty-blocks
contract OwnerModule is Ownable, IOwnerModule, InitializableMixin {
    function _isInitialized() internal view override returns (bool) {
        return _ownableStore().initialized;
    }

    function isOwnerModuleInitialized() external view override returns (bool) {
        return _isInitialized();
    }

    function initializeOwnerModule(address initialOwner) external override onlyIfNotInitialized {
        nominateNewOwner(initialOwner);
        acceptOwnership();

        _ownableStore().initialized = true;
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

import "../errors/InitError.sol";

abstract contract InitializableMixin {
    modifier onlyIfInitialized() {
        if (!_isInitialized()) {
            revert InitError.NotInitialized();
        }

        _;
    }

    modifier onlyIfNotInitialized() {
        if (_isInitialized()) {
            revert InitError.AlreadyInitialized();
        }

        _;
    }

    function _isInitialized() internal view virtual returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOwnerModule {
    function initializeOwnerModule(address initialOwner) external;

    function isOwnerModuleInitialized() external view returns (bool);
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

library InitError {
    error AlreadyInitialized();
    error NotInitialized();
}