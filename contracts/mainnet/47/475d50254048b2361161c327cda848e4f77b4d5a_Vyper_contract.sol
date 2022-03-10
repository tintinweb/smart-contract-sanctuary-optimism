# @version 0.2.12
from vyper.interfaces import ERC20

implements: ERC20

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

allowance: public(HashMap[address, HashMap[address, uint256]])
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)

AELIN: constant(address) = 0x61BAADcF22d2565B0F471b291C475db5555e0b76

@external
def __init__():
    log Transfer(ZERO_ADDRESS, msg.sender, 0)

@view
@external
def name() -> String[10]:
    return "Baby Aelin"

@view
@external
def symbol() -> String[6]:
    return "bAELIN"

@view
@external
def decimals() -> uint256:
    return 12

@internal
def _mint(receiver: address, amount: uint256):
    assert not receiver in [self, ZERO_ADDRESS]

    self.balanceOf[receiver] += amount
    self.totalSupply += amount

    log Transfer(ZERO_ADDRESS, receiver, amount)

@internal
def _burn(sender: address, amount: uint256):
    self.balanceOf[sender] -= amount
    self.totalSupply -= amount

    log Transfer(sender, ZERO_ADDRESS, amount)

@internal
def _transfer(sender: address, receiver: address, amount: uint256):
    assert not receiver in [self, ZERO_ADDRESS]

    self.balanceOf[sender] -= amount
    self.balanceOf[receiver] += amount

    log Transfer(sender, receiver, amount)

@external
def transfer(receiver: address, amount: uint256) -> bool:
    self._transfer(msg.sender, receiver, amount)
    return True

@external
def transferFrom(sender: address, receiver: address, amount: uint256) -> bool:
    self.allowance[sender][msg.sender] -= amount
    self._transfer(sender, receiver, amount)
    return True

@external
def approve(spender: address, amount: uint256) -> bool:
    self.allowance[msg.sender][spender] = amount
    log Approval(msg.sender, spender, amount)
    return True

@external
def wrap(amount: uint256 = MAX_UINT256, receiver: address = msg.sender) -> bool:
    mint_amount: uint256 = min(amount, ERC20(AELIN).balanceOf(msg.sender))
    assert ERC20(AELIN).transferFrom(msg.sender, self, mint_amount)
    self._mint(receiver, mint_amount)
    return True

@external
def unwrap(amount: uint256 = MAX_UINT256, receiver: address = msg.sender) -> bool:
    burn_amount: uint256 = min(amount, self.balanceOf[msg.sender])
    self._burn(msg.sender, burn_amount)
    assert ERC20(AELIN).transfer(receiver, burn_amount)
    return True