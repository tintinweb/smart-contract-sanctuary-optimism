// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {ISettings} from "src/interfaces/ISettings.sol";
import {Owned} from "src/utils/Owned.sol";

/// @title Kwenta Smart Margin Account Settings
/// @author JaredBorders ([email protected])
/// @notice This contract is used to manage the settings of the Kwenta Smart Margin Account
/// @custom:caution Changes to this contract will effectively clear any existing settings.
/// Post update, the owner will need to reconfigure the settings either in the deploy script or
/// via the Settings contract constructor.
contract Settings is ISettings, Owned {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISettings
    bool public accountExecutionEnabled = true;

    /// @inheritdoc ISettings
    uint256 public executorFee = 1 ether / 1000;

    /// @notice mapping of whitelisted tokens available for swapping via uniswap commands
    mapping(address => bool) internal _whitelistedTokens;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice constructs the Settings contract
    /// @param _owner: address of the owner of the contract
    constructor(address _owner) Owned(_owner) {}

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISettings
    function isTokenWhitelisted(address _token)
        external
        view
        override
        returns (bool)
    {
        return _whitelistedTokens[_token];
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISettings
    function setAccountExecutionEnabled(bool _enabled)
        external
        override
        onlyOwner
    {
        accountExecutionEnabled = _enabled;

        emit AccountExecutionEnabledSet(_enabled);
    }

    /// @inheritdoc ISettings
    function setExecutorFee(uint256 _executorFee) external override onlyOwner {
        executorFee = _executorFee;

        emit ExecutorFeeSet(_executorFee);
    }

    /// @inheritdoc ISettings
    function setTokenWhitelistStatus(address _token, bool _isWhitelisted)
        external
        override
        onlyOwner
    {
        _whitelistedTokens[_token] = _isWhitelisted;

        emit TokenWhitelistStatusUpdated(_token, _isWhitelisted);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Smart Margin Account Settings Interface
/// @author JaredBorders ([email protected])
interface ISettings {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when account execution is enabled or disabled
    /// @param enabled: true if account execution is enabled, false if disabled
    event AccountExecutionEnabledSet(bool enabled);

    /// @notice emitted when the executor fee is updated
    /// @param executorFee: the executor fee
    event ExecutorFeeSet(uint256 executorFee);

    /// @notice emitted when a token is added to or removed from the whitelist
    /// @param token: address of the token
    /// @param isWhitelisted: true if token is whitelisted, false if not
    event TokenWhitelistStatusUpdated(address token, bool isWhitelisted);

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice checks if account execution is enabled or disabled
    /// @return enabled: true if account execution is enabled, false if disabled
    function accountExecutionEnabled() external view returns (bool);

    /// @notice gets the conditional order executor fee
    /// @return executorFee: the executor fee
    function executorFee() external view returns (uint256);

    /// @notice checks if token is whitelisted
    /// @param _token: address of the token to check
    /// @return true if token is whitelisted, false if not
    function isTokenWhitelisted(address _token) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice enables or disables account execution
    /// @param _enabled: true if account execution is enabled, false if disabled
    function setAccountExecutionEnabled(bool _enabled) external;

    /// @notice sets the conditional order executor fee
    /// @param _executorFee: the executor fee
    function setExecutorFee(uint256 _executorFee) external;

    /// @notice adds/removes token to/from whitelist
    /// @dev does not check if token was previously whitelisted
    /// @param _token: address of the token to add
    /// @param _isWhitelisted: true if token is to be whitelisted, false if not
    function setTokenWhitelistStatus(address _token, bool _isWhitelisted)
        external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}