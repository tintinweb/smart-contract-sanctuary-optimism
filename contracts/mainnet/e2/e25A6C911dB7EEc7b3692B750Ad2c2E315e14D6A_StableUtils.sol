// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

library StableUtils {

    function amount0(
        uint256 _amount1,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _decimals0,
        uint256 _decimals1
    ) external pure returns (uint256 _amount0) {
        uint256 xy = _k(_reserve0, _reserve1, _decimals0, _decimals1);
        _reserve0 = (_reserve0 * 1e18) / _decimals0;
        _reserve1 = (_reserve1 * 1e18) / _decimals1;
        _amount1 = (_amount1 * 1e18) / _decimals1;
        _amount0 = _reserve0 - _y(_amount1 + _reserve1, xy, _reserve0, _decimals0, _decimals1);
        _amount0 = (_amount0 * _decimals0) / 1e18;
    }

    function amount1(
        uint256 _amount0,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _decimals0,
        uint256 _decimals1
    ) external pure returns (uint256 _amount1) {
        uint256 xy = _k(_reserve0, _reserve1, _decimals0, _decimals1);
        _reserve0 = (_reserve0 * 1e18) / _decimals0;
        _reserve1 = (_reserve1 * 1e18) / _decimals1;
        _amount0 = (_amount0 * 1e18) / _decimals0;
        _amount1 = _reserve1 - _y(_amount0 + _reserve0, xy, _reserve1, _decimals0, _decimals1);
        _amount1 = (_amount1 * _decimals1) / 1e18;
    }

    function _k(uint256 _x, uint256 _y, uint256 _decimals0, uint256 _decimals1) private pure returns (uint256) {
        _x = (_x * 1e18) / _decimals0;
        _y = (_y * 1e18) / _decimals1;
        uint256 a = (_x * _y) / 1e18;
        uint256 b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);

        return (a * b) / 1e18; // x3y+y3x >= k
    }

    function _f(uint256 x0, uint256 y) private pure returns (uint256) {
        uint256 _a = (x0 * y) / 1e18;
        uint256 _b = ((x0 * x0) / 1e18 + (y * y) / 1e18);

        return (_a * _b) / 1e18;
    }

    function _d(uint256 x0, uint256 y) private pure returns (uint256) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function _y(uint256 x0, uint256 xy, uint256 y, uint256 _decimals0, uint256 _decimals1)
        private
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < 255; i++) {
            uint256 k = _f(x0, y);
            if (k < xy) {
                // there are two cases where dy == 0
                // case 1: The y is converged and we find the correct answer
                // case 2: _d(x0, y) is too large compare to (xy - k) and the rounding error
                //         screwed us.
                //         In this case, we need to increase y by 1
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy) {
                        // We found the correct answer. Return y
                        return y;
                    }
                    if (_k(x0, y + 1, _decimals0, _decimals1) > xy) {
                        // If _k(x0, y + 1) > xy, then we are close to the correct answer.
                        // There's no closer answer than y + 1
                        return y + 1;
                    }
                    dy = 1;
                }
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy || _f(x0, y - 1) < xy) {
                        // Likewise, if k == xy, we found the correct answer.
                        // If _f(x0, y - 1) < xy, then we are close to the correct answer.
                        // There's no closer answer than "y"
                        // It's worth mentioning that we need to find y where f(x0, y) >= xy
                        // As a result, we can't return y - 1 even it's closer to the correct answer
                        return y;
                    }
                    dy = 1;
                }
                y = y - dy;
            }
        }

        revert("!y");
    }

}