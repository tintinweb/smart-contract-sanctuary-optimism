// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IFeePool {
  function feesAvailable(address account)
    external
    view
    returns (uint256, uint256);

  function isFeesClaimable(address account) external view returns (bool);

  function claimOnBehalf(address claimingForAddress) external returns (bool);
}

interface IMintableSynthetix {
  function burnSynthsToTargetOnBehalf(address burnForAddress) external;

  function burnSynthsToTarget() external;
}

interface IDelegateApprovals {
  function canClaimFor(address authoriser, address delegate)
    external
    view
    returns (bool);

  function canBurnFor(address authoriser, address delegate)
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
  address public constant MINTABLE_SNX_PROXY =
    address(0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4);

  IProxy private immutable feePoolProxy;
  IProxy private immutable mintableSnxProxy;
  IDelegateApprovals private immutable approvals;

  modifier onlyOps() {
    require(msg.sender == OPS, "SnxResolver: Only Ops");
    _;
  }

  constructor() {
    feePoolProxy = IProxy(FEE_POOL_PROXY);
    mintableSnxProxy = IProxy(MINTABLE_SNX_PROXY);
    approvals = IDelegateApprovals(APPROVALS);
  }

  function burnAndClaim(address _account) external {
    _burnIfNeeded(_account);

    _claim(_account);
  }

  function claim(address _account) external {
    _claim(_account);
  }

  function _burnIfNeeded(address _account) private {
    // Burn if c-ratio is too low to claim
    if (!_feePool().isFeesClaimable(_account)) {
      require(
        approvals.canBurnFor(_account, address(this)),
        "SnxResolver: Cant burn for"
      );

      _mintableSnx().burnSynthsToTargetOnBehalf(_account);
    }
  }

  function _claim(address _account) private {
    require(
      approvals.canClaimFor(_account, address(this)),
      "SnxResolver: Cant claim for"
    );

    (uint256 totalFees, uint256 totalRewards) = _feePool().feesAvailable(
      _account
    );
    require(totalFees > 0 || totalRewards > 0, "SnxResolver: No fees to claim");

    _feePool().claimOnBehalf(_account);
  }

  function _feePool() private view returns (IFeePool) {
    return IFeePool(feePoolProxy.target());
  }

  function _mintableSnx() private view returns (IMintableSynthetix) {
    return IMintableSynthetix(mintableSnxProxy.target());
  }
}