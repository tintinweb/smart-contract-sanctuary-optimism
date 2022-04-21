/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-21
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title TheDiff
 * @dev Retrieve virtually the best diff ever
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract TheDiff {

    string theDiff = "https://arweave.net/R5VjN9UOc1llzmvOYvymFmDexZmIxIkzz9n5CvyVAd8";

    /**
     * @dev Still 42... 
     * @return how long is a piece of a string?
     */
    function retrieve() public view returns (string memory){
        return theDiff;
    }
}