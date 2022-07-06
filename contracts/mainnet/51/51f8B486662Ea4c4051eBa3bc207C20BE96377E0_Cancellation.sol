/**
* SPDX-License-Identifier: MIT
*/
pragma solidity ^0.8.0;

interface IBurnable {

    function burn(uint256 amount) external;

}

/**
* SPDX-License-Identifier: MIT
*
* Copyright (c) 2016-2019 zOS Global Limited
*
*/
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */

interface IERC20 {

    // Optional functions
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

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
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
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
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20/IERC20.sol";
import "./IOffer.sol";
interface IDraggable {
    
    function wrapped() external view returns (IERC20);
    function unwrap(uint256 amount) external;
    function offer() external view returns (IOffer);
    function oracle() external view returns (address);
    function drag(address buyer, IERC20 currency) external;
    function notifyOfferEnded() external;
    function votingPower(address voter) external returns (uint256);
    function totalVotingTokens() external view returns (uint256);
    function notifyVoted(address voter) external;
    function migrate() external;

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20/IERC20.sol";

interface IOffer {
	function makeCompetingOffer(IOffer newOffer) external;

	// if there is a token transfer while an offer is open, the votes get transfered too
	function notifyMoved(address from, address to, uint256 value) external;

	function currency() external view returns (IERC20);

	function price() external view returns (uint256);

	function isWellFunded() external view returns (bool);

	function voteYes() external;

	function voteNo() external;
}

/**
* SPDX-License-Identifier: LicenseRef-Aktionariat
*
* MIT License with Automated License Fee Payments
*
* Copyright (c) 2020 Aktionariat AG (aktionariat.com)
*
* Permission is hereby granted to any person obtaining a copy of this software
* and associated documentation files (the "Software"), to deal in the Software
* without restriction, including without limitation the rights to use, copy,
* modify, merge, publish, distribute, sublicense, and/or sell copies of the
* Software, and to permit persons to whom the Software is furnished to do so,
* subject to the following conditions:
*
* - The above copyright notice and this permission notice shall be included in
*   all copies or substantial portions of the Software.
* - All automated license fee payments integrated into this and related Software
*   are preserved.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/
pragma solidity ^0.8.0;

import "../draggable/IDraggable.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/IBurnable.sol";

contract Cancellation {

    address public immutable target;
    address public immutable base;

    constructor(address target_) {
        target = target_;
        base = address(IDraggable(target_).wrapped());
    }

    function burnThemAll() external {
        uint256 balance = IERC20(base).balanceOf(address(this));
        require(IERC20(base).totalSupply() == balance);
        IBurnable(base).burn(balance);
    }

    function name() external pure returns (string memory) {
        return "Cancelled Token";
    }

    function symbol() external pure returns (string memory) {
        return "---";
    }

    function migrate() external {
        IDraggable(target).migrate();
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == target){
            return IERC20(base).balanceOf(address(this));
        } else {
            return 0;
        }
    }

}