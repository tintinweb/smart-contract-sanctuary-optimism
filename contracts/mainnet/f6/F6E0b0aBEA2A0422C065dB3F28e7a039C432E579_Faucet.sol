// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IERC20 {
  /// @notice ERC0 transfer tokens
  function transfer(address recipient, uint256 amount) external returns (bool);
  /// @notice ERC20 balance of address
  function balanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// ============ Imports ============

import "../interfaces/token/IERC20.sol"; // ERC20 minified interface

/// @title Faucet
/// @author Anish Agnihotri
/// @notice Drips ECO to users that authenticate with a server via twitter. Does not allow repeat drips. 
contract Faucet {

    /// ============ Immutable storage ============

    /// @notice ECO ERC20 token
    IERC20 public immutable ECO;

    /// ============ Mutable storage ============

    /// @notice ECO to disperse (unverified)
    uint256 public DRIP_UNVERIFIED;

    /// @notice ECO to disperse (verified)
    uint256 public DRIP_VERIFIED;

    /// @notice Addresses of approved operators
    mapping(address => bool) public approvedOperators;
    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;
    /// @notice Mint status of each hashed socialID
    mapping(string => bool) public hasMinted;

    /// ============ Modifiers ============

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    /// @notice Requires sender to be contract approved operator
    modifier isApprovedOperator() {
        // Ensure sender is in approved operators or is super operator
        require(
            approvedOperators[msg.sender] || superOperators[msg.sender], 
            "Not approved operator"
        );
        _;
    }

    /// ============ Events ============

    /// @notice Emitted after faucet drips to a recipient
    /// @param recipient address dripped to
    event FaucetDripped(address indexed recipient);

    /// @notice Emitted after faucet drained to a recipient
    /// @param recipient address drained to
    event FaucetDrained(address indexed recipient);

    /// @notice Emitted after operator status is updated
    /// @param operator address being updated
    /// @param status new operator status
    event OperatorUpdated(address indexed operator, bool status);

    /// @notice Emitted after super operator is updated
    /// @param operator address being updated
    /// @param status new operator status
    event SuperOperatorUpdated(address indexed operator, bool status);

    /// @notice Emitted after drip amount is updated
    /// @param newUnverifiedDrip new drip_unverified amount
    /// @param newVerifiedDrip new drip_verified amount
    event DripAmountsUpdated(uint256 newUnverifiedDrip, uint256 newVerifiedDrip);

    /// ============ Constructor ============

    /// @notice Creates a new faucet contract
    /// @param _ECO address of ECO contract
    constructor(address _ECO, uint256 _DRIP_UNVERIFIED, uint256 _DRIP_VERIFIED, address _superOperator, address[] memory _approvedOperators) {
        ECO = IERC20(_ECO);
        DRIP_UNVERIFIED = _DRIP_UNVERIFIED;
        DRIP_VERIFIED = _DRIP_VERIFIED;
        superOperators[_superOperator] = true;

        for(uint i = 0; i < _approvedOperators.length; i++) {
            approvedOperators[_approvedOperators[i]] = true;
        }
    }

    /// ============ Functions ============

    /// @notice Drips and mints tokens to recipient
    /// @param _recipient to drip tokens to
    function drip(string memory _socialHash, address _recipient, bool _verified) external isApprovedOperator {
        require(!hasMinted[_socialHash], "the owner of this social ID has already minted.");

        uint256 dripAmount = _verified ? DRIP_VERIFIED : DRIP_UNVERIFIED;
        // Drip ECO
        require(ECO.transfer(_recipient, dripAmount), "Failed dripping ECO");

        hasMinted[_socialHash] = true;

        emit FaucetDripped(_recipient);
    }

    function drain(address _recipient) external isSuperOperator {
        uint256 ecoBalance = ECO.balanceOf(address(this));
        require(ECO.transfer(_recipient, ecoBalance), "Failed to drain");

        emit FaucetDrained(_recipient);
    }

    /// @notice Allows super operator to update approved drip operator status
    /// @param _operator address to update
    /// @param _status of operator to toggle (true == allowed to drip)
    function updateApprovedOperator(address _operator, bool _status) 
        external 
        isSuperOperator 
    {
        approvedOperators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    /// @notice Allows super operator to update super operator
    /// @param _operator address to update
    /// @param _status of operator to toggle (true === is super operator)
    function updateSuperOperator(address _operator, bool _status) 
        external
        isSuperOperator
    {
        superOperators[_operator] = _status;
        emit SuperOperatorUpdated(_operator, _status);
    }

    /// @notice Allows super operator to update drip amount
    /// @param unverifiedDrip new drip_unverified amount
    /// @param verifiedDrip new drip_verified amount
    function updateDripAmount(
        uint256 unverifiedDrip,
        uint256 verifiedDrip
    ) external isSuperOperator {
        DRIP_UNVERIFIED = unverifiedDrip;
        DRIP_VERIFIED = verifiedDrip;
        emit DripAmountsUpdated(DRIP_UNVERIFIED, DRIP_VERIFIED);
    }
}