// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.6;

interface IVault {
    function totalSupply() external view returns (uint);
    function lockedProfitDegradation() external view returns (uint);
    function lastReport() external view returns (uint);
    function totalAssets() external view returns (uint);
    function lockedProfit() external view returns (uint);
}

contract ShareValueHelper {
    constructor() {}

    function sharesToAmount(address vault, uint shares) external view returns (uint) {
        uint totalSupply = IVault(vault).totalSupply();
        if (totalSupply == 0) return shares;

        uint freeFunds = calculateFreeFunds(vault);
        return (
        shares
        * freeFunds
        / totalSupply
        );
    }

    function amountToShares(address vault, uint amount) external view returns (uint) {
        uint totalSupply = IVault(vault).totalSupply();
        if (totalSupply > 0) {
            return amount * totalSupply / calculateFreeFunds(vault);
        }
        return 0;
    }

    function calculateFreeFunds(address vault) public view returns (uint) {
        uint totalAssets = IVault(vault).totalAssets();
        uint lockedFundsRatio = (block.timestamp - IVault(vault).lastReport()) * IVault(vault).lockedProfitDegradation();

        if (lockedFundsRatio < 10 ** 18) {
            uint lockedProfit = IVault(vault).lockedProfit();
            lockedProfit -= (
            lockedFundsRatio
            * lockedProfit
            / 10 ** 18
            );
            return totalAssets - lockedProfit;
        }
        else {
            return totalAssets;
        }
    }
}