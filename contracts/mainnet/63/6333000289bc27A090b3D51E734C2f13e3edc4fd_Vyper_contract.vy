# @version 0.2.15
"""
@title Token Treasury v2
@author Hundred Finance
@license MIT
"""

from vyper.interfaces import ERC20


minter: public(address)
admin: public(address)

@external
def __init__(_admin: address):
    self.admin = _admin

@external
@nonpayable
def set_minter(_minter: address):
    assert msg.sender == self.admin # only admin can set minter
    self.minter = _minter

@external
@nonpayable
def set_admin(_admin: address):
    assert msg.sender == self.admin # only admin can set minter
    self.admin = _admin

@external
@nonpayable
def mint(_to: address, _token: address, _amount: uint256) -> bool:
    assert msg.sender == self.minter or msg.sender == self.admin  # only minter or admin can distribute tokens
    return ERC20(_token).transfer(_to, _amount)