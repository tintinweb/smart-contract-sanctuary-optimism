/**
 *Submitted for verification at optimistic.etherscan.io on 2022-07-07
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

contract MockContract {
  struct CreditLimit {
    address user; // The whitelisted user address to set credit limit.
    address token; // The token address to set credit limit.
    uint limit; // The maximum token amount that can be borrowed (interest included).
    address origin; // The tx origin of whitelisted user (using for whitelistContractWithTxOrigin).
  }

  struct TokenFactors {
    uint16 borrowFactor; // The borrow factor for this token, multiplied by 1e4.
    uint16 collateralFactor; // The collateral factor for this token, multiplied by 1e4.
    uint16 liqIncentive; // The liquidation incentive, multiplied by 1e4.
  }

  function setPendingGovernor(address _newGovernor) external {}

  function acceptGovernor() external {}

  function setAllowContractCalls(bool _ok) external {}

  function setExec(address _exec) external {}

  function setWhitelistSpells(address[] calldata _spells, bool[] calldata _statuses) external {}

  function setWhitelistTokens(address[] calldata _tokens, bool[] calldata _statuses) external {}

  function setWhitelistUsers(address[] calldata _users, bool[] calldata _statuses) external {}

  function setWhitelistContractWithTxOrigin(
    address[] calldata _contracts,
    address[] calldata _origins,
    bool[] calldata _statuses
  ) external {}

  function setWorker(address _worker) external {}

  function addBank(address _token, address _cToken) external {}

  function setOracle(address _oracle) external {}

  function setFeeBps(uint _feeBps) external {}

  function setCreditLimits(CreditLimit[] calldata _creditLimits) external {}

  function setWhitelistLPTokens(address[] calldata _lpTokens, bool[] calldata _statuses) external {}

  function setPrimarySources(
    address _token,
    uint _maxPriceDeviation,
    address[] memory _sources
  ) external {}

  function setMultiPrimarySources(
    address[] memory _tokens,
    uint[] memory _maxPriceDeviationList,
    address[][] memory _allSources
  ) external {}

  function setSymbols(address[] memory _tokens, string[] memory _syms) external {}

  function setRef(address _ref) external {}

  function setMaxDelayTimes(address[] calldata _tokens, uint[] calldata _maxDelays) external {}

  function setRefsETH(address[] calldata _tokens, address[] calldata _refs) external {}

  function setRefsUSD(address[] calldata _tokens, address[] calldata _refs) external {}

  function setRefETHUSD(address _refETHUSD) external {}

  function setRoute(address[] calldata _tokens, address[] calldata _targets) external {}

  function setTokenFactors(address[] memory tokens, TokenFactors[] memory _tokenFactors) external {}

  function unsetTokenFactors(address[] memory tokens) external {}

  function setWhitelistERC1155(address[] memory tokens, bool ok) external {}

  function setFlagUniV3Pool(address[] memory pools, bool ok) external {}

  function setRedirects(address[] calldata routes, address[] calldata newRoutes) external {}
}