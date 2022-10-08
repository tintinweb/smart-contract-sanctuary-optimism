# @version 0.3.7
"""
@title L2 Optimism Governance Proxy
"""


interface CrossDomainMessenger:
    def xDomainMessageSender() -> address: view


enum AdminType:
    OWNERSHIP
    PARAMETER
    EMERGENCY


admin: public(AdminType)


CROSS_DOMAIN_MESSENGER: constant(address) = 0x4200000000000000000000000000000000000007
MAXSIZE: constant(uint256) = 2**16 - 1


@external
def receive_message(_admin_type: AdminType, _target: address, _message: Bytes[MAXSIZE]):
    assert msg.sender == CROSS_DOMAIN_MESSENGER
    assert CrossDomainMessenger(msg.sender).xDomainMessageSender() == self

    self.admin = _admin_type
    raw_call(_target, _message)
    self.admin = empty(AdminType)