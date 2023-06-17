// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Billy {
    address public target;
    bool public success;
    bytes returndata;
    address public owner;

    constructor(address _target)
    {
        target = _target;
    }

    function setTarget(address newTarget) public
    {
        target = newTarget;
    }

    function attackWithOutParams(string memory functionName) public  returns (bool,bytes memory) {
            (success,returndata) = target.call(abi.encodeWithSignature(functionName));

          return (success,returndata);
    }

    function attackStaticCall() public returns (bool,bytes memory) {

          (success, returndata) = target.staticcall(hex"f851a440");

          return (success,returndata);
    }
}