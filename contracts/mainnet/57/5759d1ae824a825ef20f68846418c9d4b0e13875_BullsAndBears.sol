/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-31
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


interface IERC20 {
  function totalSupply() external view returns (uint256 supply);

  function balanceOf(address _owner) external view returns (uint256 balance);

  function transfer(address _to, uint256 _value) external returns (bool success);

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) external returns (bool success);

  function approve(address _spender, uint256 _value) external returns (bool success);

  function allowance(address _owner, address _spender) external view returns (uint256 remaining);

  function decimals() external view returns (uint256 digits);

  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Account {

    IERC20 public baseToken ;
    address public operator;
    //int256 public desiredStableBalance; //if negative, position is long if positive, position is short
    uint256 public initialUSDCBalance;
    uint256 public initialTime;

    constructor(address _baseToken) {
        baseToken = IERC20(_baseToken);
        operator = msg.sender;
        baseToken.approve(operator, uint256(int256(-1)));
    }

    function enterLong(uint256 price) public{
        initialUSDCBalance = baseToken.balanceOf(address(this));
        initialTime = block.timestamp;
        require(msg.sender == operator,"B&B-acc/only-operator");
        
    }

    function enterShort(uint256 price) public{
        initialUSDCBalance = baseToken.balanceOf(address(this));
        initialTime = block.timestamp;
        require(msg.sender == operator,"B&B-acc/only-operator");  
    }

    function exitLong(uint256 price) public{
        require(msg.sender == operator,"B&B-acc/only-operator");
        
    }

    function exitShort(uint256 price) public{
        require(msg.sender == operator,"B&B-acc/only-operator");  
    }

    function flip(uint256 price) public{
        require(msg.sender == operator,"B&B-acc/only-operator");  
    }
}



contract BullsAndBears {

    enum AccountState { INITIAL, BULL, BEAR }

    struct User {
        AccountState state;
        address account;
    }

    mapping(address => User) public accounts ;

    IERC20 public baseToken ;

    constructor(address _baseToken) {
        baseToken = IERC20(_baseToken);
    }


    function deposit(uint amount) public{

        if(accounts[msg.sender].account == address(0)){
            accounts[msg.sender] = User(AccountState.INITIAL ,address(new Account(address(baseToken))));
        }else{
            require(accounts[msg.sender].state == AccountState.INITIAL,"B&B/deposit-initial-only");
        }
        baseToken.transferFrom(msg.sender, accounts[msg.sender].account, amount);
    }

    function withdrawAll() public{
        require(accounts[msg.sender].state == AccountState.INITIAL,"B&B/withdraw-initial-only");
        baseToken.transferFrom(accounts[msg.sender].account, msg.sender, baseToken.balanceOf(accounts[msg.sender].account));
    }

    function enterLong(uint256 price) public{
        require(accounts[msg.sender].state == AccountState.INITIAL,"B&B/initial-only");
        Account(accounts[msg.sender].account).enterLong(price);
        accounts[msg.sender].state = AccountState.BULL;
    }

    function enterShort(uint256 price) public{
        require(accounts[msg.sender].state == AccountState.INITIAL,"B&B/initial-only");
        Account(accounts[msg.sender].account).enterShort(price);
        accounts[msg.sender].state = AccountState.BEAR;
    }

    function exitLong(uint256 price) public{
        require(accounts[msg.sender].state == AccountState.BULL,"B&B/bull-only");
        Account(accounts[msg.sender].account).exitLong(price);
        accounts[msg.sender].state = AccountState.INITIAL;
    }

    function exitShort(uint256 price) public{
        require(accounts[msg.sender].state == AccountState.BEAR,"B&B/bear-only");
        Account(accounts[msg.sender].account).exitShort(price);
        accounts[msg.sender].state = AccountState.INITIAL;
    }

    function flip(uint256 price) public{
        require(accounts[msg.sender].state == AccountState.BULL || accounts[msg.sender].state == AccountState.BEAR,"B&B/deposit-initial-only");
        Account(accounts[msg.sender].account).flip(price);
        if(accounts[msg.sender].state == AccountState.BULL){
            accounts[msg.sender].state = AccountState.BEAR;
        }else{
            accounts[msg.sender].state = AccountState.BULL;
        }
    }

    function getBalance() public view returns(AccountState state, uint256 initialNetWorth, uint256 enterTime, uint256 dollarNetWorth, int256 ethExposureFactor){
        initialNetWorth = Account(accounts[msg.sender].account).initialUSDCBalance();
        enterTime = Account(accounts[msg.sender].account).initialTime();
        dollarNetWorth = initialNetWorth *99/100;
        if(accounts[msg.sender].state == AccountState.BULL){
            ethExposureFactor = 19957;
        }
        if(accounts[msg.sender].state == AccountState.BEAR){
            ethExposureFactor = -9985;
        }
        if(accounts[msg.sender].state == AccountState.INITIAL){
            ethExposureFactor = 0;
        }
        return (accounts[msg.sender].state, initialNetWorth, enterTime, dollarNetWorth, ethExposureFactor);
    }

    function getEthPrice() public view returns(uint256 uniswapPrice, uint256 oraclePrice) {
        uniswapPrice = 17000000;
        oraclePrice = 17000000;
        return (uniswapPrice, oraclePrice);
    }
}