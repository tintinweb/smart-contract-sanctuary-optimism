// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ERC20Burnable.sol";

import "./Operator.sol";

/*
   _____ ________________  _____   ________
  / ___// ____/ ____/ __ \/  _/ | / / ____/
  \__ \/ __/ / __/ / / / // //  |/ / / __  
 ___/ / /___/ /___/ /_/ // // /|  / /_/ /  
/____/_____/_____/_____/___/_/ |_/\____/   
*/
contract SBond is ERC20Burnable, Operator {
    /**
     * @notice Constructs the TOMB Bond ERC-20 contract.
     */
    constructor() public ERC20("SBOND", "SBOND") {}

    /**
     * @notice Operator mints basis bonds to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of basis bonds to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }
}