// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.15;

import "./Utils.sol";
import "./EpochTree.sol";
import "./IDepositVerifier.sol";
import "./ITransferVerifier.sol";
import "./IWithdrawalVerifier.sol";

contract Firn is EpochTree {
    using Utils for uint256;
    using Utils for Utils.Point;

    uint256 constant EPOCH_LENGTH = 60;
    mapping(bytes32 => Utils.Point[2]) _acc; // main account mapping
    mapping(bytes32 => Utils.Point[2]) _pending; // storage for pending transfers
    mapping(bytes32 => uint256) _lastRollOver;
    mapping(address => bytes) public backups;
    bytes32[] _nonces; // would be more natural to use a mapping (really a set), but they can't be deleted / reset!
    uint32 _lastGlobalUpdate = 0; // will be also used as a proxy for "current epoch", seeing as rollovers will be anticipated

    IDepositVerifier _depositVerifier;
    ITransferVerifier _transferVerifier;
    IWithdrawalVerifier _withdrawalVerifier;
    uint32 _fee; // put `fee` into the same storage slot as withdrawalVerifier; both will have to be read during withdrawal.

    event RegisterOccurred(address indexed sender, bytes32 indexed account);
    event DepositOccurred(bytes32[N] Y, bytes32[N] C, bytes32 D, address indexed source, uint32 amount); // amount not indexed
    event TransferOccurred(bytes32[N] Y, bytes32[N] C, bytes32 D);
    event WithdrawalOccurred(bytes32[N] Y, bytes32[N] C, bytes32 D, uint32 amount, address indexed destination, bytes data);

    struct Info { // try to save storage space by using smaller int types here
        uint32 epoch;
        uint32 amount; // really it's not crucial that this be uint32
        uint32 index; // index in the list
    }
    mapping(bytes32 => Info) public info; // public key --> deposit info
    mapping(uint32 => bytes32[]) public lists; // epoch --> list of depositing accounts

    function lengths(uint32 epoch) external view returns (uint256) { // see https://ethereum.stackexchange.com/a/20838.
        return lists[epoch].length;
    }

    address _owner;
    address _treasury;

    // some duplication here, but this is less painful than trying to retrieve it from the IP verifier / elsewhere.
    bytes32 immutable gX;
    bytes32 immutable gY;

    constructor() {
        _owner = msg.sender; // the rest will be set in administrate
        Utils.Point memory gTemp = Utils.mapInto("g");
        gX = gTemp.x;
        gY = gTemp.y;
    }

    function g() internal view returns (Utils.Point memory) {
        return Utils.Point(gX, gY);
    }

    function administrate(address owner_, uint32 fee_, address deposit_, address transfer_, address withdrawal_, address treasury_) external {
        require(msg.sender == _owner, "Forbidden ownership transfer.");
        _owner = owner_;
        _fee = fee_;
        _depositVerifier = IDepositVerifier(deposit_);
        _transferVerifier = ITransferVerifier(transfer_);
        _withdrawalVerifier = IWithdrawalVerifier(withdrawal_);
        _treasury = treasury_;
    }

    function simulateAccounts(bytes32[] calldata Y, uint32 epoch) external view returns (bytes32[2][] memory result) {
        // interestingly, we lose no efficiency by accepting compressed, because we never have to decompress.
        result = new bytes32[2][](Y.length);
        for (uint256 i = 0; i < Y.length; i++) {
            bytes32 Y_i = Y[i]; // not necessary here, but just for consistency

            Utils.Point[2] memory temp;
            temp[0] = _acc[Y_i][0];
            temp[1] = _acc[Y_i][1];
            if (_lastRollOver[Y_i] < epoch) {
                temp[0] = temp[0].add(_pending[Y_i][0]);
                temp[1] = temp[1].add(_pending[Y_i][1]);
            }
            result[i][0] = Utils.compress(temp[0]);
            result[i][1] = Utils.compress(temp[1]);
        }
    }

    function rollOver(bytes32 Y, uint32 epoch) internal {
        if (_lastRollOver[Y] < epoch) {
            _acc[Y][0] = _acc[Y][0].add(_pending[Y][0]);
            _acc[Y][1] = _acc[Y][1].add(_pending[Y][1]);
            delete _pending[Y]; // pending[Y] = [Utils.G1Point(0, 0), Utils.G1Point(0, 0)];
            _lastRollOver[Y] = epoch;
        }
    }

    function touch(bytes32 Y, uint32 credit, uint32 epoch) internal {
        // could save a few operations if we check for the special case that current.epoch == epoch.
        bytes32[] storage list; // declare here not for efficiency, but to avoid shadowing warning
        Info storage current = info[Y];
        if (current.epoch > 0) { // will only be false for registration...?
            list = lists[current.epoch];
            list[current.index] = list[list.length - 1];
            list.pop();
            if (list.length == 0) remove(current.epoch);
            else if (current.index < list.length) info[list[current.index]].index = current.index;
        }
        current.epoch = epoch;
        if (credit <= 0xFFFFFFFF - current.amount) current.amount += credit;
        else current.amount = 0xFFFFFFFF; // prevent overflow. extremely unlikely that this will ever happen.
        if (!exists(epoch)) {
            insert(epoch);
        }
        list = lists[epoch];
        current.index = uint32(list.length);
        list.push(Y);
    }

    function register(bytes32 Y, bytes32[2] calldata signature, bytes memory backup) external payable {
        require(msg.value == 1e16, "Amount must be 0.010 ETH.");
        require(msg.value % 1e15 == 0, "Must be a multiple of 0.001 ETH.");

        backups[msg.sender] = backup; // WARNING: you can overwrite your own backup if you f___ this up.
        // the UI will check first whether your backup is nonempty, and if it is, prevent you from registering.
        // but there is no prevention on the level of the smart contract.
        // you could overwrite your own backup and lose access to your funds if you really went out of your way to.

        uint32 epoch = uint32(block.timestamp / EPOCH_LENGTH);

        require(address(this).balance <= 1e15 * 0xFFFFFFFF, "Escrow pool now too large.");
        uint32 credit = uint32(msg.value / 1e15); // == 10.
        _pending[Y][0] = _pending[Y][0].add(g().mul(credit)); // convert to uint256?

        require(info[Y].epoch == 0, "Already registered.");
        Utils.Point memory pub = Utils.decompress(Y);
        Utils.Point memory K = g().mul(uint256(signature[1])).add(pub.mul(uint256(signature[0]).neg()));
        uint256 c = uint256(keccak256(abi.encode("Welcome to FIRN", address(this), Y, K))).mod();
        require(bytes32(c) == signature[0], "Signature failed to verify.");
        touch(Y, credit, epoch);

        emit RegisterOccurred(msg.sender, Y);
    }

    function deposit(bytes32[N] calldata Y, bytes32[N] calldata C, bytes32 D, bytes calldata proof) external payable { // bytes32 u, uint32 epoch, uint32 tip
        // not doing a minimum amount here... the idea is that this function can't be used to force your way into the tree.
        require(msg.value % 1e15 == 0, "Must be a multiple of 0.001 ETH.");
        uint32 epoch = uint32(block.timestamp / EPOCH_LENGTH);
        require(address(this).balance <= 1e15 * 0xFFFFFFFF, "Escrow pool now too large.");
        uint32 credit = uint32(msg.value / 1e15); // can't overflow, by the above.

        Utils.Statement memory statement;
        statement.D = Utils.decompress(D);
        for (uint256 i = 0; i < N; i++) {
            bytes32 Y_i = Y[i];
            rollOver(Y_i, epoch);

            statement.Y[i] = Utils.decompress(Y_i);
            statement.C[i] = Utils.decompress(C[i]);
            // mutate their pending, in advance of success.
            _pending[Y_i][0] = _pending[Y_i][0].add(statement.C[i]);
            _pending[Y_i][1] = _pending[Y_i][1].add(statement.D);
            // pending[Y_i] = scratch; // can't do this, so have to use 2 sstores _anyway_ (as in above)
            require(info[Y_i].epoch > 0, "Only cached accounts allowed.");
            touch(Y_i, credit, epoch); // weird question whether this should be 0 or credit... revisit.
        }

        _depositVerifier.verify(credit, statement, Utils.deserializeDeposit(proof));

        emit DepositOccurred(Y, C, D, msg.sender, credit);
    }

    function transfer(bytes32[N] calldata Y, bytes32[N] calldata C, bytes32 D, bytes32 u, uint32 epoch, uint32 tip, bytes calldata proof) external {
        require(epoch == block.timestamp / EPOCH_LENGTH, "Wrong epoch."); // conversion of RHS to uint32 is unnecessary / redundant

        if (_lastGlobalUpdate < epoch) {
            _lastGlobalUpdate = epoch;
            delete _nonces;
        }
        for (uint256 i = 0; i < _nonces.length; i++) {
            require(_nonces[i] != u, "Nonce already seen.");
        }
        _nonces.push(u);

        emit TransferOccurred(Y, C, D);

        Utils.Statement memory statement;
        statement.D = Utils.decompress(D);
        for (uint256 i = 0; i < N; i++) {
            bytes32 Y_i = Y[i];
            rollOver(Y_i, epoch);

            statement.Y[i] = Utils.decompress(Y_i);
            statement.C[i] = Utils.decompress(C[i]);
            statement.CLn[i] = _acc[Y_i][0].add(statement.C[i]);
            statement.CRn[i] = _acc[Y_i][1].add(statement.D);
            // mutate their pending, in advance of success.
            _pending[Y_i][0] = _pending[Y_i][0].add(statement.C[i]);
            _pending[Y_i][1] = _pending[Y_i][1].add(statement.D);
            // pending[Y_i] = scratch; // can't do this, so have to use 2 sstores _anyway_ (as in above)
            require(info[Y_i].epoch > 0, "Only cached accounts allowed.");
            touch(Y_i, 0, epoch);
        }
        statement.epoch = epoch;
        statement.u = Utils.decompress(u);
        statement.fee = tip;

        _transferVerifier.verify(statement, Utils.deserializeTransfer(proof));

        payable(msg.sender).transfer(uint256(tip) * 1e15);
    }

    function withdraw(bytes32[N] calldata Y, bytes32[N] calldata C, bytes32 D, bytes32 u, uint32 epoch, uint32 amount, uint32 tip, bytes calldata proof, address destination, bytes calldata data) external {
        require(epoch == block.timestamp / EPOCH_LENGTH, "Wrong epoch."); // conversion of RHS to uint32 is unnecessary. // could supply epoch ourselves; check early to save gas

        if (_lastGlobalUpdate < epoch) {
            _lastGlobalUpdate = epoch;
            delete _nonces;
        }
        for (uint256 i = 0; i < _nonces.length; i++) {
            require(_nonces[i] != u, "Nonce already seen.");
        }
        _nonces.push(u);

        emit WithdrawalOccurred(Y, C, D, amount, destination, data); // emit here, because of stacktoodeep.

        Utils.Statement memory statement;
        statement.D = Utils.decompress(D);
        for (uint256 i = 0; i < N; i++) {
            bytes32 Y_i = Y[i]; // this is actually necessary to prevent stacktoodeep in the below.
            rollOver(Y_i, epoch);

            statement.Y[i] = Utils.decompress(Y_i);
            statement.C[i] = Utils.decompress(C[i]);
            statement.CLn[i] = _acc[Y_i][0].add(statement.C[i]);
            statement.CRn[i] = _acc[Y_i][1].add(statement.D);
            // mutate their pending, in advance of success.
            _pending[Y_i][0] = _pending[Y_i][0].add(statement.C[i]);
            _pending[Y_i][1] = _pending[Y_i][1].add(statement.D);
            // pending[Y[i]] = scratch; // can't do this, so have to use 2 sstores _anyway_ (as in above)
            require(info[Y_i].epoch > 0, "Only cached accounts allowed.");
        }
        uint32 burn = amount >> _fee;
        statement.epoch = epoch; // implicit conversion to uint256
        statement.u = Utils.decompress(u);
        statement.fee = tip + burn; // implicit conversion to uint256

        uint256 salt = uint256(keccak256(abi.encode(destination, data))); // .mod();
        _withdrawalVerifier.verify(amount, statement, Utils.deserializeWithdrawal(proof), salt);

        payable(msg.sender).transfer(uint256(tip) * 1e15);
//        payable(treasury).transfer(uint256(burn) * 1e15);
        // send the burn---with an arbitrary amount of gas (!) to `treasury`, with no calldata.
        (bool success,) = payable(_treasury).call{value: uint256(burn) * 1e15}("");
        require(success, "External treasury call failed.");
        (success,) = payable(destination).call{value: uint256(amount) * 1e15}(data);
        require(success, "External withdrawal call failed.");
    }
}