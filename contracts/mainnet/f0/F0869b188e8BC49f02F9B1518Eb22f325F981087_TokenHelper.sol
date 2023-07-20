/*

    Copyright 2023 31Third B.V.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache-2.0

*/

/*
    Helper contract for API! Provides batch call functionality to improve performance. Not used in trading contracts.
    NO AUDIT REQUIRED!
*/
pragma solidity 0.8.16;

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);

  function decimals() external view returns (uint8);

  function allowance(address owner, address spender) external view returns (uint256);
}

contract TokenHelper {
  // ETH pseudo-token address
  address private constant ETH_ADDRESS =
  0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /**
   * Loads eth balances of given owner addresses
   *
   * @param _owners List of owners to load balances for
   */
  function ethBalances(address[] calldata _owners) external view returns (uint256[] memory balances) {
    balances = new uint256[](_owners.length);
    for (uint256 i = 0; i < _owners.length; i++) {
      balances[i] = _owners[i].balance;
    }
  }

  /**
   * Loads token balances of given owner addresses
   *
   * @param _token Address of token to load balances for
   * @param _owners List of owners to load balances for
   */
  function erc20Balances(address _token, address[] calldata _owners) external view returns (uint256[] memory balances) {
    ERC20 erc20 = ERC20(_token);
    balances = new uint256[](_owners.length);
    for (uint256 i = 0; i < _owners.length; i++) {
      balances[i] = erc20.balanceOf(_owners[i]);
    }
  }

  /**
   * Loads tokens balances of given owner and token addresses
   *
   * @param _owners List of owners to load balances for
   * @param _tokens List of tokens to load balances for
   */
  function tokenBalances(address[] calldata _owners, address[] calldata _tokens) external view returns (uint256[][] memory balances) {
    balances = new uint256[][](_owners.length);
    for (uint256 i = 0; i < _owners.length; i++) {
      balances[i] = new uint256[](_tokens.length);
      for (uint256 j = 0; j < _tokens.length; j++) {
        if (_tokens[j] == ETH_ADDRESS) {
          balances[i][j] = _owners[i].balance;
        } else {
          ERC20 erc20 = ERC20(_tokens[j]);
          balances[i][j] = erc20.balanceOf(_owners[i]);
        }
      }
    }
  }

  /**
   * Loads decimals of given token addresses
   *
   * @param _tokens List of tokens to load decimals for
   */
  function tokenDecimals(address[] calldata _tokens) external view returns (uint8[] memory decimals) {
    decimals = new uint8[](_tokens.length);
    for (uint256 i = 0; i < _tokens.length; i++) {
      if (_tokens[i] == ETH_ADDRESS) {
        decimals[i] = 18;
      } else {
        ERC20 erc20 = ERC20(_tokens[i]);
        decimals[i] = erc20.decimals();
      }
    }
  }

  /**
   * Loads allowances of spender for owners given token addresses
   *
   * @param _owner   Owner of the tokens
   * @param _spender Spender to load allowances for
   * @param _tokens  List of tokens to load allowances for
   */
  function tokenAllowances(address _owner, address _spender, address[] calldata _tokens) external view returns (uint256[] memory approvals) {
    approvals = new uint256[](_tokens.length);
    for (uint256 i = 0; i < _tokens.length; i++) {
      if (_tokens[i] == ETH_ADDRESS) {
        approvals[i] = 2**256 - 1; // max value
      } else {
        ERC20 erc20 = ERC20(_tokens[i]);
        approvals[i] = erc20.allowance(_owner, _spender);
      }
    }
  }
}