# @version 0.2.15
"""
@title Token Minter v2
@author Hundred Finance
@license MIT
"""

interface LiquidityGauge:
    # Presumably, other gauges will provide the same interfaces
    def integrate_fraction(token: address, user: address) -> uint256: view
    def user_checkpoint(addr: address) -> bool: nonpayable

interface MERC20:
    def mint(_to: address, _token: address, _value: uint256) -> bool: nonpayable

interface GaugeController:
    def gauge_types(addr: address) -> int128: view


event Minted:
    recipient: indexed(address)
    gauge: address
    token: address
    minted: uint256


MAX_TOKENS: constant(uint256) = 10

token_count: public(uint256)
tokens: public(address[MAX_TOKENS])


treasury: public(address)
controller: public(address)
admin: public(address)

# user -> gauge -> token -> value
minted: public(HashMap[address, HashMap[address, HashMap[address, uint256]]])

# minter -> user -> can mint?
allowed_to_mint_for: public(HashMap[address, HashMap[address, bool]])


@external
def __init__(_treasury: address, _controller: address):
    self.treasury = _treasury
    self.controller = _controller
    self.admin = msg.sender


@internal
def _mint_for(gauge_addr: address, _token: address, _for: address):
    assert GaugeController(self.controller).gauge_types(gauge_addr) >= 0  # dev: gauge is not added

    LiquidityGauge(gauge_addr).user_checkpoint(_for)
    total_mint: uint256 = LiquidityGauge(gauge_addr).integrate_fraction(_token, _for)
    to_mint: uint256 = total_mint - self.minted[_for][gauge_addr][_token]

    if to_mint != 0:
        MERC20(self.treasury).mint(_for, _token, to_mint)
        self.minted[_for][gauge_addr][_token] = total_mint

        log Minted(_for, gauge_addr, _token, total_mint)


@external
@nonreentrant('lock')
def mint(gauge_addr: address):
    """
    @notice Mint everything which belongs to `msg.sender` and send to them
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    """
    for j in range(MAX_TOKENS):
        _token: address = self.tokens[j]
        if _token == ZERO_ADDRESS:
            break
        self._mint_for(gauge_addr, _token, msg.sender)


@external
@nonreentrant('lock')
def mint_many(gauge_addrs: address[8]):
    """
    @notice Mint everything which belongs to `msg.sender` across multiple gauges
    @param gauge_addrs List of `LiquidityGauge` addresses
    """
    for i in range(8):
        if gauge_addrs[i] == ZERO_ADDRESS:
            break
        for j in range(MAX_TOKENS):
            _token: address = self.tokens[j]
            if _token == ZERO_ADDRESS:
                break
            self._mint_for(gauge_addrs[i], _token, msg.sender)


@external
@nonreentrant('lock')
def mint_for(gauge_addr: address, _for: address):
    """
    @notice Mint tokens for `_for`
    @dev Only possible when `msg.sender` has been approved via `toggle_approve_mint`
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    @param _for Address to mint to
    """
    if self.allowed_to_mint_for[msg.sender][_for]:
        for i in range(MAX_TOKENS):
            _token: address = self.tokens[i]
            if _token == ZERO_ADDRESS:
                break
            self._mint_for(gauge_addr, _token, _for)


@external
def toggle_approve_mint(minting_user: address):
    """
    @notice allow `minting_user` to mint for `msg.sender`
    @param minting_user Address to toggle permission for
    """
    self.allowed_to_mint_for[minting_user][msg.sender] = not self.allowed_to_mint_for[minting_user][msg.sender]


@external
def add_token(_token: address):
    """
    @notice Set the reward token
    """
    assert msg.sender == self.admin  # dev: only owner

    token_count: uint256 = self.token_count
    assert token_count < MAX_TOKENS

    self.tokens[token_count] = _token
    self.token_count = token_count + 1


@external
@nonpayable
def set_admin(_admin: address):
    assert msg.sender == self.admin # only admin can set minter
    self.admin = _admin