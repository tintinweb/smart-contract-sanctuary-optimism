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
pragma solidity 0.8.7;

interface ILiquidityGauge {
    function user_checkpoint(address user) external returns (bool);
}

contract BeethovenCheckpointer {
    function checkpoint_my_gauges(address[] calldata gauges_to_checkpoint) external {
        for (uint256 i = 0; i < gauges_to_checkpoint.length; i++) {
            ILiquidityGauge(gauges_to_checkpoint[i]).user_checkpoint(msg.sender);
        }
    }

    function checkpoint_user_gauges(address user, address[] calldata gauges_to_checkpoint) external {
        for (uint256 i = 0; i < gauges_to_checkpoint.length; i++) {
            ILiquidityGauge(gauges_to_checkpoint[i]).user_checkpoint(user);
        }
    }
}