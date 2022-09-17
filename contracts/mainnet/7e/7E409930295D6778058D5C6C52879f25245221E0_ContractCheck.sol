// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract ContractCheck {

    // Certificate of the contract
    struct Certificate {
        bytes32 cid;
        string name;
        address contractAddress;
        address owner;
        uint256 chainId;
        address[] validators;
        bool valid;
        uint256 creationTime;
    }

    bytes32[] public certificatesIds;
    mapping (bytes32 => Certificate) public certificateRegistry;
    mapping (address => bytes32[]) public userValidatedCertificateIds;
    mapping (address => bytes32[]) public contractAddressToCertificateIds;
    mapping (bytes32 => mapping(address => bool)) public isValidator;

    // Events
    event NewCertificateCreated(bytes32 indexed certificateId, address indexed contractAddress, address indexed owner, string name);
    event Validated(bytes32 indexed certificateId, address indexed validator, address indexed contractAddress);
    event CertificateModified(bytes32 indexed certificateId, address indexed contractAddress, address indexed owner, string name);

    /**
     * newCertificate : creates a new certificate
     * @param _name The name/description of the contract
     * @param _contractAddress The contract address for which the certificate is created
     * @param _chainId The chain id of the network where the contract is deployed
    */
    function newCertificate(string memory _name, address _contractAddress, uint256 _chainId) public {
        bytes32 cid = _hash(_name, _contractAddress, msg.sender, _chainId);
        Certificate memory nc = Certificate(cid, _name, _contractAddress, msg.sender, _chainId, new address[](0), true, block.timestamp);
        // check that the certificate does not exist
        require(certificateRegistry[cid].contractAddress == address(0), "Certificate already exists");
        certificateRegistry[cid] = nc;
        certificatesIds.push(cid);
        contractAddressToCertificateIds[_contractAddress].push(cid);
        emit NewCertificateCreated(cid, _contractAddress, msg.sender, _name);
    }

    /**
     * batchValidate : validate a list of certificates
     * @param _certificateIds The certificate ids to validate
    */
    function batchValidate(bytes32[] memory _certificateIds) public {
        for (uint i = 0; i < _certificateIds.length; i++) {
            _validate(_certificateIds[i]);
        }
    }

    /**
     * removeValidity : creates a new certificate
     * @param _certificateId The certificate ids to remove validity
    */
    function removeValidity(bytes32 _certificateId) public {
        require(certificateRegistry[_certificateId].owner == msg.sender, "Only the owner can remove the validity");
        certificateRegistry[_certificateId].valid = false;
    }

    // Internal functions

    /**
     * _validate : creates a new certificate
     * @param _certificateId The certificate id to validate
    */
    function _validate(bytes32 _certificateId) public {
        // TODO : do checks here
        require(certificateRegistry[_certificateId].owner != address(0), "Certificate does not exist");
        require(!isValidator[_certificateId][msg.sender], "Already a validator");
        require(certificateRegistry[_certificateId].valid, "Certificate is not valid");
        certificateRegistry[_certificateId].validators.push(msg.sender);
        userValidatedCertificateIds[msg.sender].push(_certificateId);
        isValidator[_certificateId][msg.sender] = true;
        emit Validated(_certificateId, msg.sender, certificateRegistry[_certificateId].contractAddress);
    }

    // Getters

    /**
     * getCertificateIds : returns all the certificate ids currently created
     * @return The certificate ids
    */
    function getCertificateIds() public view returns(bytes32[] memory) {
        return certificatesIds;
    }

    /**
     * getCertificatedIdsOfCertificatesValidatedByUser : returns all the certificate ids currently validated by a user
     * @return The certificate ids
    */
    function getCertificatedIdsOfCertificatesValidatedByUser(address _user) public view returns(bytes32[] memory) {
        return userValidatedCertificateIds[_user];
    }

    /**
     * getCertificatedIdsForContractAddress : returns all the certificate ids associated to a contract address
     * @return The certificate ids
    */
    function getCertificatedIdsForContractAddress(address _contract) public view returns(bytes32[] memory) {
        return contractAddressToCertificateIds[_contract];
    }

    /**
     * getAllValidatorsOfContract : returns all the validators of a certificate
     * @param _certificateId The certificate id
     * @return The addresses of the validators
    */
    function getAllValidatorsOfCertificate(bytes32 _certificateId) public view returns(address[] memory) {
        return certificateRegistry[_certificateId].validators;
    }

    // Helpers
    /**
     * _hash : creates a unique id for a certificate
     * @param _name The name/description of the contract
     * @param _contract The contract address for which the certificate is created
     * @param _owner The creator of the certificate
     * @param _chainId The chain id of the network where the contract is deployed
    */
    function _hash(string memory _name, address _contract, address _owner, uint256 _chainId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_name, _contract, _owner, _chainId));
    }

}