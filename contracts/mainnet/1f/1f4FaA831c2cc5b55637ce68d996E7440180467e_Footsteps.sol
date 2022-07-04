/**
 *Submitted for verification at optimistic.etherscan.io on 2022-07-04
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//// ============ Interfaces ==============

interface Registerverifier{
  // @notice Verifies zk proof when player registers
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[2] memory input
        ) external view returns (bool);
}


interface Moveverifier{
  // @notice Verifies zk proof when player moves
  function verifyProof(
            uint[2] memory ,
            uint[2][2] memory ,
            uint[2] memory ,
            uint[3] memory 
        ) external view returns (bool );
}

interface DefenseVerifier{
  // @notice Verifies zk proof when player defends
  function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[3] memory input
        ) external view returns (bool);
}

/// @title  Footsteps contract 
/// @author Supernovahs.eth  <Twitter: @harshit16024263 > 
// @notice Game logic for Board Game Footsteps
contract Footsteps {

/// ============================= Storage =================================
  address public immutable  registerverifier;
  address public immutable moveverifier;
  address public immutable verifierdefend;

 
  address[] public activeplayers;


  // =========== mapping ============

  mapping(address =>uint) public Id;
  mapping(address=> Player) public players;
  mapping(address =>Attack) public attacks;


  // ===========  struct ============

  struct Player{
    address player;
    uint health;
    uint location;
    uint zone;
    bool alive;
  }

  struct Attack{
    uint xguess;
    uint yguess;
    bool active;
    address attacker;
  }

  /// ===================Custom errors=========================== 

  error AlreadyRegistered(address player);
  error InvalidProof();
  error DefendFirst();
  error Dead();
  error InvalidLocation();
  error NoAttack();
  error WrongGuess();
  error Cheater();
  error ZombiesNotAllowed();


 // =======================events============================

  event register(address indexed player,bool indexed registered);
  event move(address indexed player, bool indexed moved);
  event dead(address indexed player,bool indexed deadornot);
  event attack(address indexed attacker,address indexed victim);
  event defend(address indexed gained);


/// ====================== Constructor ======================

/// @notice  Creates Footsteps contract
/// @param _registerverifier Address of register verifier
/// @param _moveverifier Address of move verifier
/// @param _defendverifier Address of defend verifier

  constructor (address _registerverifier,address _moveverifier,address _defendverifier) public payable{
    registerverifier = _registerverifier;
    moveverifier = _moveverifier;
    verifierdefend = _defendverifier;
  }


  /// ====================Internal Functions ===================

/// @notice : Exit the Game 
  function exit(address plr) internal {
    if(players[plr].alive ==true){
    
    activeplayers[Id[plr] -1 ] = activeplayers[activeplayers.length -1];
      Id[activeplayers[activeplayers.length -1]] = Id[plr];
      activeplayers.pop();
      Id[plr] =0;
      players[plr].alive =false;
      emit dead(plr,true);
    }
  }

/// Exit the game
  function Quit() external {
    if(msg.sender == players[msg.sender].player){
      exit(msg.sender);
    }
  }



  /// ================ Public functions ===============

/// @notice Registers player to the game
/// @param a ZK Proof of player's registration
/// @param b ZK Proof of player's registration
/// @param c ZK Proof of player's registration
/// @param input input[0] = location-hash , input[1] = zone

  function Register(uint[2] memory a,uint[2][2] memory b,uint[2] memory c,uint[2] memory input) external {
    if(!(Registerverifier(registerverifier).verifyProof(a,b,c,input) == true)) revert InvalidProof();
    Player memory plr = players[msg.sender];
     if( plr.player == msg.sender  && plr.alive==true) revert AlreadyRegistered(msg.sender);// Condition to check whether player is leaving even though its not dead.
     /// Below is to reregister or register for first time. Code is same for both.

     Player memory  player = Player({
      player: msg.sender,
      health: 100,
      location: input[0],
      zone: input[1],
      alive: true
    });

    players[msg.sender] = player;

    activeplayers.push(msg.sender);
    Id[msg.sender] = activeplayers.length;
    emit register(msg.sender,true);
  } 

/// @notice Moves player to a new location
/// @param a ZK Proof of player's movement
/// @param b ZK Proof of player's movement
/// @param c ZK Proof of player's movement
/// @param input input[0] =last  location hash , input[1] = New location hash,input[2] = new zone
/// [email protected] input[0] should be equal to lash location hash to avoid cheating.

  function Move(uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[3] memory input) external {
    if(!(Moveverifier(moveverifier).verifyProof(a,b,c,input) == true)) revert InvalidProof();
    if(attacks[msg.sender].active == true) revert DefendFirst();

    Player storage player = players[msg.sender];
    if(player.alive ==false) revert Dead();
    if (player.location != input[0]) revert InvalidLocation();

    player.location = input[1];/// New location hash is updated here
    player.zone = input[2];/// zone is public to give hints to other players
    player.health -=4;/// health decreases by 4 on every successful move
    if(player.health < 8){/// Handler: Health < 8 after Move condition.
      exit(msg.sender);
    }
    emit move(msg.sender,true);/// emits event to update local storage in front end 
  }


/// @notice Attack player by guessing location
/// @param player address of player to be attacked
/// @param x xcoordinate of player to be attacked
/// @param y ycoordinate of player to be attacked
/// @dev updates the mapping Attack.active to true to stop the victim to move. 

  function AttackPlayer(address player,uint x ,uint y) external {
    if(players[msg.sender].alive  == false) revert Dead();
    if(players[player].alive ==false) revert ZombiesNotAllowed();// Victim already Dead.

  attacks[player] = Attack({
    xguess: x,
    yguess: y,
    active: true,
    attacker: msg.sender
  });

  players[msg.sender].health -=8;/// Attacking  decreases health by 8pts
  if(players[msg.sender].health <8){  /// Handler: Health < 8 after attack condition. 
    exit(msg.sender);
  }
  emit attack(msg.sender,player);

  }


/// @notice Defending against an attack by proving location.
/// @param a ZK Proof of player who is  defending
/// @param b ZK Proof of player who is  defending
/// @param c ZK Proof of player who is  defending
/// @param input zk proof of input
/// @dev input[0] current location of attacked player
/// @dev input[1] xcoordinate of attacked player. Asserting this to be equal to guessed xcoordinate(by attacker) to prevent cheating by attacked player
/// @dev input[2] ycoordinate of attacked player. Asserting this to be equal to guessed ycoordinate(by attacker) to prevent cheating by attacked player

  function Defend(uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[3] memory input) external {
    if(!(DefenseVerifier(verifierdefend).verifyProof(a,b,c,input) == true)) revert InvalidProof();
    if(players[msg.sender].health <8) revert Dead();

    Player storage plr = players[msg.sender];
    Attack storage att = attacks[msg.sender];
    Player storage attackerplayer = players[att.attacker];

    if(att.active == false) revert NoAttack();
    if(input[0] != plr.location) revert WrongGuess();
    if(input[1] != att.xguess) revert Cheater();
    if(input[2] != att.yguess) revert Cheater();

  if(att.active == true){
    if(plr.health > attackerplayer.health){   /// If Defender's health >attacker , defender gains 20% of attacker's health
      plr.health += ((attackerplayer.health)/5);
      attackerplayer.health = ((attackerplayer.health)/5) * 4;
      att.active = false;
      emit defend(msg.sender);
    }

    else if(plr.health == attackerplayer.health) { /// If attacker health = defender health , attack failed
      att.active = false;
    }

    else{  /// else attacker gains half of defender's health
      attackerplayer.health += (plr.health/2);
      plr.health = (plr.health /2);
      att.active = false;
      emit defend(attackerplayer.player);
    }
    
  }
    if(plr.health <8){
      exit(msg.sender);
    }
    if(attackerplayer.health <8){
      exit(att.attacker);
    }

  }

/// @notice Returns the no. of active players 
  function TotalPlayers() external view returns (uint){
    return activeplayers.length;
  }
  
}