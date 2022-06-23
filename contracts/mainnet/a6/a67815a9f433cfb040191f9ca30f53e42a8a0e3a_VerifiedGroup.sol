// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IVerifiedGroupFactory.sol";
import "./ChildBase.sol";
import "./AddressSet.sol";
using AddressSet for AddressSet.Set;

/*{
  "name": "Group",
  "overview": {
    "registeredCount": {},
    "isRegistered": { "args": ["account"] }
  },
  "methods": {
    "setText": {
      "onlyAllowed": true
    },
    "setName": {
      "onlyAllowed": true
    },
    "allowContract": {
      "onlyAllowed": true,
      "fields": [
        { "hint": "Anything",
          "select": [ "Factories", "Children" ] }
      ]
    },
    "disallowContract": {
      "onlyAllowed": true,
      "fields": [
        { "select": [ "Allowed" ] }
      ]
    },
    "register": {
      "onlyAllowed": true
    },
    "unregister": {
      "onlyAllowed": true
    },
    "ban": {
      "onlyAllowed": true,
      "fields": [
        {},
        { "preview": "timestamp" }
      ]
    },
    "setVerifications": {
      "onlyAllowed": true
    }
  },
  "display": {
    "Allowed": {},
    "FactoryBrowser": {},
    "Swap": {}
  }
}*/
contract VerifiedGroup is ChildBase {
  IVerification public verifications;
  address public factory;
  uint public registeredCount;
  mapping(address => uint) public joinedTimestamps;
  mapping(bytes32 => uint) public activeBans;
  AddressSet.Set allowedContracts;
  mapping(address => bytes4) public registrationHooks;
  mapping(address => bytes4) public unregistrationHooks;
  AddressSet.Set registrationHookSet;
  AddressSet.Set unregistrationHookSet;
  struct Comment {
    address author;
    uint timestamp;
    string text;
  }
  mapping(address => Comment[]) public comments;

  event NewComment(address indexed item, string text);
  event VerificationContractChanged(address indexed oldContract, address indexed newContract);
  event Registration(address indexed account);
  event Unregistered(address indexed account);
  event AccountBanned(address indexed account, uint banExpirationTimestamp, bytes32 idHash);
  event TxSent(address to, bytes data, bytes returned);
  event ContractAllowed(address indexed contractAddress);
  event ContractDisallowed(address indexed contractAddress);
  event ContractOnAllowInvoked(address indexed contractAddress, bytes returned);
  event RegisterHookSuccess(address indexed contractAddress, address indexed account);
  event RegisterHookFailure(address indexed contractAddress, address indexed account);
  event UnregisterHookSuccess(address indexed contractAddress, address indexed account);
  event UnregisterHookFailure(address indexed contractAddress, address indexed account);

  constructor(
    address _meta,
    address _verifications,
    address _firstAccount,
    address _factory,
    string memory _name
  ) ChildBase(
    _meta,
    address(this),
    _name
  ){
    require(_verifications != address(0), 'Verifications cannot be 0 address');
    verifications = IVerification(_verifications);
    factory = _factory;

    allowedContracts.insert(address(this));

    // Contract creator becomes first member automatically
    // in order to prevent any bots from taking over before it can start
    register(_firstAccount);
  }

  // General use view functions
  function isVerified(address account) public view returns(bool) {
    return verifications.addressActive(account);
  }

  function isRegistered(address account) public view returns(bool) {
    return joinedTimestamps[account] > 0;
  }

  function contractAllowed(address key) public view returns(bool) {
    // Admin mode when only one user
    if(registeredCount == 0) return true;
    if(registeredCount == 1 && isRegistered(key)) return true;
    return allowedContracts.exists(key);
  }

  function allowedContractCount() external view returns(uint) {
    return allowedContracts.count();
  }

  function allowedContractIndex(uint index) external view returns(address) {
    return allowedContracts.keyList[index];
  }

  function commentCount(address item) external view returns(uint) {
    return comments[item].length;
  }

  // Cannot use auto-getter from public comments mapping due to variable-length strings
  function getComment(address item, uint index) external view returns(Comment memory) {
    return comments[item][index];
  }

  // Functions that can be invoked by members
  function postComment(address item, string memory text) external {
    require(isVerified(msg.sender), 'Not Verified');
    require(isRegistered(msg.sender), 'Not Registered');
    comments[item].push(Comment(msg.sender, block.timestamp, text));
    emit NewComment(item, text);
  }

  // Functions that can be invoked by allowed contracts
  function register(address account) public onlyAllowed {
    require(isVerified(account), 'Not Verified');
    require(!isRegistered(account), 'Already Registered');
    bytes32 idHash = verifications.addressIdHash(account);
    require(activeBans[idHash] <= block.timestamp, 'Account Banned');
    joinedTimestamps[account] = block.timestamp;
    registeredCount++;
    emit Registration(account);

    for(uint i = 0; i < registrationHookSet.count(); i++) {
      address hookContract = registrationHookSet.keyList[i];
      (bool success,) = hookContract.call(abi.encodeWithSelector(
        registrationHooks[hookContract], account));
      if(success) {
        emit RegisterHookSuccess(hookContract, account);
      } else {
        emit RegisterHookFailure(hookContract, account);
      }
    }
  }

  function unregister(address account) public onlyAllowed {
    require(isRegistered(account), 'Not Registered');
    delete joinedTimestamps[account];
    registeredCount--;
    emit Unregistered(account);

    for(uint i = 0; i < unregistrationHookSet.count(); i++) {
      address hookContract = unregistrationHookSet.keyList[i];
      (bool success,) = hookContract.call(abi.encodeWithSelector(
        unregistrationHooks[hookContract], account));
      if(success) {
        emit UnregisterHookSuccess(hookContract, account);
      } else {
        emit UnregisterHookFailure(hookContract, account);
      }
    }
  }

  function ban(address account, uint banExpirationTimestamp) external onlyAllowed {
    unregister(account);
    bytes32 idHash = verifications.addressIdHash(account);
    activeBans[idHash] = banExpirationTimestamp;
    emit AccountBanned(account, banExpirationTimestamp, idHash);
  }

  function setVerifications(address _verifications) external onlyAllowed {
    require(_verifications != address(0), 'Verifications cannot be 0 address');
    emit VerificationContractChanged(address(verifications), _verifications);
    verifications = IVerification(_verifications);
  }

  function allowContract(address contractToAllow) external onlyAllowed {
    allowedContracts.insert(contractToAllow);
    emit ContractAllowed(contractToAllow);
    // Call onAllow() if it's available
    (bool success, bytes memory data) =
      contractToAllow.call(abi.encodePacked(uint32(0x9ce690cf)));
    if(success) {
      emit ContractOnAllowInvoked(contractToAllow, data);
    }
  }

  // Intended to be invoked from a child contract's onAllow() function
  // The selector will be called with one argument: address of account
  function hookRegister(bytes4 selector) public onlyAllowed {
    registrationHooks[msg.sender] = selector;
    registrationHookSet.insert(msg.sender);
  }

  // Intended to be invoked from a child contract's onAllow() function
  // The selector will be called with one argument: address of account
  function hookUnregister(bytes4 selector) public onlyAllowed {
    unregistrationHooks[msg.sender] = selector;
    unregistrationHookSet.insert(msg.sender);
  }

  function disallowContract(address contractToDisallow) external onlyAllowed {
    allowedContracts.remove(contractToDisallow);
    emit ContractDisallowed(contractToDisallow);
    // Remove lifecyle hooks
    if(registrationHookSet.exists(contractToDisallow)) {
      delete registrationHooks[contractToDisallow];
      registrationHookSet.remove(contractToDisallow);
    }
    if(unregistrationHookSet.exists(contractToDisallow)) {
      delete unregistrationHooks[contractToDisallow];
      unregistrationHookSet.remove(contractToDisallow);
    }
  }

  function invokeMany(bytes[] memory data) external onlyAllowed {
    IVerifiedGroupFactory origin = IVerifiedGroupFactory(factory);
    uint startChildCount = origin.childCount(address(this));
    for(uint d = 0; d < data.length; d++) {
      (address to, bytes memory txData) = IInvokeRewriter(origin.rewriter()).rewrite(data[d], factory, address(this), startChildCount);
      (bool success, bytes memory returned) = to.call(txData);
      emit TxSent(to, txData, returned);
      require(success, 'Invoke Failed');
    }
  }

  modifier onlyAllowed() {
    require(contractAllowed(msg.sender), 'Invalid Caller');
    _;
  }

}

interface IVerification {
  function addressActive(address toCheck) external view returns (bool);
  function addressExpiration(address toCheck) external view returns (uint);
  function addressIdHash(address toCheck) external view returns(bytes32);
}

interface IInvokeRewriter {
  function rewrite(bytes memory data, address parentFactory, address group, uint startChildCount) external view returns(address, bytes memory);
}