/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-22
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

contract Bet {
    address house;
    uint256 fees = 0;

    struct UserBet {
        uint256 id;
        address bettor;
        uint256 time;
        uint256 amount;
        uint position;
    }

    struct Meta {
        uint256 id;
        uint256 start_time;
        uint256 end_time;
        address oracle;
        uint result;
        uint256 for_pot;
        uint256 against_pot;
        uint house_fees_bps;
    }

    uint256 house_fee_bps = 1;

    mapping (uint256 => mapping (address => UserBet)) bets;
    mapping (uint256 => Meta) meta;
    mapping (uint256 => mapping (address => uint256)) balances;
    uint256 last_id = 0;

    constructor() {
        house = msg.sender;
    }

    function start() public returns (uint256) {
        last_id += 1;
        meta[last_id] = Meta({
            id: last_id,
            start_time: block.timestamp,
            end_time: 0,
            oracle: msg.sender,
            result: 0,
            for_pot: 0,
            against_pot: 0,
            house_fees_bps: house_fee_bps
        });
        return last_id;
    }

    function end(uint256 bet_id, uint result) public {
        require(meta[bet_id].id != 0, "Invalid bet");
        require(meta[bet_id].oracle == msg.sender, "This address cannot end the bet");

        meta[bet_id].end_time = block.timestamp;
        meta[bet_id].result = result;
    }

    function enter(uint256 bet_id, uint position) public payable {
        require(meta[bet_id].end_time == 0, "Bet has completed. Cannot enter");
        require(meta[bet_id].oracle != msg.sender, "Oracle cannot enter a bet");
        require(bets[bet_id][msg.sender].id == 0, "Bet has already been placed");

        bets[bet_id][msg.sender] = UserBet({
            id: bet_id,
            bettor: msg.sender,
            time: block.timestamp,
            amount: msg.value,
            position: position
        });
        balances[bet_id][msg.sender] = msg.value;
        if (position == 0) {
            meta[bet_id].for_pot += msg.value;
        } else {
            meta[bet_id].against_pot += msg.value;
        }
    }

    function claim(uint256 bet_id) public {
        require(meta[bet_id].end_time != 0, "Bet has not completed");
        require(balances[bet_id][msg.sender] != 0, "User has no balance for receiving payout");

        UserBet memory user_bet = bets[bet_id][msg.sender];
        Meta memory bet = meta[bet_id];
        uint result = bet.result;
        if (user_bet.position == result) {
            uint256 amount = balances[bet_id][msg.sender];
            uint256 total_pot = 0;
            uint256 dipping_pot = 0;
            if (bet.result == 0) {
                total_pot = bet.for_pot;
                dipping_pot = bet.against_pot;
            } else {
                total_pot = bet.against_pot;
                dipping_pot = bet.for_pot;
            }
            if (total_pot == 0 || dipping_pot == 0) {
                revert("One or both the pots are empty. Cannot make a payout.");
            }
            uint256 winning_ratio = ((bet.end_time - user_bet.time) * amount) / ((bet.end_time - bet.start_time) * total_pot);
            uint256 winning_amount = winning_ratio * dipping_pot;
            uint256 house_fees = winning_amount * bet.house_fees_bps / 100;
            fees += house_fees;
            uint256 adjusted_winning_amount = amount + (winning_amount - house_fees);
            balances[bet_id][msg.sender] = 0;
            if (!payable(msg.sender).send(adjusted_winning_amount)) {
                balances[bet_id][msg.sender] = amount;
            }
        } else {
            revert("You have not won this bet");
        }
    }

    function claimFees() public {
        require(msg.sender == house, "Only house can claim fees");
        require(fees > 0, "No fees to payout");

        uint256 amount = fees;
        fees = 0;
        if (!payable(msg.sender).send(amount)) {
            fees = amount;
        }
    }
}