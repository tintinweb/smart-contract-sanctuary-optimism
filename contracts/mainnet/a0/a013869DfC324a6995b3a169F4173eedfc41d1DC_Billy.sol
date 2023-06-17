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

    function getProxyAdmin(address proxy) public view virtual returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("admin()")) == 0xf851a440
        (bool success, bytes memory returnData) = proxy.staticcall(hex"f851a440");
        require(success);
        return abi.decode(returnData, (address));
    }
}