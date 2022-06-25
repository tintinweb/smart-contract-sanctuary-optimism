/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-25
*/

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;



  /**********************************************************************
   *                                                                    *
   *    Stations.sol                                                    *
   *                                                                    *
   *      author:    Tony Fischetti    <[email protected]>          *
   *      version:   9                                                  *
   *                                                                    *
   **********************************************************************/


/**
 * Description:
 *
 *
 */

/**
 * Specifications / flags / config
 *
 * Note:
 *   The flag <-> meaning mapping available in the project's
 *   docs will always be at least as up-to-date as the info
 *   here. Refer to that instead.
 *
 *   station type:
 *     0x0000 = microblog
 *
 *   station_flags (starting from left-most bit)
 *     0: single user (0) or multi-user (1)                   - 0x8000
 *     1: trusted/render arbitrary HTML (0) or untrusted (1)  - 0x4000
 *     2: private (0) or public (1)                           - 0x2000
 *     3: undeletable (0) or deletable (1) broadcasts         - 0x1000
 *
 *     4: unmodifiable (0) or modifiable (1) broadcasts       - 0x0800
 *     5: disallow (0) or allow (1) replies                   - 0x0400
 *     6: disallow (0) or allow (1) changing usernames        - 0x0200
 *
 *   broadcast_flags (starting from left-most bit)
 *     0: user-created (0) or system-created (1)              - 0x8000
 *     1: undeleted (0) or (1) deleted broadcast              - 0x4000
 *     2: unedited (0) or (1) edited broadcast                - 0x2000
 *     3: unimported (0) or imported (1) broadcast            - 0x1000
 *
 *     4: apocryphal date (1)                                 - 0x0800
 *     5: encrypted (1)                                       - 0x0400
 *
 *   broadcast_type
 *     0x0000 = raw HTML
 *     0x0001 = plain text
 *     0x0002 = music video with lyrics
 *
 */


/**
 * Example station instantiation:
 *   creator: 0xdF94fCA483faf1bf1f1f484df3e0F1B5fF216bAe
 *   name: Den of understanding
 *   frequency: den-of-understanding
 *   description: an investigation into pulling the curtain back and
                  seeing how the machinery works
 *   type: 0x0000
 *   flags: 0x1E00       (0x9E00 for group tests)
 */

/**
 * TODO:
 *  [x] signature
 *    [ ] should the signed hash contain the timestamp and username?
 *  [ ] another broadcast_type (that's my jam?)
 *  [ ] events that are good enough to create station state from scratch
 *  [ ] "acknowledgements" (and count)
 *  [ ] implement piece-meal fetching of broadcasts
 *  [ ] grep for /TODO/
 *  [ ] self-destruct
 *  [ ] closer to end, trade from clarity to give to gas savings
 *  [ ] delete replies/acknowledgements go away on an edit?
 *        or maybe you need approval after edit?
 *  [ ] all the other ones
 */

contract Stations {

    /* ------------------------------------------------------ */
    /* -- STATE VARIABLES                                     */

    string            station_name;
    string            station_frequency;
    string            station_description;
    uint256 constant  stations_version = 9;
    uint256 constant  stations_minor_version = 1;
    address immutable creator;
    uint256 immutable created_on;
    bytes2  immutable station_type;
    bytes2  immutable station_flags;
    string            station_metadata = "";

    uint256           current_broadcast_id = 0;
    uint256           current_user_index   = 0;
    User      []      all_users_of_station;
    Broadcast []      all_broadcasts;

    mapping(address => uint) user_exist_map;
    mapping(string  => bool) username_exist_map;
    mapping(address => bool) admin_map;
    mapping(address => bool) whitelist_map;

    bool sf_multiuser_p;
    bool sf_untrusted_p;
    bool sf_public_p;
    bool sf_deletable_broadcasts_p;
    bool sf_modifiable_broadcasts_p;
    bool sf_allow_replies_p;
    bool sf_allow_changing_usernames_p;
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- STRUCTURES                                          */

    struct Broadcast {
        uint256 broadcast_id;
        uint256 unix_timestamp;
        address author;
        string  content;
        bytes   signature;
        uint256 parent;
        uint256 reference_count;
        bytes2  broadcast_type;
        bytes2  broadcast_flags;
        string  broadcast_metadata;
    }

    struct User {
        address user_address;
        string  username;
        uint256 time_joined;
        string  user_metadata;
    }
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- EVENTS                                              */

    event UserJoined(
        User theuser
    );

    event NewBroadcast(
        Broadcast thebroadcast
    );

    event BroadcastChange(
        string whatkindofchange,
        Broadcast thebroadcast
    );

    event StationMetadataChange(
        string whatkindofchange
    );

    event UserMetadataChange(
        string whatkindofchange,
        User theuser
    );

    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- CONSTRUCTOR (and parameter getters)                 */

    constructor (address       _creator,
                 string memory _station_name,
                 string memory _station_frequency,
                 string memory _station_description,
                 bytes2        _station_type,
                 bytes2        _station_flags,
                 string memory _station_metadata) {
        creator = _creator;
        station_name = _station_name;
        station_frequency = _station_frequency;
        station_description = _station_description;
        station_type  = _station_type;
        station_flags = _station_flags;
        station_metadata = _station_metadata;

        // creator is automatically an admin
        admin_map[_creator] = true;
        // creator is automatically whitelisted
        whitelist_map[_creator] = true;
        created_on = block.timestamp;
    }

    // should get called right after contract creation
    function inaugurate_station(string memory username) public returns (bool){
        address who = msg.sender;

        require(who == creator,
                "error: need to be the station creator to inaugurate station");

        // interpreting station flags (to avoid repeated function calls)
        sf_multiuser_p                 = ((station_flags & 0x8000) > 0);
        sf_untrusted_p                 = ((station_flags & 0x4000) > 0);
        sf_public_p                    = ((station_flags & 0x2000) > 0);
        sf_deletable_broadcasts_p      = ((station_flags & 0x1000) > 0);
        sf_modifiable_broadcasts_p     = ((station_flags & 0x0800) > 0);
        sf_allow_replies_p             = ((station_flags & 0x0400) > 0);
        sf_allow_changing_usernames_p  = ((station_flags & 0x0200) > 0);

        // creating system user... the uncaused cause
        User memory uncaused_cause = User(address(this), "uncaused-cause",
                                          created_on, "");
        user_exist_map[address(this)] = current_user_index;
        all_users_of_station.push(uncaused_cause);
        current_user_index += 1;
        username_exist_map["uncaused-cause"] = true;

        // creates the "prime" broadcast
        Broadcast memory tmp = Broadcast(0, 0, address(this),
                                         "this is a placeholder",
                                         abi.encodePacked(username),
                                         0, 0, 0x0001, 0x8000, "");
        all_broadcasts.push(tmp);
        current_broadcast_id += 1;

        // setting username of station creator
        uint256 timenow = block.timestamp;
        User memory tmp2 = User(who, username, timenow, "");
        user_exist_map[who] = current_user_index;
        username_exist_map[username] = true;
        all_users_of_station.push(tmp2);
        current_user_index += 1;
        return true;
    }

    function station_info() public view returns (string memory, string memory,
                                                 string memory, uint256,
                                                 uint256, address, uint256,
                                                 bytes2, bytes2, string memory,
                                                 uint256, uint256){
        return (station_name, station_frequency, station_description,
                stations_version, stations_minor_version, creator,
                created_on, station_type, station_flags, station_metadata,
                current_user_index, current_broadcast_id);
    }
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- CHECKING FUNCTIONS (VIEW)                           */

    function user_already_in_station_p(address who)
               public view returns(bool){
        return user_exist_map[who] > 0;
    }

    function username_already_in_station_p(string memory a_name)
               public view returns(bool){
        return username_exist_map[a_name];
    }

    function is_admin_p(address who) public view returns (bool){
        return admin_map[who];
    }

    function is_allowed_in_p(address who) public view returns (bool){
        return whitelist_map[who];
    }
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- ACCESSOR (VIEW or PURE) FUNCTIONS (AND DEBUGGING)   */

    function get_all_broadcasts() public view returns (Broadcast [] memory){
        return all_broadcasts;
    }

    function get_all_users() public view returns (User [] memory){
        return all_users_of_station;
    }
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- MORE INTERESTING FUNCTIONS                          */

    function join_station(string memory username) public returns (bool){
        address who = msg.sender;

        require(sf_multiuser_p || who==creator,
                "station is single-user. cannot join station");
        require(sf_public_p || whitelist_map[who],
                "error: address not whitelisted and group is private");
        require(!user_already_in_station_p(who),
                "error: user already in station");
        require(!username_already_in_station_p(username),
                "error: username already taken");

        uint256 timenow = block.timestamp;
        user_exist_map[who] = current_user_index;
        User memory tmp = User(who, username, timenow, "");
        all_users_of_station.push(tmp);
        current_user_index += 1;
        username_exist_map[username] = true;
        emit UserJoined(tmp);
        return true;
    }

    // TODO: this is a temporary solution
    function _add_user_to_station(address new_user_address,
                                  string memory username)
                                     public returns (bool){
        address who = msg.sender;
        require(is_admin_p(who),
                "error: must be admin to add user in this manner");
        require(sf_multiuser_p || who==creator,
                "station is single-user. cannot join station");
        require(!user_already_in_station_p(new_user_address),
                "error: user already in station");
        require(!username_already_in_station_p(username),
                "error: username already taken");

        uint256 timenow = block.timestamp;
        user_exist_map[new_user_address] = current_user_index;
        User memory tmp = User(new_user_address, username, timenow, "");
        all_users_of_station.push(tmp);
        current_user_index += 1;
        username_exist_map[username] = true;
        emit UserJoined(tmp);
        return true;
    }

    function do_broadcast(string memory content, bytes memory signature,
                          uint256 parent, bytes2 broadcast_type,
                          bytes2  broadcast_flags,
                          string  memory broadcast_metadata,
                          uint256 optional_timestamp)
                               public returns (bool){
        address who = msg.sender;
        uint256 timetouse = block.timestamp;

        if (optional_timestamp != 0){
            // date is now apocryphal
            timetouse = optional_timestamp;
            broadcast_flags = broadcast_flags | 0x0800;
        }

        require(user_already_in_station_p(who), "error: user not in station");
        require((broadcast_type!=0x0000) || (!sf_untrusted_p),
                "error: this station cannot broadcast raw HTML");
        require(!((broadcast_flags & 0x8000) > 0),
                "error: cannot broadcast a 'system' broadcast");
        require(parent == 0 || sf_allow_replies_p,
                "error: this station doesn't accept replies");
        require(verify_broadcast_author(content, who, signature),
                "error: signature mismatch");

        Broadcast memory tmp = Broadcast(current_broadcast_id, timetouse, who,
                                         content, signature, parent, 0,
                                         broadcast_type, broadcast_flags,
                                         broadcast_metadata);

        all_broadcasts[parent].reference_count += 1;
        all_broadcasts.push(tmp);
        emit NewBroadcast(tmp);
        current_broadcast_id += 1;
        return true;
    }

    function import_broadcast(uint256 unix_timestamp,
                              address author,
                              string  memory content,
                              bytes   memory sig,
                              bytes2  broadcast_type,
                              bytes2  broadcast_flags,
                              string  memory broadcast_metadata)
                                                 public returns (uint256){
        address who = msg.sender;
        // TODO: do you, though?
        require(is_admin_p(who),
                "error: need to be station admin to import");
        require(verify_broadcast_author(content, author, sig),
                "error: signature mismatch");
        // no raw html messages if untrusted
        require(!(sf_untrusted_p && broadcast_type==0x0000),
                "error: untrusted station cannot import html broadcasts");
        require((broadcast_flags & 0x8000) == 0,
                "error: cannot import system broadcasts");
        require((broadcast_flags & 0x4000) == 0,
                "error: will not import deleted broadcasts");
        // TODO: can I just use 0xC000 for both?

        Broadcast memory tmp = Broadcast(current_broadcast_id,
                                         unix_timestamp, author, content,
                                         sig, 0, 0, broadcast_type,
                                         broadcast_flags|0x1000|0x0800,
                                         broadcast_metadata);
        all_broadcasts.push(tmp);
        emit NewBroadcast(tmp);
        current_broadcast_id += 1;
        all_broadcasts[0].reference_count += 1;

        return 1;
    }

    function change_username(string memory new_username) public returns (bool){
        address who = msg.sender;

        require(sf_allow_changing_usernames_p,
                "error: this station does not support changing usernames");
        require(user_already_in_station_p(who),
                "error: user not in station");
        require(!username_already_in_station_p(new_username),
                "error: username already taken");

        string memory old_username = all_users_of_station[user_exist_map[who]].username;
        username_exist_map[old_username] = false;
        username_exist_map[new_username] = true;
        all_users_of_station[user_exist_map[who]].username = new_username;
        emit UserMetadataChange("username-change",
                                all_users_of_station[user_exist_map[who]]);
        return true;
    }

    function add_admin(address someone) public returns (bool){
        require(is_admin_p(msg.sender),
                "error: need to be an admin to add another admin");
        require(sf_multiuser_p,
                "station is single-user. cannot add admin");
        admin_map[someone] = true;
        return true;
    }

    function remove_admin(address someone) public returns (bool){
        require(msg.sender == creator,
                "error: need to be station creator to remove an admin");
        require(creator == someone,
                "error: cannot remove station creator from admin list");
        admin_map[someone] = false;
        return true;
    }

    function whitelist_address(address someone) public returns (bool){
        require(is_admin_p(msg.sender),
                "error: need to be an admin to whitelist address");
        whitelist_map[someone] = true;
        return true;
    }

    function reverse_whitelist(address someone) public returns (bool){
        require(is_admin_p(msg.sender),
                "error: need to be an admin to remove address from whitelist");
        whitelist_map[someone] = false;
        return true;
    }
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- DELETIONS AND EDITING FUNCTIONS                     */

    // TODO QUESTION: should the bcaster *and* the admins be able to delete?
    function delete_broadcast(uint256 id_to_delete) public returns (bool){
        require(sf_deletable_broadcasts_p,
                "error: station doesn't allow deletion of broadcasts");
        require(is_admin_p(msg.sender) ||
                  msg.sender == all_broadcasts[id_to_delete].author,
                "error: must be admin or author to delete a broadcast");
        require(id_to_delete != 0, "error: cannot delete prime broadcast");
        require(id_to_delete < current_broadcast_id,
                "error: array index out of bounds");
        all_broadcasts[id_to_delete].content = "";
        all_broadcasts[id_to_delete].signature = "";
        bytes2 newflags = all_broadcasts[id_to_delete].broadcast_flags|0x4000;
        all_broadcasts[id_to_delete].broadcast_flags = newflags;
        all_broadcasts[0].reference_count -= 1;
        emit BroadcastChange("deletion", all_broadcasts[id_to_delete]);
        return true;
    }

    // TODO: needs more flexibility
    // NOTE: even the creator cannot edit a broadcast made by someone else
    function edit_broadcast(uint256 id_to_edit,
                            string memory newcontent,
                            bytes memory newsignature) public returns (bool){
        address who = msg.sender;
        require(sf_modifiable_broadcasts_p,
                "error: station doesn't allow editing broadcasts");
        require(msg.sender == all_broadcasts[id_to_edit].author,
                "error: must be author to edit a broadcast");
        require(id_to_edit != 0, "error: cannot edit prime broadcast");
        require(id_to_edit < current_broadcast_id,
                "error: array index out of bounds");
        require(verify_broadcast_author(newcontent, who, newsignature),
                "error: signature mismatch");
        all_broadcasts[id_to_edit].content = newcontent;
        all_broadcasts[id_to_edit].signature = newsignature;
        bytes2 newflags = all_broadcasts[id_to_edit].broadcast_flags | 0x2000;
        all_broadcasts[id_to_edit].broadcast_flags = newflags;
        emit BroadcastChange("edit", all_broadcasts[id_to_edit]);
        return true;
    }

    function replace_broadcast_metadata(uint256 id_to_edit,
                                        string memory newmetadata)
                                               public returns (bool){
        require(sf_modifiable_broadcasts_p,
                "error: station doesn't allow editing broadcasts");
        require(msg.sender == all_broadcasts[id_to_edit].author,
                "error: must be author to edit a broadcast");
        require(id_to_edit != 0, "error: cannot edit prime broadcast");
        require(id_to_edit < current_broadcast_id,
                "error: array index out of bounds");
        all_broadcasts[id_to_edit].broadcast_metadata = newmetadata;
        emit BroadcastChange("metadata-change", all_broadcasts[id_to_edit]);
        return true;
    }

    function replace_station_metadata(string memory newmetadata)
                                             public returns (bool){
        require(is_admin_p(msg.sender),
                "error: must be admin or author to change station metadata");
        station_metadata = newmetadata;
        emit StationMetadataChange("metadata-change");
        return true;
    }

    function replace_station_name(string memory newname)
                                             public returns (bool){
        require(is_admin_p(msg.sender),
                "error: must be admin or author to change station metadata");
        station_name = newname;
        emit StationMetadataChange("name-change");
        return true;
    }

    function replace_station_description(string memory newdescription)
                                                    public returns (bool){
        require(is_admin_p(msg.sender),
                "error: must be admin or author to change station metadata");
        station_description = newdescription;
        emit StationMetadataChange("description-change");
        return true;
    }

    function replace_user_metadata(string memory newmetadata)
                                                     public returns (bool){
        address who = msg.sender;
        require(user_already_in_station_p(who),
                "error: user not in station");
        all_users_of_station[user_exist_map[who]].user_metadata = newmetadata;
        emit UserMetadataChange("metadata-change",
                                all_users_of_station[user_exist_map[who]]);
        return true;
    }

    // TODO: write self destruct routine
    /* ------------------------------------------------------ */


    /* ------------------------------------------------------ */
    /* -- UTILITIES                                           */

    function get_hash(string memory text) pure public returns (bytes32){
        return keccak256(abi.encodePacked(text));
    }

    function ec_recover_signer(bytes32 msg_hash, bytes memory sig)
                                             public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = split_signature(sig);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixed = keccak256(abi.encodePacked(prefix, msg_hash));
        return ecrecover(prefixed, v, r, s);
    }

    function split_signature(bytes memory sig) public pure returns (bytes32 r,
                                                                    bytes32 s,
                                                                    uint8 v) {
        require(sig.length==65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27){
            v += 27;
        }
        require(v==27 || v==28, "invalid signature");
        return (r, s, v);
    }

    function verify_broadcast_author(string memory content,
                                     address alleged_author,
                                     bytes memory sig)
                                           public pure returns (bool){
        bytes32 the_hash = keccak256(abi.encodePacked(content));
        address real_author = ec_recover_signer(the_hash, sig);
        return (real_author==alleged_author);
    }
    /* ------------------------------------------------------ */


    function very_temp() public view returns (address){
        address who = msg.sender;
        return who;
    }

}