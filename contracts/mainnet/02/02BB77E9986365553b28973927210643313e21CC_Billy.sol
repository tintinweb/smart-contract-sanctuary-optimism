// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Billy {
    constructor() {}

    function attackStaticCall(address target) public view virtual returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.staticcall(
            abi.encode(bytes4(keccak256("admin()")))
        );
        return (success, returnData);
    }

    function attackStaticCall2(address target) public view virtual returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.staticcall(
            abi.encode(bytes32(keccak256("admin()")))
        );
        return (success, returnData);
    }

    function attackStaticCallSc(address target, string memory sc) public view virtual returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.staticcall(
            abi.encode(bytes4(keccak256(bytes(sc))))
        );
        return (success, returnData);
    }


    function getFunctionSelector(string calldata functionSignature) external pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked(functionSignature)));
    }

    function attackStaticCallArg1(address target, bytes4 selector, address arg1) public view virtual returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.staticcall(
            abi.encodeWithSelector(selector, arg1)
        );
        return (success, returnData);
    }

}