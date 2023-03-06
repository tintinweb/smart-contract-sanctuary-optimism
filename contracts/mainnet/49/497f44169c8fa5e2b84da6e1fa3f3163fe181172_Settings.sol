// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {ISettings} from "./interfaces/ISettings.sol";
import {Owned} from "@solmate/auth/Owned.sol";

/// @title Kwenta Settings for Accounts
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
contract Settings is ISettings, Owned {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISettings
    uint256 public constant MAX_BPS = 10_000;

    /*//////////////////////////////////////////////////////////////
                                SETTINGS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISettings
    address public treasury;

    /// @inheritdoc ISettings
    uint256 public tradeFee;

    /// @inheritdoc ISettings
    uint256 public limitOrderFee;

    /// @inheritdoc ISettings
    uint256 public stopOrderFee;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice set initial account fees
    /// @param _owner: owner of the contract
    /// @param _treasury: Kwenta's Treasury Address
    /// @param _tradeFee: fee denoted in BPS
    /// @param _limitOrderFee: fee denoted in BPS
    /// @param _stopOrderFee: fee denoted in BPS
    constructor(
        address _owner,
        address _treasury,
        uint256 _tradeFee,
        uint256 _limitOrderFee,
        uint256 _stopOrderFee
    ) Owned(_owner) {
        treasury = _treasury;

        /// @notice ensure valid fees
        if (_tradeFee > MAX_BPS) revert InvalidFee(_tradeFee);
        if (_limitOrderFee > MAX_BPS) revert InvalidFee(_limitOrderFee);
        if (_stopOrderFee > MAX_BPS) revert InvalidFee(_stopOrderFee);

        /// @notice set initial fees
        tradeFee = _tradeFee;
        limitOrderFee = _limitOrderFee;
        stopOrderFee = _stopOrderFee;
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISettings
    function setTreasury(address _treasury) external override onlyOwner {
        /// @notice ensure valid address for Kwenta Treasury
        if (_treasury == address(0)) revert ZeroAddress();

        // @notice ensure address will change
        if (_treasury == treasury) revert DuplicateAddress();

        /// @notice set Kwenta Treasury address
        treasury = _treasury;

        emit TreasuryAddressChanged(_treasury);
    }

    /// @inheritdoc ISettings
    function setTradeFee(uint256 _fee) external override onlyOwner {
        /// @notice ensure valid fee
        if (_fee > MAX_BPS) revert InvalidFee(_fee);

        // @notice ensure fee will change
        if (_fee == tradeFee) revert DuplicateFee();

        /// @notice set fee
        tradeFee = _fee;

        emit TradeFeeChanged(_fee);
    }

    /// @inheritdoc ISettings
    function setLimitOrderFee(uint256 _fee) external override onlyOwner {
        /// @notice ensure valid fee
        if (_fee > MAX_BPS) revert InvalidFee(_fee);

        // @notice ensure fee will change
        if (_fee == limitOrderFee) revert DuplicateFee();

        /// @notice set fee
        limitOrderFee = _fee;

        emit LimitOrderFeeChanged(_fee);
    }

    /// @inheritdoc ISettings
    function setStopOrderFee(uint256 _fee) external override onlyOwner {
        /// @notice ensure valid fee
        if (_fee > MAX_BPS) revert InvalidFee(_fee);

        // @notice ensure fee will change
        if (_fee == stopOrderFee) revert DuplicateFee();

        /// @notice set fee
        stopOrderFee = _fee;

        emit StopOrderFeeChanged(_fee);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Settings Interface
/// @author JaredBorders ([email protected])
/// @dev all fees are denoted in Basis points (BPS)
interface ISettings {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted after changing treasury address
    /// @param treasury: new treasury address
    event TreasuryAddressChanged(address treasury);

    /// @notice emitted after a successful trade fee change
    /// @param fee: fee denoted in BPS
    event TradeFeeChanged(uint256 fee);

    /// @notice emitted after a successful limit order fee change
    /// @param fee: fee denoted in BPS
    event LimitOrderFeeChanged(uint256 fee);

    /// @notice emitted after a successful stop loss fee change
    /// @param fee: fee denoted in BPS
    event StopOrderFeeChanged(uint256 fee);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice zero address cannot be used
    error ZeroAddress();

    /// @notice new treasury address cannot be the same as the old treasury address
    error DuplicateAddress();

    /// @notice invalid fee (fee > MAX_BPS)
    /// @param fee: fee denoted in BPS
    error InvalidFee(uint256 fee);

    /// @notice new fee cannot be the same as the old fee
    error DuplicateFee();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return max BPS; used for decimals calculations
    // solhint-disable-next-line func-name-mixedcase
    function MAX_BPS() external view returns (uint256);

    // @return Kwenta's Treasury Address
    function treasury() external view returns (address);

    /// @return fee imposed on all trades
    function tradeFee() external view returns (uint256);

    /// @return fee imposed on limit orders
    function limitOrderFee() external view returns (uint256);

    /// @return fee imposed on stop losses
    function stopOrderFee() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice set new treasury address
    /// @param _treasury: new treasury address
    function setTreasury(address _treasury) external;

    /// @notice set new trade fee
    /// @param _fee: fee imposed on all trades
    function setTradeFee(uint256 _fee) external;

    /// @notice set new limit order fee
    /// @param _fee: fee imposed on limit orders
    function setLimitOrderFee(uint256 _fee) external;

    /// @notice set new stop loss fee
    /// @param _fee: fee imposed on stop losses
    function setStopOrderFee(uint256 _fee) external;
}