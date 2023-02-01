/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-31
*/

pragma solidity ^0.8.0;

contract DummyToken {
	// Variables
	uint256 public totalSupply = 100000000e18;
	uint8 public decimals = 18;
	string public name = "Dummy";
	string public symbol = "DUMMY";
	mapping(address => uint256) public balances;
	mapping(address => mapping(address => uint256)) public allowed;
	address public admin;
	address public noTaxWallet;
	address payable public marketingWallet;
	address payable public projectWallet;
	address payable public liquidityAddress;
	uint256 public marketingTax = 5;
	uint256 public projectTax = 5;
	uint256 public liquidityTax = 5;

	// Events
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

	// Constructor
	constructor() {
		admin = msg.sender;
		// Assign 100000000 dummy tokens to the admin
		balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
	}

	// ------------------ FUNCTIONS ------------------

	// Admin set marketing wallet
	function setMarketingWallet(address payable _marketingWallet) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		marketingWallet = _marketingWallet;
	}

	// Admin set project wallet
	function setLiquidityAddress(address payable _liquidityAddress) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		liquidityAddress = _liquidityAddress;
	}

	// Admin set liquidity wallet
	function setProjectWallet(address payable _projectWallet) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		projectWallet = _projectWallet;
	}

	// Admin set marketing tax (0-5%)
	function setMarketingTax(uint256 _marketingTax) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		require(_marketingTax <= 5, "Invalid marketing tax, must be less than or equal to 5");
		marketingTax = _marketingTax;
	}

	// Admin set project tax (0-5%)
	function setProjectTax(uint256 _projectTax) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		require(_projectTax <= 5, "Invalid project tax, must be less than or equal to 5");
		projectTax = _projectTax;
	}

	// Admin set liquidity tax (0-5%)
	function setLiquidityTax(uint256 _liquidityTax) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		require(_liquidityTax <= 5, "Invalid project tax, must be less than or equal to 5");
		liquidityTax = _liquidityTax;
	}

	// Admin set no tax wallet
	function setNoTaxWallet(address _noTaxWallet) public {
		require(msg.sender == admin, "Only the current admin can set a new admin.");
		noTaxWallet = _noTaxWallet;
	}

	// ------------------ IERC20 FUNCTIONS ------------------

	// Return balance of address
	function balanceOf(address _owner) public view returns (uint256) {
		return balances[_owner];
	}

	function transferFrom(address _sender, address _recipient, uint256 _value) public returns (bool) {
		require(balances[_sender] >= _value, "Sender does not have enough balance");
		require(allowed[_sender][msg.sender] >= _value, "Allowance is not enough");
		// Deduct tax if not no tax wallet
		uint256 marketingTaxValue = 0;
		uint256 projectTaxValue = 0;
		uint256 liquidityTaxValue = 0;
		if (_sender != noTaxWallet) {
			marketingTaxValue = _value * marketingTax / 100;
			projectTaxValue = _value *  projectTax / 100;
			liquidityTaxValue = _value *  liquidityTax / 100;
		}
		uint256 transferAmount = _value - marketingTaxValue - projectTaxValue - liquidityTaxValue;

		// Update balances
		balances[_sender] -= _value;
		balances[_recipient] += transferAmount;

		// Deduct allowance
		allowed[_sender][msg.sender] -= _value;

		// Transfer tax to marketing, project and liquidity wallets
		if (marketingTaxValue > 0) {
			marketingWallet.transfer(marketingTaxValue);
		}
		if (projectTaxValue > 0) {
			projectWallet.transfer(projectTaxValue);
		}
		if (liquidityTaxValue > 0) {
			liquidityAddress.transfer(liquidityTaxValue);
		}

		// Emit transfer event
		emit Transfer(_sender, _recipient, transferAmount);
		return true;
	}

	// Transfer token to another address
	function transfer(address _to, uint256 _value) public returns (bool) {
		require(balances[msg.sender] >= _value, "Not enough balance");

		// Deduct tax if not no tax wallet
		uint256 marketingTaxValue = 0;
		uint256 projectTaxValue = 0;
		uint256 liquidityTaxValue = 0;
		if (msg.sender != noTaxWallet) {
			marketingTaxValue = _value * marketingTax / 100;
			projectTaxValue = _value *  projectTax / 100;
			liquidityTaxValue = _value *  liquidityTax / 100;
		}
		uint256 transferAmount = _value - marketingTaxValue - projectTaxValue - liquidityTaxValue;

		// Update balances
		balances[msg.sender] -= _value;
		balances[_to] += transferAmount;

		// Transfer tax to marketing, project and liquidity wallets
		if (marketingTax > 0) {
			marketingWallet.transfer(marketingTaxValue);
		}
		if (projectTax > 0) {
			projectWallet.transfer(projectTaxValue);
		}
		if (liquidityTax > 0) {
			liquidityAddress.transfer(liquidityTaxValue);
		}

		// Emit transfer event
		emit Transfer(msg.sender, _to, transferAmount);
		return true;
	}

	// Approve and call for transfer from another address
	function approve(address _spender, uint256 _value) public returns (bool) {
		require(_spender != address(0), "Invalid spender address");

		// Approve transfer
		allowed[_spender][msg.sender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	// Return allowed transfer value
	function allowance(address _owner, address _spender) public view returns (uint256) {
		return allowed[_spender][_owner];
	}
}