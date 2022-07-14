// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

contract OptGasPriceLogger {
  event DebugGas(
    uint256 indexed index,
    uint256 indexed blockNum,
    uint256 gasLeft,
    uint256 gasPrice,
    uint256 l1GasCost
  );
  mapping(bytes32 => bool) public dummyMap; // used to force storage lookup

  constructor() {}

  function log(bytes calldata input) public returns (bool) {
    emit DebugGas(0, block.number, gasleft(), tx.gasprice, 0);
    uint256 l1CostWei;

    // Get L1 cost of this tx
    // contract to call is optimism oracle at 0x420000000000000000000000000000000000000F
    // function to call is getL1Fee(bytes) uint256 which corresponds to selector 0x49948e0e
    // The bytes data is supposed to be RLP serialized (msg.data, to, gasPrice, type, gasLimit, nonce)
    // However we don't have all variables easily accessible. Only msg.data is of variable length, for rest
    // we use an upper bound of 18 bytes and append it to msg.data
    (bool success, bytes memory result) = address(0x420000000000000000000000000000000000000F).call(
      abi.encodeWithSelector(
        0x49948e0e,
        bytes.concat(
          msg.data,
          bytes(
            "0xffffffffffffffffffffffffffffffffffff"
          )
        )
      )
    );
    l1CostWei = abi.decode(result, (uint256));

    emit DebugGas(0, block.number, gasleft(), tx.gasprice, l1CostWei);

    uint256 startGas = gasleft();
    bool dummy;
    uint256 blockNum = block.number - 1;
    // burn gas
    while (startGas - gasleft() < 500000) {
      dummy = dummy && dummyMap[blockhash(blockNum)]; // arbitrary storage reads
      blockNum--;
    }

    emit DebugGas(2, block.number, gasleft(), tx.gasprice, 0);

    return true;
  }
}