# @version ^0.3.7
"""
@title Multicall Functions
@license GNU Affero General Public License v3.0
@author pcaversaccio
@notice These functions can be used to batch together multiple external
        function calls into one single external function call.
        The implementation is inspired by Matt Solomon's implementation here:
        https://github.com/mds1/multicall/blob/master/src/Multicall3.sol.
@custom:security Make sure you understand how `msg.sender` works in `CALL` vs
                 `DELEGATECALL` to the multicall contract, as well as the risks
                 of using `msg.value` in a multicall. To learn more about the latter, see:
                 - https://github.com/runtimeverification/verified-smart-contracts/wiki/List-of-Security-Vulnerabilities#payable-multicall,
                 - https://samczsun.com/two-rights-might-make-a-wrong.
"""

# @dev Batch struct for ordinary (i.e. `nonpayable`) function calls.
struct Batch:
    target: address
    allow_failure: bool
    call_data: Bytes[max_value(uint16)]

# @dev Result struct for function call results.
struct Result:
    success: bool
    return_data: Bytes[max_value(uint8)]

owner: public(address)

@external
@payable
def __init__(owner: address):
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    """
    self.owner = owner

@external
def multicall(data: DynArray[Batch, max_value(uint8)]) -> DynArray[Result, max_value(uint8)]:
    """
    @dev Aggregates function calls, ensuring that each
         function returns successfully if required.
         Since this function uses `CALL`, the `msg.sender`
         will be the multicall contract itself.
    @param data The array of `Batch` structs.
    @return DynArray The array of `Result` structs.
    """
    assert tx.origin == self.owner, "Owner Only"
    results: DynArray[Result, max_value(uint8)] = []
    return_data: Bytes[max_value(uint8)] = b""
    success: bool = empty(bool)
    for batch in data:
        if (batch.allow_failure == False):
            return_data = raw_call(batch.target, batch.call_data, max_outsize=max_value(uint8))
            success = True
            results.append(Result({success: success, return_data: return_data}))
        else:
            success, return_data = \
                raw_call(batch.target, batch.call_data, max_outsize=max_value(uint8), revert_on_failure=False)
            results.append(Result({success: success, return_data: return_data}))
    return results