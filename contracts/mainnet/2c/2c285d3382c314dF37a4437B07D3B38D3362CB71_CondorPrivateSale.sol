/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-29
*/

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^ 0.8.17;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }
    
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }
    
    modifier whenPaused() {
        _requirePaused();
        _;
    }
    
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }
    
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }
    
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

contract CondorPrivateSale is Pausable, ReentrancyGuard {
    address public admin;

    uint256 public unitPrice = 0.0007 ether;
    uint256 public hardcap = 7000 ether;
    uint256 public maxPurchase = 560 ether;
    uint256 public minPurchase = 7 ether;
    uint256 public endDate = 1674127657; //Jan 19, 2023
    uint256 public totalPurchasedETH = 0;

    address[] private arrayParticipants;
    uint256 public totalParticipants = 0;

    address payable safe = payable(0xfA2608A162dCA576e04Ea31433a9DEC5d41453DA);

    mapping(address => uint256) public userPurchasedETH;
    mapping(address => uint256) public usserPurchasedCONDOR;

    event TokensPurchased(address purchaser, uint256 weiAmount, uint256 tokenAmount);

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {
        purchase();
    }

    modifier saleIsActive() {
        uint256 weiAmount = msg.value;
        address beneficiary = msg.sender;

        require(weiAmount > 0, "weiAmount is 0");
        require(endDate >= block.timestamp, "end date reached");
        require(weiAmount >= minPurchase, "have to send at least: 7 ETH");
        require((userPurchasedETH[beneficiary] + weiAmount) <= maxPurchase, "cannot buy more than: 560 ETH");
        require((totalPurchasedETH + weiAmount) <= hardcap, "Hard Cap reached");
        require(beneficiary != address(this), "beneficiary is the contract address");
        _;
    }

    function purchase() public nonReentrant whenNotPaused saleIsActive payable {
        (bool sent, ) = safe.call{ value: msg.value }("");

        require(sent, "cannot transfer funds to safe");

        if(userPurchasedETH[msg.sender] == 0) {
            arrayParticipants.push(msg.sender);
            totalParticipants += 1;
        }

        userPurchasedETH[msg.sender] += msg.value;
        usserPurchasedCONDOR[msg.sender] += tokensForETH(msg.value);

        emit TokensPurchased(msg.sender, msg.value, tokensForETH(msg.value));
    }

    function pause() public virtual {
        require(msg.sender == admin, "only admin");
        _pause();
    }

    function unpause() public virtual {
        require(msg.sender == admin, "only admin");
        _unpause();
    }

    function tokensForETH(uint256 _amount) public view returns(uint256) {
        return _amount/unitPrice;
    }
}