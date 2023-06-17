// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Billy {
    address public target;
    address public owner;

    constructor(address _target)
    {
        target = _target;
    }

    function setTarget(address newTarget) public
    {
        target = newTarget;
    }

    function attackWithOutParams(string memory functionName) public returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.call(abi.encodeWithSignature(functionName));
        return (success, returnData);
    }

    function attackStaticCall(string memory functionAddress) public returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.staticcall(hex"f851a440");
        return (success, returnData);
    }


    function staticCallFunctionDirectly() public view returns (bytes memory, bool) {
        (bool success, bytes memory returnData) = target.staticcall(
        // abi.encodeWithSignature(hex"f851a440")
            hex"f851a440"
        );
        return (returnData, success);
    }
}