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

# @dev Emitted when the ownership is transferred
# from `previous_owner` to `new_owner`.
event OwnershipTransferred:
    previous_owner: indexed(address)
    new_owner: indexed(address)


interface token_contract:
    def transfer(_to:address,_amount:uint256): nonpayable


@external
@payable
def __init__():
    self._transfer_ownership(msg.sender)


@external
@payable
def multicall_10(data: DynArray[Batch, 10]) -> DynArray[Result, max_value(uint8)]:
    """
    @dev Aggregates function calls, ensuring that each
         function returns successfully if required.
         Since this function uses `CALL`, the `msg.sender`
         will be the multicall contract itself.
    @param data The array of `Batch` structs.
    @return DynArray The array of `Result` structs.
    """
    self._check_owner()
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
                raw_call(batch.target, batch.call_data, max_outsize=max_value(uint8),revert_on_failure=False)
            results.append(Result({success: success, return_data: return_data}))
    return results

@external
@payable
def multicall_20(data: DynArray[Batch, 20]) -> DynArray[Result, max_value(uint8)]:
    """
    @dev Aggregates function calls, ensuring that each
         function returns successfully if required.
         Since this function uses `CALL`, the `msg.sender`
         will be the multicall contract itself.
    @param data The array of `Batch` structs.
    @return DynArray The array of `Result` structs.
    """
    self._check_owner()
    results: DynArray[Result, max_value(uint8)] = []
    return_data: Bytes[max_value(uint8)] = b""
    success: bool = empty(bool)
    for batch in data:
        if (batch.allow_failure == False):
            return_data = raw_call(batch.target, batch.call_data,  max_outsize=max_value(uint8))
            success = True
            results.append(Result({success: success, return_data: return_data}))
        else:
            success, return_data = \
                raw_call(batch.target, batch.call_data, max_outsize=max_value(uint8),revert_on_failure=False)
            results.append(Result({success: success, return_data: return_data}))
    return results

@external
def recover_token(token_address: address, amount: uint256):
    token_contract(token_address).transfer(self.owner,amount)

@external
def recover_eth():
    send(self.owner,self.balance)

@external
def transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner`.
    @notice Note that this function can only be
            called by the current `owner`. Also,
            the `new_owner` cannot be the zero address.
    @param new_owner The 20-byte address of the new owner.
    """
    self._check_owner()
    assert new_owner != empty(address), "Ownable: new owner is the zero address"
    self._transfer_ownership(new_owner)


@external
def renounce_ownership():
    """
    @dev Leaves the contract without an owner.
    @notice Renouncing ownership will leave the
            contract without an owner, thereby
            removing any functionality that is
            only available to the owner.
    """
    self._check_owner()
    self._transfer_ownership(empty(address))


@internal
def _check_owner():
    """
    @dev Throws if the sender is not the owner.
    """
    assert msg.sender == self.owner, "Ownable: caller is not the owner"


@internal
def _transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner`.
    @notice This is an `internal` function without
            access restriction.
    @param new_owner The 20-byte address of the new owner.
    """
    old_owner: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old_owner, new_owner)