// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.15;

import "./FirnBase.sol";
import "./FirnLogic.sol";
import "./Utils.sol";

contract FirnReader {
    using Utils for Utils.Point;

    FirnBase immutable _base;
    FirnLogic immutable _logic;

    constructor(address payable base_, address logic_) {
        _base = FirnBase(base_);
        _logic = FirnLogic(logic_);
    }

    function sampleAnonset(bytes32 seed, uint32 amount) external view returns (bytes32[N] memory result) {
        uint256 successes = 0;
        uint256 attempts = 0;
        while (successes < N) {
            attempts++;
            if (attempts > 50) {
                amount >>= 1;
                attempts = 0;
            }
            seed = keccak256(abi.encode(seed));
            uint256 entropy = uint256(seed);
            uint256 layer = entropy % _base.blackHeight();
            entropy >>= 8; // an overestimate on the _log_ (!) of the blackheight of the _base. blackheight <= 256.
            uint64 cursor = _base.root();
            bool red = false; // avoid a "shadowing" warning
            for (uint256 i = 0; i < layer; i++) {
                // inv: at the beginning of the loop, it points to the index-ith black node in the rightmost path.
                (,,cursor,) = _base.nodes(cursor); // _base.nodes[cursor].right
                (,,,red) = _base.nodes(cursor); // if (_base.nodes[cursor].red)
                if (red) (,,cursor,) = _base.nodes(cursor);
            }
            uint256 subLayer; // (weighted) random element of {0, ..., blackHeight - 1 - layer}, low more likely.
            while (true) {
                bool found = false;
                for (uint256 i = 0; i < _base.blackHeight() - layer; i++) {
                    if (entropy & 0x01 == 0x01) {
                        subLayer = i;
                        found = true;
                        break;
                    }
                    entropy >>= 1;
                }
                if (found) break;
            }
            entropy >>= 1; // always a 1 here. get rid of it.
            for (uint256 i = 0; i < _base.blackHeight() - 1 - layer - subLayer; i++) {
                // at beginning of loop, points to the layer + ith black node down _random_ path...
                if (entropy & 0x01 == 0x01) (,,cursor,) = _base.nodes(cursor); // cursor = _base.nodes[cursor].right
                else (,cursor,,) = _base.nodes(cursor); // cursor = _base.nodes[cursor].left
                entropy >>= 1;
                (,,,red) = _base.nodes(cursor); // if (_base.nodes[cursor].red)
                if (red) {
                    if (entropy & 0x01 == 0x01) (,,cursor,) = _base.nodes(cursor);
                    else (,cursor,,) = _base.nodes(cursor);
                    entropy >>= 1;
                }
            }
            (,,uint64 right,) = _base.nodes(cursor);
            (,,,red) = _base.nodes(right);
            if (entropy & 0x01 == 0x01 && red) {
                (,,cursor,) = _base.nodes(cursor);
            }
            else if (entropy & 0x02 == 0x02) {
                (,uint64 left,,) = _base.nodes(cursor);
                (,,,red) = _base.nodes(left);
                if (red) (,cursor,,) = _base.nodes(cursor);
            }
            entropy >>= 2;
            uint256 length = _base.lengths(cursor);
            bytes32 account = _base.lists(cursor, entropy % length);
            (,uint64 candidate,) = _base.info(account); // what is the total amount this person has deposited?
            if (candidate < amount) continue; // skip them for now
            bool duplicate = false;
            for (uint256 i = 0; i < successes; i++) {
                if (result[i] == account) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;
            attempts = 0;
            result[successes++] = account;
        }
    }

    function simulateAccounts(bytes32[] calldata Y, uint64 epoch) external view returns (bytes32[2][] memory result) {
        // interestingly, we lose no efficiency by accepting compressed, because we never have to decompress.
        result = new bytes32[2][](Y.length);
        for (uint256 i = 0; i < Y.length; i++) {
            Utils.Point[2] memory acc;
            (acc[0].x, acc[0].y) = _base.acc(Y[i], 0);
            (acc[1].x, acc[1].y) = _base.acc(Y[i], 1);
            if (_logic.lastRollOver(Y[i]) < epoch) {
                Utils.Point[2] memory pending;
                (pending[0].x, pending[0].y) = _base.pending(Y[i], 0);
                (pending[1].x, pending[1].y) = _base.pending(Y[i], 1);
                acc[0] = acc[0].add(pending[0]);
                acc[1] = acc[1].add(pending[1]);
            }
            result[i][0] = Utils.compress(acc[0]);
            result[i][1] = Utils.compress(acc[1]);
        }
    }
}