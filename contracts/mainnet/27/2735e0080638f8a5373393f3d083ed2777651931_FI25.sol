/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-12
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract Owned {
    bool public paused;
    mapping(address => bool) internal _owners;
    uint8 internal _amountOwners = 0;

    constructor() {
        _owners[msg.sender] = true;
        _amountOwners++;
        paused = false;
    }

    function isOwner(address account) public view returns (bool) {
        return _owners[account];
    }

    modifier onlyOwner() {
        require(_owners[msg.sender], "Owned Error: Caller is not an owner.");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Pausable Error: Contract is paused.");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable Error: Contract is not paused.");
        _;
    }
}

contract Multisignature is Owned {
    string public _topic = "";

    event EnableMultisigEvent(address account);
    event DisableMultisigEvent(address account);

    mapping(address => bool) internal _haveVoted;
    uint8 private _voteCount;
    address[] _listOfVoters = new address[](0);

    bool public _multisigApprovalGiven = false;
    bool public _multisigEnabled = false;

    function multisigVoteApproved(string memory topic) internal returns (bool) {
        if (!_multisigEnabled) return true;
        if (_amountOwners == 1) return true;
        if (_multisigApprovalGiven && (keccak256(abi.encodePacked(_topic)) == keccak256(abi.encodePacked(topic)))) {
            resetVoting();
            return true;
        }
        return false;
    }

    function enableMultisig() public onlyOwner {
        _multisigEnabled = true;
        emit EnableMultisigEvent(msg.sender);
    }

    function disableMultisig() public onlyOwner {
        //Check multisignature vote eligibility
        require(
            multisigVoteApproved("DISABLE_MULTISIG"),
            "MultiSig Error: Multisignature requirements have not been met."
        );

        //Set _multisigEnabled to true
        _multisigEnabled = false;

        //Emit event
        emit DisableMultisigEvent(msg.sender);
    }

    function resetVoting() public onlyOwner {
        //Mark approval given as false
        _multisigApprovalGiven = false;

        //Reset vote count to zero
        _voteCount = 0;

        //Reset topic to empty string
        _topic = "";

        //Loop through _listOfVoters array and unmark their ballots
        for (uint256 voter = 0; voter < _listOfVoters.length; voter++) {
            _haveVoted[_listOfVoters[voter]] = false;
        }

        //Shrink _listOfVoters array
        _listOfVoters = new address[](0);
    }

    function vote() public onlyOwner {
        //Check to make sure that there are sufficient voters to initiate a vote
        require(
            (_amountOwners > 1) && (_amountOwners <= 3),
            "Multisig Error: Voting requires > 1 and <=3 owners."
        );
        require(
            keccak256(abi.encodePacked(_topic)) != keccak256(abi.encodePacked("")),
            "Multisig Error: Must set topic prior voting."
        );

        //Check to make sure that voter has not already voted
        require(
            !_haveVoted[msg.sender],
            "Multisig Error: You have already voted."
        );

        //Mark voter as voted
        _haveVoted[msg.sender] = true;

        //Add voter to _listOfVoters array
        _listOfVoters.push(msg.sender);

        //Increment vote count
        _voteCount++;

        //If two or more contract owners have voted in favor, mark approval given as true
        if (_voteCount >= 2) {
            _multisigApprovalGiven = true;
        }
    }

    function setTopic(string memory topic) public onlyOwner {
        //Cannot set topic 'ADD_NEW_OWNER' once there are three owners
        require(
            (keccak256(abi.encodePacked(topic)) != keccak256(abi.encodePacked("ADD_NEW_OWNER"))) || (_amountOwners != 3),
            "Multisig Error: Cannot call ADD_NEW_OWNER topic with >= 3 owners."
        );

        //Check to make sure that _topic is unset
        require(
            keccak256(abi.encodePacked(_topic)) == keccak256(abi.encodePacked("")),
            "Multisig Error: Topic cannot be changed during a pending vote."
        );

        //Set interal _topic variable
        _topic = topic;
    }
}

contract OwnedExtended is Multisignature {
    mapping(address => bool) internal _isExcludedFromFee;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function isExcludedFromFee(address account) public view returns (bool){
	return _isExcludedFromFee[account];
    }

    function addNewOwner(address newOwner) public onlyOwner {
        //Checking multisignature vote eligibility
        require(
            multisigVoteApproved("ADD_NEW_OWNER"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Checking to ensure that account being added is not a zero address
        require(
            newOwner != address(0),
            "Owned Error: Owner cannot be a zero address."
        );

        //Checking to ensure that account being added is not already an owner
        require(
            !_owners[newOwner],
            "Owned Error: Account is already an owner."
        );

        //Checking to ensure that total account owners are less than three
        require(
            _amountOwners < 3,
            "Owned Error: Contract cannot have more than three owners."
        );

        //Set account ownership to true
        _owners[newOwner] = true;

        //Exclude new owner from transaction fee
        _isExcludedFromFee[newOwner] = true;

        //Increase total amount of owners
        _amountOwners++;
    }

    function removeOwner(address ownerAccount) public onlyOwner {
        //Checking multisignature vote eligibility
        require(
            multisigVoteApproved("REMOVE_OWNER"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Checking to ensure that account being removed is an owner
        require(
	    _owners[ownerAccount], 
	    "Owned Error: Account is not owner."
	);

        //Checking to ensure that account being removed isn't the sender
        require(
            ownerAccount != msg.sender,
            "Owned Error: Owner cannot remove himself."
        );

        //Checking to ensure that amount of owners is greater than one
        require(
            _amountOwners > 1,
            "Owned Error: Amount of owners must be greater than one."
        );

        //Set account ownership to false
        _owners[ownerAccount] = false;

        //Include old owner in transaction fee
        _isExcludedFromFee[ownerAccount] = false;

        //Decrease amount of owners
        _amountOwners--;
    }
}

contract Pausable is OwnedExtended {
    event PausedEvt(address account);
    event UnpausedEvt(address account);

    function pause() public onlyOwner whenNotPaused {
        require(
            multisigVoteApproved("PAUSE"),
            "Multisig Error: Multisignature requirements have not been met."
        );
        paused = true;
        emit PausedEvt(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        require(
            multisigVoteApproved("UNPAUSE"),
            "Multisig Error: Multisignature requirements have not been met."
        );
        paused = false;
        emit UnpausedEvt(msg.sender);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract FI25 is Pausable, IERC20 {
    address private _owner;
    address public _commissionHolder;
    address public _burnAddress = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name = "FIDIS FI25 Crypto Index";
    string private _symbol = "FI25";

    uint8 private _decimals = 8;
    uint256 private _totalSupply = 0;
    uint256 _txFeeBP = 100; // Every integer equals 1 basis points (Value range 1 (0.01%) to 9999 (99.99%)

    event ReduceTokenSupply(address from, uint256 value);
    event CommissionHolderChange(address from, address to);

    constructor() {
        _owner = msg.sender;
        _isExcludedFromFee[_owner] = true;
        _commissionHolder = msg.sender;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function getTransferFeeRate() public view virtual returns (uint256) {
        return _txFeeBP;
    }

    function changeTransferFeeRate(uint256 amount) public whenNotPaused onlyOwner {
        //Check for multisig vote eligibility
        require(
            multisigVoteApproved("CHANGE_TX_FEE_RATE"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Check to ensure that submitted amount is between 1 and 9999.  Minimum fee is 0.01%.  Maximum fee is 99.99%
        require(
            (amount >= 1) && (amount <= 9999),
            "Tx Fee Error: Submitted value out of bounds.  Value must be >= 1 and <= 9999."
        );

        //Set transfer fee
        _txFeeBP = amount;
    }

    function increaseTokenSupply(address account, uint256 amount) public whenNotPaused onlyOwner {
        //Check for multisig vote eligibility
        require(
            multisigVoteApproved("INCREASE_TOKEN_SUPPLY"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Add tokens to total supply
        _totalSupply += amount;

        //Add tokens to account balance
        _balances[account] += amount;

        //Emit transfer event
        emit Transfer(address(0), account, amount);
    }

    function reduceTokenSupply(address account, uint256 amount) public whenNotPaused onlyOwner {
        //Check for multisig vote eligibility
        require(
            multisigVoteApproved("REDUCE_TOKEN_SUPPLY"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Checking to make sure that submitted address isn't the zero address
        //Checking to make sure that submitted address isn't the contract address
        require(
            (account != address(0)) && (account != address(this)),
            "Reduce Token Supply Error: Cannot destroy tokens from the zero or contract address."
        );

        //Checking to make sure that submitted address is an owners address and the message sender
        require(
            (_owners[account]) && (account == msg.sender),
            "Reduce Token Supply Error: Tokens may only be destroyed from a contract owner's own account."
        );

        //Checking to ensure that burn amount is less than or equal to address balance
        require(
            _balances[account] >= amount,
            "Reduce Token Supply Error: Account balance too small to satisfy request."
        );

        //Deduct token amount from account balance
        _balances[account] -= amount;
        
        //Increase token amount for burn address (_burnAddress)
        _balances[_burnAddress] += amount;

        //Emit Events
        emit Transfer(account, _burnAddress, amount);
        emit ReduceTokenSupply(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        uint256 senderBalance = _balances[sender];

        //Check to ensure that account has enough tokens to transfer
        require(
            senderBalance >= amount,
            "Transfer Error: Transfer amount exceeds balance."
        );

        //Check to ensure that sender is not the zero address
        //Check to ensure that recipient is not the zero address
        //Check to ensure that recipient is not the contract address
        require(
            (sender != address(0)) && (recipient != address(0)) && (recipient != address(this)),
            "Transfer Error: Cannot transfer from/to the zero/contract address."
        );

        //Check to ensure that transfer amount is greater than or equal to 10,000
        require(
            amount >= 10000,
            "Transfer Error: Cannot transfer amount smaller than 10,000 units."
        );

        //Initialize fee variable and set to 0%
        uint256 fee = 0;

        //Check if sender is excluded from paying transfer fees
        if (!_isExcludedFromFee[sender]) {
            //Set fee amount based off _txFeeBP. _txFeeBP integer represents 1 basis point or 0.01%
            fee = (amount * _txFeeBP) / 10000;

            //Add fee to commission holder account
            _balances[_commissionHolder] += fee;

            //Emit transfer event
            emit Transfer(msg.sender, _commissionHolder, fee);
        }

        //Deduct tokens from sender
        _balances[sender] = senderBalance - amount;

        //Add tokens minus fee to recipient
        _balances[recipient] += (amount - fee);

        //Emit transfer event
        emit Transfer(msg.sender, recipient, amount - fee);
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];

        require(
            currentAllowance >= amount,
            "Transfer From Error: Transfer amount exceeds allowance."
        );

        _transfer(sender, recipient, amount);

        _approve(sender, msg.sender, currentAllowance - amount);

        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        //Check to make sure owner is not the zero address
        //Check to make sure spender is not the zero address
        //Check to make sure spender is not contract address
        require(
            (owner_ != address(0)) && (spender != address(0)) && (spender != address(this)),
            "Approve Error: Cannot approve from/to the zero address or to contract's address."
        );

        //Set allowance
        _allowances[owner_][spender] = amount;

        //Emit event
        emit Approval(owner_, spender, amount);
    }

    function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
        _approve(msg.sender, spender, amount);

        return true;
    }

    function allowance(address owner_, address spender) public view override whenNotPaused returns (uint256) {
        return _allowances[owner_][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue) public override whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];

        _approve(msg.sender, spender, currentAllowance + addedValue);

        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public override whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];

        //Check to make sure that decreased amount is not lower than current allowance
        require(
            currentAllowance >= subtractedValue,
            "Decrease Allowance Error: Decreased allowance would be below zero."
        );

        _approve(msg.sender, spender, currentAllowance - subtractedValue);

        return true;
    }

    function excludeAddrFromTxFee(address account) public whenNotPaused onlyOwner {
        //Check to make sure account isn't already excluded from fee
        require(
            !_isExcludedFromFee[account],
            "Tx Fee Error: Address is already excluded from fee."
        );

        _isExcludedFromFee[account] = true;
    }

    function includeAddrInTxFee(address account) public whenNotPaused onlyOwner {
        //Check to make sure that account isn't already included in fee
        require(
            _isExcludedFromFee[account],
            "Tx Fee Error: Address is already included in fee."
        );

        //Check to make sure that account isn't an owners account
        require(
            !_owners[account],
            "Tx Fee Error: Cannot charge tx fee to contract owner."
        );

	//Check to make sure that account isn't the commission holder account
	require(
	    _commissionHolder != account,
	    "Tx Fee Error: Cannot charge tx fee to commission holder."
	);

        _isExcludedFromFee[account] = false;
    }

    function setAccountAsCommissionHolder(address account) public onlyOwner {
        //Check multisignature eligibility
        require(
            multisigVoteApproved("SET_COMMISSION_HOLDER"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Check that commission holder account is not the zero address
        require(
            account != address(0),
            "Commission Error: Commission holder cannot be the zero address."
        );

        //Check that commission holder isn't already set
        require(
            _commissionHolder != account,
            "Commission Error: Account is already the commission holder."
        );

        //Change commission holder
        _commissionHolder = account;

        //Emit event
        emit CommissionHolderChange(_commissionHolder, account);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        //Check for multisig vote eligibility
        require(
            multisigVoteApproved("TRANSFER_OWNERSHIP"),
            "Multisig Error: Multisignature requirements have not been met."
        );

        //Check to make sure that new owner is not the caller
        require(
            newOwner != msg.sender,
            "Owner Transfer Error: New owner is the same as caller."
        );

        //Check to make sure that new owner is not already an owner
        require(
            !_owners[newOwner],
            "Owner Transfer Error: New owner is already an owner."
        );

        //Check to make sure that new owner's address is not zero
        //Check to make sure that new owner's address is not the contract address
        require(
            (newOwner != address(0)) && (newOwner != address(this)),
            "Owner Transfer Error: New owner's address cannot be zero or contract's address."
        );

        //Previous contract owner is removed
        _owners[msg.sender] = false;
        _isExcludedFromFee[msg.sender] = false;

        //New contract owner is added
        _owners[newOwner] = true;
        _isExcludedFromFee[newOwner] = true;

        //Emit event log
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}