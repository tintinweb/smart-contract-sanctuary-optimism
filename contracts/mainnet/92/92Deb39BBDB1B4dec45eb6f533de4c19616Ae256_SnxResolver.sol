// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IFeePool {
  function feesAvailable(address account)
    external
    view
    returns (uint256, uint256);

  function isFeesClaimable(address account) external view returns (bool);

  function claimOnBehalf(address claimingForAddress) external returns (bool);
}

interface IDelegateApprovals {
  function canClaimFor(address authoriser, address delegate)
    external
    view
    returns (bool);
}

interface IProxy {
  function target() external view returns (address);
}

contract SnxResolver {
  address public constant OPS =
    address(0x340759c8346A1E6Ed92035FB8B6ec57cE1D82c2c);
  address public constant APPROVALS =
    address(0x2A23bc0EA97A89abD91214E8e4d20F02Fe14743f);
  address public constant FEE_POOL_PROXY =
    address(0x4a16A42407AA491564643E1dfc1fd50af29794eF);

  function checker(address _account)
    external
    view
    returns (bool, bytes memory execPayload)
  {
    IFeePool feePool = IFeePool(IProxy(FEE_POOL_PROXY).target());
    IDelegateApprovals approvals = IDelegateApprovals(APPROVALS);

    (uint256 totalFees, uint256 totalRewards) = feePool.feesAvailable(_account);
    if (totalFees == 0 && totalRewards == 0) {
      execPayload = bytes("No fees to claim");
      return (false, execPayload);
    }

    if (!feePool.isFeesClaimable(_account)) {
      execPayload = bytes("Not claimable, cRatio too low");
      return (false, execPayload);
    }

    if (!approvals.canClaimFor(_account, OPS)) {
      execPayload = bytes("Not approved for claiming");
      return (false, execPayload);
    }

    execPayload = abi.encodeWithSelector(
      feePool.claimOnBehalf.selector,
      _account
    );

    return (true, execPayload);
  }
}