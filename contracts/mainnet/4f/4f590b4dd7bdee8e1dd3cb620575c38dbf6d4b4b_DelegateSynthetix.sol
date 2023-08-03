// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Synthetix} from "./interface/Synthetix.sol";
import {FeePool} from "./interface/FeePool.sol";
import {AddressResolver} from "./interface/AddressResolver.sol";
import {ERC20} from "./interface/ERC20.sol";

//import "hardhat/console.sol";

contract DelegateSynthetix {
    bytes32 private constant FEEPOOL_NAME = "FeePool";
    Synthetix private immutable synthetix;
    AddressResolver private immutable addressResolver;
    ERC20 private immutable sUSD;

    constructor(
        address proxySynthetixAddress,
        address sUSDAddress,
        address addressresolverAddress
    ) {
        // in Synthetix this is referenced as `ProxyERC20` however it is unlikely to changed so not need for `AddressResolver`
        synthetix = Synthetix(proxySynthetixAddress);
        sUSD = ERC20(sUSDAddress);
        addressResolver = AddressResolver(addressresolverAddress);
    }

    fallback(bytes calldata input) external returns (bytes memory output) {
        bytes1 sig = bytes1(input[:1]);
        // mint max
        address delegator = msg.sender;
        if (sig == 0x00) {
            synthetix.issueMaxSynthsOnBehalf(delegator);
        }
        // burn to target and claim
        else if (sig == 0x01) {
            FeePool feePool = FeePool(addressResolver.getAddress(FEEPOOL_NAME));
            synthetix.burnSynthsToTargetOnBehalf(delegator);
            feePool.claimOnBehalf(delegator);
        }
        // claim only
        else if (sig == 0x02) {
            FeePool feePool = FeePool(addressResolver.getAddress(FEEPOOL_NAME));
            feePool.claimOnBehalf(delegator);
        }
        // burn max/to X
        else if (sig == 0x03) {
            uint256 balance = 0;
            if (input.length == 1) {
                balance = sUSD.balanceOf(delegator);
                synthetix.burnSynthsOnBehalf(delegator, balance);
            } else {
                // copied from 0xngmi llamazip
                uint256 data = uint256(bytes32(input[1:]));
                // 1 byte for zeroes
                //console.logBytes(input[1:]);
                uint256 zeroes = (data & 0xff << (256 - 8)) >> (256 - 8);
                uint256 calldataLength = input.length - 1;
                uint256 inputBits = (data & (type(uint256).max >> 8)) >>
                    (256 - (calldataLength * 8));
                balance = inputBits * (10 ** zeroes);
                //console.log(zeroes, inputBits, balance);
                synthetix.burnSynthsOnBehalf(delegator, balance);
            }
        }
        // mint to X
        else if (sig == 0x04) {
            uint256 balance = 0;
            // copied from 0xngmi llamazip
            uint256 data = uint256(bytes32(input[1:]));
            // 1 byte for zeroes
            uint256 zeroes = (data & 0xff << (256 - 8)) >> (256 - 8);
            uint256 calldataLength = input.length - 1;
            uint256 inputBits = (data & (type(uint256).max >> 8)) >>
                    (256 - (calldataLength * 8));
                balance = inputBits * (10 ** zeroes);
            synthetix.issueSynthsOnBehalf(delegator, balance);
        }
        // burn to target only
        else if (sig == 0x05) {
            synthetix.burnSynthsToTargetOnBehalf(delegator);
        }
        // silencing unused variable
        output = bytes.concat(bytes1(0x01));
    }
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

interface AddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

interface ERC20 {
    function balanceOf(address _owner) external view returns (uint256);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

interface FeePool {
    function claimOnBehalf(address claimingForAddress) external returns (bool);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;
interface Synthetix {
    function burnSynthsOnBehalf(address burnForAddress, uint amount) external;

    function burnSynthsToTargetOnBehalf(address burnForAddress) external;

    function issueMaxSynthsOnBehalf(address issueForAddress) external;

    function issueSynthsOnBehalf(address issueForAddress, uint amount) external;
}