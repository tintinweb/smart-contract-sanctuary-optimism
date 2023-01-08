# @version 0.2.15
"""
@title Liquidity Gauge v5
@author Hundred Finance (based on Curve Finance Liquidity Gauge v4)
@license MIT
"""

from vyper.interfaces import ERC20

implements: ERC20


interface RewardPolicyMaker:
    def future_epoch_time() -> uint256: nonpayable
    def rate_at(_timestamp: uint256, _token: address) -> uint256: view
    def epoch_at(_timestamp: uint256) -> uint256: view
    def epoch_start_time(_epoch: uint256) -> uint256: view

interface Controller:
    def gauge_relative_weight(addr: address, time: uint256) -> uint256: view
    def voting_escrow() -> address: view
    def checkpoint_gauge(addr: address): nonpayable

interface Minter:
    def controller() -> address: view
    def minted(user: address, gauge: address, token: address) -> uint256: view
    def token_count() -> uint256: view
    def tokens(index: uint256) -> address: view

interface VotingEscrow:
    def user_last_checkpoint_ts(_user: address) -> uint256: view

interface VotingEscrowBoost:
    def adjusted_balance_of(_account: address) -> uint256: view

interface ERC20Extended:
    def symbol() -> String[26]: view
    def decimals() -> uint256: view


event Deposit:
    provider: indexed(address)
    value: uint256

event Withdraw:
    provider: indexed(address)
    value: uint256

event EmergencyWithdraw:
    provider: indexed(address)
    value: uint256

event UpdateLiquidityLimit:
    user: address
    original_balance: uint256
    original_supply: uint256
    working_balance: uint256
    working_supply: uint256

event CommitOwnership:
    admin: address

event ApplyOwnership:
    admin: address

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256


TOKENLESS_PRODUCTION: constant(uint256) = 40
WEEK: constant(uint256) = 604800
MAX_TOKENS: constant(uint256) = 10

minter: public(address)
reward_policy_maker: public(address)
voting_escrow: public(address)
controller: public(address)
veboost_proxy: public(address)

lp_token: public(address)

balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)
allowance: public(HashMap[address, HashMap[address, uint256]])

name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)

working_balances: public(HashMap[address, uint256])
working_supply: public(uint256)

# The goal is to be able to calculate ∫(rate * balance / totalSupply dt) from 0 till checkpoint
# All values are kept in units of being multiplied by 1e18
period: public(int128)
period_timestamp: public(uint256[100000000000000000000000000000])


# 1e18 * ∫(rate(t) / totalSupply(t) dt) from 0 till checkpoint
# token -> inv supply value
integrate_inv_supply: public(HashMap[address, uint256[100000000000000000000000000000]])

# 1e18 * ∫(rate(t) / totalSupply(t) dt) from (last_action) till checkpoint
# token -> user -> inv supply value
integrate_inv_supply_of: public(HashMap[address, HashMap[address, uint256]])
# user -> checkpoint timestamp
integrate_checkpoint_of: public(HashMap[address, uint256])

# ∫(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
# Units: rate * t = already number of coins per address and token to issue
# token -> user -> checkpoint value
integrate_fraction: public(HashMap[address, HashMap[address, uint256]])

admin: public(address)
future_admin: public(address)
is_killed: public(bool)


@external
def __init__(
        _lp_token: address,
        _minter: address,
        _admin: address,
        _reward_policy_maker: address,
        _veboost_proxy: address
    ):
    """
    @notice Contract constructor
    @param _lp_token Liquidity Pool contract address
    @param _minter Minter contract address
    @param _admin Admin who can kill the gauge
    @param _veboost_proxy veBoost proxy contract
    """

    symbol: String[26] = ERC20Extended(_lp_token).symbol()
    self.name = concat(symbol, " Gauge Deposit")
    self.symbol = concat(symbol, "-gauge")
    self.decimals = ERC20Extended(_lp_token).decimals()

    controller: address = Minter(_minter).controller()

    self.lp_token = _lp_token
    self.minter = _minter
    self.admin = _admin
    self.reward_policy_maker = _reward_policy_maker
    self.controller = controller
    self.voting_escrow = Controller(controller).voting_escrow()

    self.period_timestamp[0] = block.timestamp
    self.veboost_proxy = _veboost_proxy


@view
@external
def integrate_checkpoint() -> uint256:
    return self.period_timestamp[self.period]


@internal
def _update_liquidity_limit(addr: address, l: uint256, L: uint256):
    """
    @notice Calculate limits which depend on the amount of HND token per-user.
            Effectively it calculates working balances to apply amplification
            of HND production by HND
    @param addr User address
    @param l User's amount of liquidity (LP tokens)
    @param L Total amount of liquidity (LP tokens)
    """
    # To be called after totalSupply is updated
    voting_balance: uint256 = VotingEscrowBoost(self.veboost_proxy).adjusted_balance_of(addr)
    voting_total: uint256 = ERC20(self.voting_escrow).totalSupply()

    lim: uint256 = l * TOKENLESS_PRODUCTION / 100
    if voting_total > 0:
        lim += L * voting_balance / voting_total * (100 - TOKENLESS_PRODUCTION) / 100

    lim = min(l, lim)
    old_bal: uint256 = self.working_balances[addr]
    self.working_balances[addr] = lim
    _working_supply: uint256 = self.working_supply + lim - old_bal
    self.working_supply = _working_supply

    log UpdateLiquidityLimit(addr, l, L, lim, _working_supply)


@internal
def _checkpoint_token(addr: address, token: address, period: int128, period_time: uint256):
    """
    @notice Checkpoint for a user
    @param addr User address
    @param token Reward token
    @param period Reward period id
    @param period_time Reward period timestamp
    """
    _integrate_inv_supply: uint256 = self.integrate_inv_supply[token][period]

    _epoch: uint256 = RewardPolicyMaker(self.reward_policy_maker).epoch_at(block.timestamp)

    # Update integral of 1/supply
    if block.timestamp > period_time and not self.is_killed:
        _working_supply: uint256 = self.working_supply
        _controller: address = self.controller

        prev_week_time: uint256 = period_time

        for i in range(500):
            _epoch = RewardPolicyMaker(self.reward_policy_maker).epoch_at(prev_week_time)
            week_time: uint256 = RewardPolicyMaker(self.reward_policy_maker).epoch_start_time(_epoch + 1)
            week_time = min(week_time, block.timestamp)

            dt: uint256 = week_time - prev_week_time
            w: uint256 = Controller(_controller).gauge_relative_weight(self, prev_week_time / WEEK * WEEK)

            if _working_supply > 0:
                _integrate_inv_supply += RewardPolicyMaker(self.reward_policy_maker).rate_at(prev_week_time, token) * w * dt / _working_supply
                # On precisions of the calculation
                # rate ~= 10e18
                # last_weight > 0.01 * 1e18 = 1e16 (if pool weight is 1%)
                # _working_supply ~= TVL * 1e18 ~= 1e26 ($100M for example)
                # The largest loss is at dt = 1
                # Loss is 1e-9 - acceptable

            if week_time == block.timestamp:
                break

            prev_week_time = week_time

    self.integrate_inv_supply[token][period + 1] = _integrate_inv_supply

    # Update user-specific integrals
    _working_balance: uint256 = self.working_balances[addr]
    self.integrate_fraction[token][addr] += _working_balance * (_integrate_inv_supply - self.integrate_inv_supply_of[token][addr]) / 10 ** 18
    self.integrate_inv_supply_of[token][addr] = _integrate_inv_supply


@internal
def _checkpoint(addr: address):
    _token_count: uint256 = Minter(self.minter).token_count()
    _period: int128 = self.period
    _period_time: uint256 = self.period_timestamp[_period]

    if _period_time == 0:
        _epoch: uint256 = RewardPolicyMaker(self.reward_policy_maker).epoch_at(block.timestamp)
        _period_time = RewardPolicyMaker(self.reward_policy_maker).epoch_start_time(_epoch)

    if block.timestamp > _period_time and not self.is_killed:
        _controller: address = self.controller
        Controller(_controller).checkpoint_gauge(self)

    for i in range(MAX_TOKENS):
        if i == _token_count:
            break
        self._checkpoint_token(addr, Minter(self.minter).tokens(i), _period, _period_time)

    _period += 1
    self.period = _period
    self.period_timestamp[_period] = block.timestamp
    self.integrate_checkpoint_of[addr] = block.timestamp


@external
def user_checkpoint(addr: address) -> bool:
    """
    @notice Record a checkpoint for `addr`
    @param addr User address
    @return bool success
    """
    assert (msg.sender == addr) or (msg.sender == self.minter)  # dev: unauthorized
    self._checkpoint(addr)
    self._update_liquidity_limit(addr, self.balanceOf[addr], self.totalSupply)
    return True


@external
def claimable_tokens(addr: address, token: address) -> uint256:
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)
    return self.integrate_fraction[token][addr] - Minter(self.minter).minted(addr, self, token)


@external
def kick(addr: address):
    """
    @notice Kick `addr` for abusing their boost
    @dev Only if either they had another voting event, or their voting escrow lock expired
    @param addr Address to kick
    """
    _voting_escrow: address = self.voting_escrow
    t_last: uint256 = self.integrate_checkpoint_of[addr]
    t_ve: uint256 = VotingEscrow(_voting_escrow).user_last_checkpoint_ts(addr)
    _balance: uint256 = self.balanceOf[addr]

    assert ERC20(_voting_escrow).balanceOf(addr) == 0 or t_ve > t_last # dev: kick not allowed
    assert self.working_balances[addr] > _balance * TOKENLESS_PRODUCTION / 100  # dev: kick not needed

    self._checkpoint(addr)
    self._update_liquidity_limit(addr, _balance, self.totalSupply)


@external
@nonreentrant('lock')
def deposit(_value: uint256, _addr: address = msg.sender):
    """
    @notice Deposit `_value` LP tokens
    @param _value Number of tokens to deposit
    @param _addr Address to deposit for
    """

    self._checkpoint(_addr)

    if _value != 0:
        total_supply: uint256 = self.totalSupply

        total_supply += _value
        new_balance: uint256 = self.balanceOf[_addr] + _value
        self.balanceOf[_addr] = new_balance
        self.totalSupply = total_supply

        self._update_liquidity_limit(_addr, new_balance, total_supply)

        assert ERC20(self.lp_token).transferFrom(msg.sender, self, _value)

    log Deposit(_addr, _value)
    log Transfer(ZERO_ADDRESS, _addr, _value)


@external
@nonreentrant('lock')
def withdraw(_value: uint256):
    """
    @notice Withdraw `_value` LP tokens
    @param _value Number of tokens to withdraw
    """
    self._checkpoint(msg.sender)

    if _value != 0:
        total_supply: uint256 = self.totalSupply

        total_supply -= _value
        new_balance: uint256 = self.balanceOf[msg.sender] - _value
        self.balanceOf[msg.sender] = new_balance
        self.totalSupply = total_supply

        self._update_liquidity_limit(msg.sender, new_balance, total_supply)

        ERC20(self.lp_token).transfer(msg.sender, _value)

    log Withdraw(msg.sender, _value)
    log Transfer(msg.sender, ZERO_ADDRESS, _value)


@external
@nonreentrant('lock')
def emergency_withdraw():
    """
    @notice Withdraw all user LP tokens
    """
    total_supply: uint256 = self.totalSupply
    user_balance: uint256 = self.balanceOf[msg.sender]

    assert user_balance > 0  # nothing to withdraw

    total_supply -= user_balance
    self.balanceOf[msg.sender] = 0
    self.totalSupply = total_supply

    self._update_liquidity_limit(msg.sender, 0, total_supply)

    ERC20(self.lp_token).transfer(msg.sender, user_balance)

    log EmergencyWithdraw(msg.sender, user_balance)
    log Transfer(msg.sender, ZERO_ADDRESS, user_balance)


@internal
def _transfer(_from: address, _to: address, _value: uint256):
    self._checkpoint(_from)
    self._checkpoint(_to)

    if _value != 0:
        total_supply: uint256 = self.totalSupply
        new_balance: uint256 = self.balanceOf[_from] - _value
        self.balanceOf[_from] = new_balance
        self._update_liquidity_limit(_from, new_balance, total_supply)

        new_balance = self.balanceOf[_to] + _value
        self.balanceOf[_to] = new_balance
        self._update_liquidity_limit(_to, new_balance, total_supply)

    log Transfer(_from, _to, _value)


@external
@nonreentrant('lock')
def transfer(_to : address, _value : uint256) -> bool:
    """
    @notice Transfer token for a specified address
    @dev Transferring claims pending reward tokens for the sender and receiver
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    """
    self._transfer(msg.sender, _to, _value)

    return True


@external
@nonreentrant('lock')
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
     @notice Transfer tokens from one address to another.
     @dev Transferring claims pending reward tokens for the sender and receiver
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
    """
    _allowance: uint256 = self.allowance[_from][msg.sender]
    if _allowance != MAX_UINT256:
        self.allowance[_from][msg.sender] = _allowance - _value

    self._transfer(_from, _to, _value)

    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    """
    @notice Approve the passed address to transfer the specified amount of
            tokens on behalf of msg.sender
    @dev Beware that changing an allowance via this method brings the risk
         that someone may use both the old and new allowance by unfortunate
         transaction ordering. This may be mitigated with the use of
         {incraseAllowance} and {decreaseAllowance}.
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will transfer the funds
    @param _value The amount of tokens that may be transferred
    @return bool success
    """
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)

    return True


@external
def increaseAllowance(_spender: address, _added_value: uint256) -> bool:
    """
    @notice Increase the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _added_value The amount of to increase the allowance
    @return bool success
    """
    allowance: uint256 = self.allowance[msg.sender][_spender] + _added_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)

    return True


@external
def decreaseAllowance(_spender: address, _subtracted_value: uint256) -> bool:
    """
    @notice Decrease the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _subtracted_value The amount of to decrease the allowance
    @return bool success
    """
    allowance: uint256 = self.allowance[msg.sender][_spender] - _subtracted_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)

    return True


@external
def set_killed(_is_killed: bool):
    """
    @notice Set the killed status for this contract
    @dev When killed, the gauge always yields a rate of 0 and so cannot mint CRV
    @param _is_killed Killed status to set
    """
    assert msg.sender == self.admin

    self.is_killed = _is_killed


@external
def commit_transfer_ownership(addr: address):
    """
    @notice Transfer ownership of GaugeController to `addr`
    @param addr Address to have ownership transferred to
    """
    assert msg.sender == self.admin  # dev: admin only

    self.future_admin = addr
    log CommitOwnership(addr)


@external
def accept_transfer_ownership():
    """
    @notice Accept a pending ownership transfer
    """
    _admin: address = self.future_admin
    assert msg.sender == _admin  # dev: future admin only

    self.admin = _admin
    log ApplyOwnership(_admin)