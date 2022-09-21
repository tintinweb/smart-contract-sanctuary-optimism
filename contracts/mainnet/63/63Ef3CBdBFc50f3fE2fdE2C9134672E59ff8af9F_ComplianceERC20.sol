// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.15;

import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "./interfaces/ICompliance.sol";

contract ComplianceERC20 is ERC20 {
    ICompliance public immutable compliance;
    address public immutable safe;
    address public beneficiary;

    constructor(ICompliance _compliance, address _safe) ERC20("", "", 18) {
        compliance = _compliance;
        safe = _safe;
    }

    function initialize(string memory _name, string memory _symbol, address _beneficiary) external {
        require(beneficiary == address(0), "initialized");
        name = _name;
        symbol = _symbol;
        beneficiary = _beneficiary;
    }

    function reinitialize(string memory _name, string memory _symbol, address _beneficiary) external {
        require(msg.sender == beneficiary || msg.sender == safe, "!beneficiary");
        name = _name;
        symbol = _symbol;
        beneficiary = _beneficiary;
    }

    function changeBeneficiary(address _newBeneficiary) external {
        require(msg.sender == beneficiary, "!beneficiary");
        beneficiary = _newBeneficiary;
        transfer(_newBeneficiary, balanceOf[msg.sender]);
    }

    function mint(address _to, uint256 _amount) external {
        require(msg.sender == safe, "!safe");
        _mint(_to, _amount);
    }

    function _mint(address to, uint256 amount) internal override {
        compliance.authorizeTransfer(address(0), to, amount);
        super._mint(to, amount);
    }

    function _burn(address from, uint256 amount) internal override {
        compliance.authorizeTransfer(from, address(0), amount);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        compliance.authorizeTransfer(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        compliance.authorizeTransfer(from, to, amount);
        return super.transferFrom(from, to, amount);
    }

    function batchTransfer(address[] calldata tos, uint256[] calldata amounts) public {
        require(tos.length == amounts.length, "length diff");
        for (uint256 i = 0; i < tos.length; i++) {
            compliance.authorizeTransfer(msg.sender, tos[i], amounts[i]);
            super.transfer(tos[i], amounts[i]);
        }
    }

    function legal() external view returns (string memory) {
        return compliance.legal(address(this));
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.12;

/**
 * Source: https://raw.githubusercontent.com/simple-restricted-token/reference-implementation/master/contracts/token/ERC1404/ERC1404.sol
 * With ERC-20 APIs removed (will be implemented as a separate contract).
 * And adding authorizeTransfer.
 */
interface ICompliance {
    /**
     * @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
     * @param from Sending address
     * @param to Receiving address
     * @param value Amount of tokens being transferred
     * @return Code by which to reference message for rejection reasoning
     * @dev Overwrite with your custom transfer restriction logic
     */
    function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);

    /**
     * @notice Returns a human-readable message for a given restriction code
     * @param restrictionCode Identifier for looking up a message
     * @return Text showing the restriction's reasoning
     * @dev Overwrite with your custom message and restrictionCode handling
     */
    function messageForTransferRestriction(uint8 restrictionCode) external pure returns (string memory);

    /**
     * @notice Called by the DAT contract before a transfer occurs.
     * @dev This call will revert when the transfer is not authorized.
     * This is a mutable call to allow additional data to be recorded,
     * such as when the user aquired their tokens.
     */
    function authorizeTransfer(address _from, address _to, uint256 _value) external;

    function legal(address _safe) external view returns (string memory);
}