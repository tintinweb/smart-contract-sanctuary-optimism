// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "../utils/Owned.sol";
import "@openzeppelin/contracts-4.4.1/utils/cryptography/MerkleProof.sol";
import "../utils/Pausable.sol";

/**
 * Contract which implements a merkle airdrop for a given token
 * Based on an account balance snapshot stored in a merkle tree
 */
contract Airdrop is Owned, Pausable {
    IERC20 public token;

    bytes32 public root; // merkle tree root

    uint256 public startTime;

    mapping(uint256 => uint256) public _claimed;

    constructor(
        address _owner,
        IERC20 _token,
        bytes32 _root
    ) Owned(_owner) Pausable() {
        token = _token;
        root = _root;
        startTime = block.timestamp;
    }

    // Check if a given reward has already been claimed
    function claimed(uint256 index) public view returns (uint256 claimedBlock, uint256 claimedMask) {
        claimedBlock = _claimed[index / 256];
        claimedMask = (uint256(1) << uint256(index % 256));
        require((claimedBlock & claimedMask) == 0, "Tokens have already been claimed");
    }

    // helper for the dapp
    function canClaim(uint256 index) external view returns (bool) {
        uint256 claimedBlock = _claimed[index / 256];
        uint256 claimedMask = (uint256(1) << uint256(index % 256));
        return ((claimedBlock & claimedMask) == 0);
    }

    // Get airdrop tokens assigned to address
    // Requires sending merkle proof to the function
    function claim(
        uint256 index,
        uint256 amount,
        bytes32[] memory merkleProof
    ) public notPaused {
        require(token.balanceOf(address(this)) > amount, "Contract doesnt have enough tokens");

        // Make sure the tokens have not already been redeemed
        (uint256 claimedBlock, uint256 claimedMask) = claimed(index);
        _claimed[index / 256] = claimedBlock | claimedMask;

        // Compute the merkle leaf from index, recipient and amount
        bytes32 leaf = keccak256(abi.encodePacked(index, msg.sender, amount));
        // verify the proof is valid
        require(MerkleProof.verify(merkleProof, root, leaf), "Proof is not valid");
        // Redeem!
        token.transfer(msg.sender, amount);
        emit Claim(msg.sender, amount, block.timestamp);
    }

    function _selfDestruct(address payable beneficiary) external onlyOwner {
        token.transfer(beneficiary, token.balanceOf(address(this)));
        selfdestruct(beneficiary);
    }

    event Claim(address claimer, uint256 amount, uint timestamp);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merklee tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        return computedHash;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
// Inheritance
import "./Owned.sol";

abstract contract Pausable is Owned {
    uint public lastPauseTime;
    bool public paused;

    constructor() {
        // This contract is abstract, and thus cannot be instantiated directly
        require(owner != address(0), "Owner must be set");
        // Paused will be false, and lastPauseTime will be 0 upon initialisation
    }

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "../utils/Owned.sol";
import "@openzeppelin/contracts-4.4.1/utils/cryptography/MerkleProof.sol";
import "../utils/Pausable.sol";
import "../interfaces/IEscrowThales.sol";

/**
 * Contract which implements a merkle airdrop for a given token
 * Based on an account balance snapshot stored in a merkle tree
 */
contract OngoingAirdrop is Owned, Pausable {
    IERC20 public token;

    IEscrowThales public iEscrowThales;

    bytes32 public root; // merkle tree root

    uint256 public startTime;

    address public admin;

    uint256 public period;

    mapping(uint256 => mapping(uint256 => uint256)) public _claimed;

    constructor(
        address _owner,
        IERC20 _token,
        bytes32 _root
    ) Owned(_owner) Pausable() {
        token = _token;
        root = _root;
        startTime = block.timestamp;
        period = 1;
    }

    // Set root of merkle tree
    function setRoot(bytes32 _root) public onlyOwner {
        require(address(iEscrowThales) != address(0), "Set Escrow Thales address");
        root = _root;
        startTime = block.timestamp; //reset time every period
        emit NewRoot(_root, block.timestamp, period);
        period = period + 1;
    }

    // Set EscrowThales contract address
    function setEscrow(address _escrowThalesContract) public onlyOwner {
        if (address(iEscrowThales) != address(0)) {
            token.approve(address(iEscrowThales), 0);
        }
        iEscrowThales = IEscrowThales(_escrowThalesContract);
        token.approve(_escrowThalesContract, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }

    // Check if a given reward has already been claimed
    function claimed(uint256 index) public view returns (uint256 claimedBlock, uint256 claimedMask) {
        claimedBlock = _claimed[period][index / 256];
        claimedMask = (uint256(1) << uint256(index % 256));
        require((claimedBlock & claimedMask) == 0, "Tokens have already been claimed");
    }

    // helper for the dapp
    function canClaim(uint256 index) external view returns (bool) {
        uint256 claimedBlock = _claimed[period][index / 256];
        uint256 claimedMask = (uint256(1) << uint256(index % 256));
        return ((claimedBlock & claimedMask) == 0);
    }

    // Get airdrop tokens assigned to address
    // Requires sending merkle proof to the function
    function claim(
        uint256 index,
        uint256 amount,
        bytes32[] memory merkleProof
    ) public notPaused {
        // Make sure the tokens have not already been redeemed
        (uint256 claimedBlock, uint256 claimedMask) = claimed(index);
        _claimed[period][index / 256] = claimedBlock | claimedMask;

        // Compute the merkle leaf from index, recipient and amount
        bytes32 leaf = keccak256(abi.encodePacked(index, msg.sender, amount));
        // verify the proof is valid
        require(MerkleProof.verify(merkleProof, root, leaf), "Proof is not valid");

        // Send to EscrowThales contract
        iEscrowThales.addToEscrow(msg.sender, amount);

        emit Claim(msg.sender, amount, block.timestamp);
    }

    function _selfDestruct(address payable beneficiary) external onlyOwner {
        token.transfer(beneficiary, token.balanceOf(address(this)));
        selfdestruct(beneficiary);
    }

    event Claim(address claimer, uint256 amount, uint timestamp);
    event NewRoot(bytes32 root, uint timestamp, uint256 period);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IEscrowThales {
    /* ========== VIEWS / VARIABLES ========== */
    function getStakerPeriod(address account, uint index) external view returns (uint);

    function getStakerAmounts(address account, uint index) external view returns (uint);

    function totalAccountEscrowedAmount(address account) external view returns (uint);

    function getStakedEscrowedBalanceForRewards(address account) external view returns (uint);

    function totalEscrowedRewards() external view returns (uint);

    function totalEscrowBalanceNotIncludedInStaking() external view returns (uint);

    function currentVestingPeriod() external view returns (uint);

    function updateCurrentPeriod() external returns (bool);

    function claimable(address account) external view returns (uint);

    function addToEscrow(address account, uint amount) external;

    function vest(uint amount) external returns (bool);

    function addTotalEscrowBalanceNotIncludedInStaking(uint amount) external;

    function subtractTotalEscrowBalanceNotIncludedInStaking(uint amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IStakingThales {
    function updateVolume(address account, uint amount) external;
    
    /* ========== VIEWS / VARIABLES ========== */
    function totalStakedAmount() external view returns (uint);

    function stakedBalanceOf(address account) external view returns (uint); 

    function currentPeriodRewards() external view returns (uint);

    function currentPeriodFees() external view returns (uint);

    function getLastPeriodOfClaimedRewards(address account) external view returns (uint);

    function getRewardsAvailable(address account) external view returns (uint);

    function getRewardFeesAvailable(address account) external view returns (uint);

    function getAlreadyClaimedRewards(address account) external view returns (uint);

    function getAlreadyClaimedFees(address account) external view returns (uint);

    function getContractRewardFunds() external view returns (uint);

    function getContractFeeFunds() external view returns (uint);

    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

// interface
import "../interfaces/ISportPositionalMarket.sol";
import "../interfaces/ISportPositionalMarketManager.sol";
import "../interfaces/IPosition.sol";
import "../interfaces/IStakingThales.sol";
import "../interfaces/ITherundownConsumer.sol";
import "../interfaces/ICurveSUSD.sol";

/// @title Sports AMM contract
/// @author kirilaa
contract SportsAMM is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct GameOdds {
        bytes32 gameId;
        int24 homeOdds;
        int24 awayOdds;
        int24 drawOdds;
    }

    uint private constant ONE = 1e18;
    uint private constant ZERO_POINT_ONE = 1e17;
    uint private constant ONE_PERCENT = 1e16;
    uint private constant MAX_APPROVAL = type(uint256).max;

    /// @return The sUSD contract used for payment
    IERC20Upgradeable public sUSD;

    /// @return The address of the SportsPositionalManager contract
    address public manager;

    /// @notice Each game has `defaultCapPerGame` available for trading
    /// @return The default cap per game.
    uint public defaultCapPerGame;

    /// @return The minimal spread/skrew percentage
    uint public min_spread;

    /// @return The maximum spread/skrew percentage
    uint public max_spread;

    /// @notice Each game will be restricted for AMM trading `minimalTimeLeftToMaturity` seconds before is mature
    /// @return The period of time before a game is matured and begins to be restricted for AMM trading
    uint public minimalTimeLeftToMaturity;

    enum Position {Home, Away, Draw}

    /// @return The sUSD amount bought from AMM by users for the market
    mapping(address => uint) public spentOnGame;

    /// @return The SafeBox address
    address public safeBox;

    /// @return The address of Therundown Consumer
    address public theRundownConsumer;

    /// @return The percentage that goes to SafeBox
    uint public safeBoxImpact;

    /// @return The address of the Staking contract
    IStakingThales public stakingThales;

    /// @return The minimum supported odd
    uint public minSupportedOdds;

    /// @return The maximum supported odd
    uint public maxSupportedOdds;

    /// @return The address of the Curve contract for multi-collateral
    ICurveSUSD public curveSUSD;

    /// @return The address of USDC
    address public usdc;

    /// @return The address of USDT (Tether)
    address public usdt;

    /// @return The address of DAI
    address public dai;

    /// @return Curve usage is enabled?
    bool public curveOnrampEnabled;

    /// @notice Initialize the storage in the proxy contract with the parameters.
    /// @param _owner Owner for using the ownerOnly functions
    /// @param _sUSD The payment token (sUSD)
    /// @param _min_spread Minimal spread (percentage)
    /// @param _max_spread Maximum spread (percentage)
    /// @param _minimalTimeLeftToMaturity Period to close AMM trading befor maturity
    function initialize(
        address _owner,
        IERC20Upgradeable _sUSD,
        uint _defaultCapPerGame,
        uint _min_spread,
        uint _max_spread,
        uint _minimalTimeLeftToMaturity
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        sUSD = _sUSD;
        defaultCapPerGame = _defaultCapPerGame;
        min_spread = _min_spread;
        max_spread = _max_spread;
        minimalTimeLeftToMaturity = _minimalTimeLeftToMaturity;
    }

    /// @notice Returns the available position options to buy from AMM for specific market/game
    /// @param market The address of the SportPositional market created for a game
    /// @param position The position (home/away/draw) to check availability
    /// @return The amount of position options (tokens) available to buy from AMM.
    function availableToBuyFromAMM(address market, Position position) public view returns (uint) {
        if (isMarketInAMMTrading(market)) {
            uint baseOdds = obtainOdds(market, position);
            // ignore extremes
            if (baseOdds <= minSupportedOdds || baseOdds >= maxSupportedOdds) {
                return 0;
            }
            baseOdds = baseOdds.add(min_spread);
            uint balance = _balanceOfPositionOnMarket(market, position);
            uint midImpactPriceIncrease = ONE.sub(baseOdds).mul(max_spread.div(2)).div(ONE);

            uint divider_price = ONE.sub(baseOdds.add(midImpactPriceIncrease));

            uint additionalBufferFromSelling = balance.mul(baseOdds).div(ONE);

            if (defaultCapPerGame.add(additionalBufferFromSelling) <= spentOnGame[market]) {
                return 0;
            }
            uint availableUntilCapSUSD = defaultCapPerGame.add(additionalBufferFromSelling).sub(spentOnGame[market]);

            return balance.add(availableUntilCapSUSD.mul(ONE).div(divider_price));
        } else {
            return 0;
        }
    }

    /// @notice Calculate the sUSD cost to buy an amount of available position options from AMM for specific market/game
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) quoted to buy from AMM
    /// @param amount The position amount quoted to buy from AMM
    /// @return The sUSD cost for buying the `amount` of `position` options (tokens) from AMM for `market`.
    function buyFromAmmQuote(
        address market,
        Position position,
        uint amount
    ) public view returns (uint) {
        if (amount < 1 || amount > availableToBuyFromAMM(market, position)) {
            return 0;
        }
        uint baseOdds = obtainOdds(market, position).add(min_spread);
        uint impactPriceIncrease = ONE.sub(baseOdds).mul(_buyPriceImpact(market, position, amount)).div(ONE);
        // add 2% to the price increase to avoid edge cases on the extremes
        impactPriceIncrease = impactPriceIncrease.mul(ONE.add(ONE_PERCENT * 2)).div(ONE);
        uint tempAmount = amount.mul(baseOdds.add(impactPriceIncrease)).div(ONE);
        uint returnQuote = tempAmount.mul(ONE.add(safeBoxImpact)).div(ONE);
        return ISportPositionalMarketManager(manager).transformCollateral(returnQuote);
    }

    /// @notice Calculate the sUSD cost to buy an amount of available position options from AMM for specific market/game
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) quoted to buy from AMM
    /// @param amount The position amount quoted to buy from AMM
    /// @param collateral The position amount quoted to buy from AMM
    /// @return collateralQuote The sUSD cost for buying the `amount` of `position` options (tokens) from AMM for `market`.
    /// @return sUSDToPay The sUSD cost for buying the `amount` of `position` options (tokens) from AMM for `market`.
    function buyFromAmmQuoteWithDifferentCollateral(
        address market,
        Position position,
        uint amount,
        address collateral
    ) public view returns (uint collateralQuote, uint sUSDToPay) {
        int128 curveIndex = _mapCollateralToCurveIndex(collateral);
        if (curveIndex == 0 || !curveOnrampEnabled) {
            return (0, 0);
        }

        sUSDToPay = buyFromAmmQuote(market, position, amount);
        //cant get a quote on how much collateral is needed from curve for sUSD,
        //so rather get how much of collateral you get for the sUSD quote and add 0.2% to that
        collateralQuote = curveSUSD.get_dy_underlying(0, curveIndex, sUSDToPay).mul(ONE.add(ONE_PERCENT.div(5))).div(ONE);
    }

    /// @notice Calculates the buy price impact for given position amount. Changes with every new purchase.
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) for which the buy price impact is calculated
    /// @param amount The position amount to calculate the buy price impact
    /// @return The buy price impact after the buy of the amount of positions for market
    function buyPriceImpact(
        address market,
        Position position,
        uint amount
    ) public view returns (uint) {
        if (amount < 1 || amount > availableToBuyFromAMM(market, position)) {
            return 0;
        }
        return _buyPriceImpact(market, position, amount);
    }

    /// @notice Calculate the maximum position amount available to sell to AMM for specific market/game
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) to sell to AMM
    /// @return The maximum amount available to be sold to AMM
    function availableToSellToAMM(address market, Position position) public view returns (uint) {
        if (isMarketInAMMTrading(market)) {
            uint sell_max_price = _getSellMaxPrice(market, position);
            if (sell_max_price == 0) {
                return 0;
            }
            (IPosition home, IPosition away, IPosition draw) = ISportPositionalMarket(market).getOptions();
            uint balanceOfTheOtherSide =
                position == Position.Home ? away.getBalanceOf(address(this)) : home.getBalanceOf(address(this));

            // Balancing with three positions needs to be elaborated
            if (ISportPositionalMarket(market).optionsCount() == 3) {
                uint homeBalance = home.getBalanceOf(address(this));
                uint awayBalance = away.getBalanceOf(address(this));
                uint drawBalance = draw.getBalanceOf(address(this));
                if (position == Position.Home) {
                    balanceOfTheOtherSide = awayBalance < drawBalance ? awayBalance : drawBalance;
                } else if (position == Position.Away) {
                    balanceOfTheOtherSide = homeBalance < drawBalance ? homeBalance : drawBalance;
                } else {
                    balanceOfTheOtherSide = homeBalance < awayBalance ? homeBalance : awayBalance;
                }
            }

            // can burn straight away balanceOfTheOtherSide
            uint willPay = balanceOfTheOtherSide.mul(sell_max_price).div(ONE);
            uint capPlusBalance = defaultCapPerGame.add(balanceOfTheOtherSide);
            if (capPlusBalance < spentOnGame[market].add(willPay)) {
                return 0;
            }
            uint usdAvailable = capPlusBalance.sub(spentOnGame[market]).sub(willPay);
            return usdAvailable.div(sell_max_price).mul(ONE).add(balanceOfTheOtherSide);
        } else return 0;
    }

    function _getSellMaxPrice(address market, Position position) internal view returns (uint) {
        uint baseOdds = obtainOdds(market, position);
        // ignore extremes
        if (baseOdds <= minSupportedOdds || baseOdds >= maxSupportedOdds) {
            return 0;
        }
        uint sell_max_price = baseOdds.sub(min_spread).mul(ONE.sub(max_spread.div(2))).div(ONE);
        return sell_max_price;
    }

    /// @notice Calculate the sUSD to receive for selling the position amount to AMM for specific market/game
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) to sell to AMM
    /// @param amount The position amount to sell to AMM
    /// @return The sUSD to receive for the `amount` of `position` options if sold to AMM for `market`
    function sellToAmmQuote(
        address market,
        Position position,
        uint amount
    ) public view returns (uint) {
        if (amount > availableToSellToAMM(market, position)) {
            return 0;
        }
        uint baseOdds = obtainOdds(market, position).sub(min_spread);

        uint tempAmount = amount.mul(baseOdds.mul(ONE.sub(_sellPriceImpact(market, position, amount))).div(ONE)).div(ONE);

        uint returnQuote = tempAmount.mul(ONE.sub(safeBoxImpact)).div(ONE);
        return ISportPositionalMarketManager(manager).transformCollateral(returnQuote);
    }

    /// @notice Calculates the sell price impact for given position amount. Changes with every new sell.
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) to sell to AMM
    /// @param amount The position amount to sell to AMM
    /// @return The price impact after selling the position amount to AMM
    function sellPriceImpact(
        address market,
        Position position,
        uint amount
    ) public view returns (uint) {
        if (amount > availableToSellToAMM(market, position)) {
            return 0;
        }
        return _sellPriceImpact(market, position, amount);
    }

    /// @notice Obtains the oracle odds for `_position` of a given `_market` game. Odds do not contain price impact
    /// @param _market The address of the SportPositional market of a game
    /// @param _position The position (home/away/draw) to get the odds
    /// @return The oracle odds for `_position` of a `_market`
    function obtainOdds(address _market, Position _position) public view returns (uint) {
        bytes32 gameId = ISportPositionalMarket(_market).getGameId();
        if (ISportPositionalMarket(_market).optionsCount() > uint(_position)) {
            uint[] memory odds = new uint[](ISportPositionalMarket(_market).optionsCount());
            odds = ITherundownConsumer(theRundownConsumer).getNormalizedOdds(gameId);
            return odds[uint(_position)];
        } else {
            return 0;
        }
    }

    /// @notice Checks if a `market` is active for AMM trading
    /// @param market The address of the SportPositional market of a game
    /// @return Returns true if market is active, returns false if not active.
    function isMarketInAMMTrading(address market) public view returns (bool) {
        if (ISportPositionalMarketManager(manager).isActiveMarket(market)) {
            (uint maturity, ) = ISportPositionalMarket(market).times();
            if (maturity < block.timestamp) {
                return false;
            }

            uint timeLeftToMaturity = maturity - block.timestamp;
            return timeLeftToMaturity > minimalTimeLeftToMaturity;
        } else {
            return false;
        }
    }

    /// @notice Checks if a `market` options can be excercised. Winners get the full options amount 1 option = 1 sUSD.
    /// @param market The address of the SportPositional market of a game
    /// @return Returns true if market can be exercised, returns false market can not be exercised.
    function canExerciseMaturedMarket(address market) public view returns (bool) {
        if (ISportPositionalMarketManager(manager).isKnownMarket(market) && ISportPositionalMarket(market).resolved()) {
            (IPosition home, IPosition away, IPosition draw) = ISportPositionalMarket(market).getOptions();
            if (
                (home.getBalanceOf(address(this)) > 0) ||
                (away.getBalanceOf(address(this)) > 0) ||
                (draw.getBalanceOf(address(this)) > 0)
            ) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks the default odds for a `_market`. These odds take into account the price impact.
    /// @param _market The address of the SportPositional market of a game
    /// @param isSell The address of the SportPositional market of a game
    /// @return Returns the default odds for the `_market` including the price impact.
    function getMarketDefaultOdds(address _market, bool isSell) public view returns (uint[] memory) {
        uint[] memory odds = new uint[](ISportPositionalMarket(_market).optionsCount());
        if (isMarketInAMMTrading(_market)) {
            Position position;
            for (uint i = 0; i < odds.length; i++) {
                if (i == 0) {
                    position = Position.Home;
                } else if (i == 1) {
                    position = Position.Away;
                } else {
                    position = Position.Draw;
                }
                if (isSell) {
                    odds[i] = sellToAmmQuote(_market, position, ONE);
                } else {
                    odds[i] = buyFromAmmQuote(_market, position, ONE);
                }
            }
        }
        return odds;
    }

    // write methods

    /// @notice Buy amount of position for market/game from AMM using different collateral
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) to buy from AMM
    /// @param amount The position amount to buy from AMM
    /// @param expectedPayout The amount expected to pay in sUSD for the amount of position. Obtained by buyAMMQuote.
    /// @param additionalSlippage The slippage percentage for the payout
    /// @param collateral The address of the collateral used
    function buyFromAMMWithDifferentCollateral(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage,
        address collateral
    ) public nonReentrant whenNotPaused {
        int128 curveIndex = _mapCollateralToCurveIndex(collateral);
        require(curveIndex > 0 && curveOnrampEnabled, "Unsupported collateral");

        (uint collateralQuote, uint susdQuote) =
            buyFromAmmQuoteWithDifferentCollateral(market, position, amount, collateral);

        require(collateralQuote.mul(ONE).div(expectedPayout) <= ONE.add(additionalSlippage), "Slippage too high!");

        IERC20Upgradeable collateralToken = IERC20Upgradeable(collateral);
        collateralToken.safeTransferFrom(msg.sender, address(this), collateralQuote);
        curveSUSD.exchange_underlying(curveIndex, 0, collateralQuote, susdQuote);

        _buyFromAMM(market, position, amount, susdQuote, additionalSlippage, false, susdQuote);
    }

    /// @notice Buy amount of position for market/game from AMM using sUSD
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) to buy from AMM
    /// @param amount The position amount to buy from AMM
    /// @param expectedPayout The sUSD amount expected to pay for buyuing the position amount. Obtained by buyAMMQuote.
    /// @param additionalSlippage The slippage percentage for the payout
    function buyFromAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) public nonReentrant whenNotPaused {
        _buyFromAMM(market, position, amount, expectedPayout, additionalSlippage, true, 0);
    }

    function _buyFromAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage,
        bool sendSUSD,
        uint sUSDPaid
    ) internal {
        require(isMarketInAMMTrading(market), "Market is not in Trading phase");
        require(ISportPositionalMarket(market).optionsCount() > uint(position), "Invalid position");
        uint availableToBuyFromAMMatm = availableToBuyFromAMM(market, position);
        require(amount > ZERO_POINT_ONE && amount <= availableToBuyFromAMMatm, "Not enough liquidity or zero amount.");

        if (sendSUSD) {
            sUSDPaid = buyFromAmmQuote(market, position, amount);
            require(sUSD.balanceOf(msg.sender) >= sUSDPaid, "You dont have enough sUSD.");
            require(sUSD.allowance(msg.sender, address(this)) >= sUSDPaid, "No allowance.");
            require(sUSDPaid.mul(ONE).div(expectedPayout) <= ONE.add(additionalSlippage), "Slippage too high");
            sUSD.safeTransferFrom(msg.sender, address(this), sUSDPaid);
        }

        uint toMint = _getMintableAmount(market, position, amount);
        if (toMint > 0) {
            require(
                sUSD.balanceOf(address(this)) >= ISportPositionalMarketManager(manager).transformCollateral(toMint),
                "Not enough sUSD in contract."
            );
            ISportPositionalMarket(market).mint(toMint);
            spentOnGame[market] = spentOnGame[market].add(toMint);
        }
        (IPosition home, IPosition away, IPosition draw) = ISportPositionalMarket(market).getOptions();
        IPosition target = position == Position.Home ? home : away;
        if (ISportPositionalMarket(market).optionsCount() > 2 && position != Position.Home) {
            target = position == Position.Away ? away : draw;
        }

        IERC20Upgradeable(address(target)).safeTransfer(msg.sender, amount);

        if (address(stakingThales) != address(0)) {
            stakingThales.updateVolume(msg.sender, sUSDPaid);
        }
        _updateSpentOnOnMarketOnBuy(market, position, amount, sUSDPaid);

        emit BoughtFromAmm(msg.sender, market, position, amount, sUSDPaid, address(sUSD), address(target));
    }

    /// @notice Sell amount of position for market/game to AMM
    /// @param market The address of the SportPositional market of a game
    /// @param position The position (home/away/draw) to buy from AMM
    /// @param amount The position amount to buy from AMM
    /// @param expectedPayout The sUSD amount expected to receive for selling the position amount. Obtained by sellToAMMQuote.
    /// @param additionalSlippage The slippage percentage for the payout
    function sellToAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) public nonReentrant whenNotPaused {
        require(isMarketInAMMTrading(market), "Market is not in Trading phase");
        require(ISportPositionalMarket(market).optionsCount() > uint(position), "Invalid position");
        uint availableToSellToAMMATM = availableToSellToAMM(market, position);
        require(
            availableToSellToAMMATM > 0 && amount > ZERO_POINT_ONE && amount <= availableToSellToAMMATM,
            "Not enough liquidity or zero amount.."
        );

        uint pricePaid = sellToAmmQuote(market, position, amount);
        require(expectedPayout.mul(ONE).div(pricePaid) <= (ONE.add(additionalSlippage)), "Slippage too high");

        (IPosition home, IPosition away, IPosition draw) = ISportPositionalMarket(market).getOptions();
        IPosition target = position == Position.Home ? home : away;
        if (ISportPositionalMarket(market).optionsCount() > 2 && position != Position.Home) {
            target = position == Position.Away ? away : draw;
        }

        require(target.getBalanceOf(msg.sender) >= amount, "You dont have enough options.");
        require(IERC20Upgradeable(address(target)).allowance(msg.sender, address(this)) >= amount, "No allowance.");

        //transfer options first to have max burn available
        IERC20Upgradeable(address(target)).safeTransferFrom(msg.sender, address(this), amount);
        uint sUSDFromBurning =
            ISportPositionalMarketManager(manager).transformCollateral(
                ISportPositionalMarket(market).getMaximumBurnable(address(this))
            );
        if (sUSDFromBurning > 0) {
            ISportPositionalMarket(market).burnOptionsMaximum();
        }

        require(sUSD.balanceOf(address(this)) >= pricePaid, "Not enough sUSD in contract.");

        sUSD.safeTransfer(msg.sender, pricePaid);

        if (address(stakingThales) != address(0)) {
            stakingThales.updateVolume(msg.sender, pricePaid);
        }
        _updateSpentOnMarketOnSell(market, position, amount, pricePaid, sUSDFromBurning);

        emit SoldToAMM(msg.sender, market, position, amount, pricePaid, address(sUSD), address(target));
    }

    function exerciseMaturedMarket(address market) external {
        require(canExerciseMaturedMarket(market), "No options to exercise");
        ISportPositionalMarket(market).exerciseOptions();
    }

    // setters

    /// @notice Setting the minimal time left until the market is active for AMM trading, before the market is mature.
    /// @param _minimalTimeLeftToMaturity The time period in seconds.
    function setMinimalTimeLeftToMaturity(uint _minimalTimeLeftToMaturity) public onlyOwner {
        minimalTimeLeftToMaturity = _minimalTimeLeftToMaturity;
        emit SetMinimalTimeLeftToMaturity(_minimalTimeLeftToMaturity);
    }

    /// @notice Setting the minimal spread amount
    /// @param _spread Percentage expressed in ether unit (uses 18 decimals -> 1% = 0.01*1e18)
    function setMinSpread(uint _spread) public onlyOwner {
        min_spread = _spread;
        emit SetMinSpread(_spread);
    }

    /// @notice Setting the safeBox price impact
    /// @param _safeBoxImpact Percentage expressed in ether unit (uses 18 decimals -> 1% = 0.01*1e18)
    function setSafeBoxImpact(uint _safeBoxImpact) public onlyOwner {
        safeBoxImpact = _safeBoxImpact;
        emit SetSafeBoxImpact(_safeBoxImpact);
    }

    /// @notice Setting the safeBox address
    /// @param _safeBox Address of the Safe Box
    function setSafeBox(address _safeBox) public onlyOwner {
        safeBox = _safeBox;
        emit SetSafeBox(_safeBox);
    }

    /// @notice Setting the maximum spread amount
    /// @param _spread Percentage expressed in ether unit (uses 18 decimals -> 1% = 0.01*1e18)
    function setMaxSpread(uint _spread) public onlyOwner {
        max_spread = _spread;
        emit SetMaxSpread(_spread);
    }

    /// @notice Setting the minimum supported oracle odd.
    /// @param _minSupportedOdds Minimal oracle odd in ether unit (18 decimals)
    function setMinSupportedOdds(uint _minSupportedOdds) public onlyOwner {
        minSupportedOdds = _minSupportedOdds;
        emit SetMinSupportedOdds(_minSupportedOdds);
    }

    /// @notice Setting the maximum supported oracle odds.
    /// @param _maxSupportedOdds Maximum oracle odds in ether unit (18 decimals)
    function setMaxSupportedOdds(uint _maxSupportedOdds) public onlyOwner {
        maxSupportedOdds = _maxSupportedOdds;
        emit SetMaxSupportedOdds(_maxSupportedOdds);
    }

    /// @notice Setting the default cap in sUSD for each market/game
    /// @param _defaultCapPerGame Default sUSD cap per market (18 decimals)
    function setDefaultCapPerGame(uint _defaultCapPerGame) public onlyOwner {
        defaultCapPerGame = _defaultCapPerGame;
        emit SetDefaultCapPerGame(_defaultCapPerGame);
    }

    /// @notice Setting the sUSD address
    /// @param _sUSD Address of the sUSD
    function setSUSD(IERC20Upgradeable _sUSD) public onlyOwner {
        sUSD = _sUSD;
        emit SetSUSD(address(sUSD));
    }

    /// @notice Setting Therundown consumer address
    /// @param _theRundownConsumer Address of Therundown consumer
    function setTherundownConsumer(address _theRundownConsumer) public onlyOwner {
        theRundownConsumer = _theRundownConsumer;
        emit SetTherundownConsumer(_theRundownConsumer);
    }

    /// @notice Setting Staking contract address
    /// @param _stakingThales Address of Staking contract
    function setStakingThales(IStakingThales _stakingThales) public onlyOwner {
        stakingThales = _stakingThales;
        emit SetStakingThales(address(_stakingThales));
    }

    /// @notice Setting the Sport Positional Manager contract address
    /// @param _manager Address of Staking contract
    function setSportsPositionalMarketManager(address _manager) public onlyOwner {
        if (address(_manager) != address(0)) {
            sUSD.approve(address(_manager), 0);
        }
        manager = _manager;
        sUSD.approve(manager, MAX_APPROVAL);
        emit SetSportsPositionalMarketManager(_manager);
    }

    /// @notice Setting the Curve collateral addresses for all collaterals
    /// @param _curveSUSD Address of the Curve contract
    /// @param _dai Address of the DAI contract
    /// @param _usdc Address of the USDC contract
    /// @param _usdt Address of the USDT (Tether) contract
    /// @param _curveOnrampEnabled Enabling or restricting the use of multicollateral
    function setCurveSUSD(
        address _curveSUSD,
        address _dai,
        address _usdc,
        address _usdt,
        bool _curveOnrampEnabled
    ) external onlyOwner {
        curveSUSD = ICurveSUSD(_curveSUSD);
        dai = _dai;
        usdc = _usdc;
        usdt = _usdt;
        IERC20Upgradeable(dai).approve(_curveSUSD, MAX_APPROVAL);
        IERC20Upgradeable(usdc).approve(_curveSUSD, MAX_APPROVAL);
        IERC20Upgradeable(usdt).approve(_curveSUSD, MAX_APPROVAL);
        // not needed unless selling into different collateral is enabled
        //sUSD.approve(_curveSUSD, MAX_APPROVAL);
        curveOnrampEnabled = _curveOnrampEnabled;
    }

    // Internal

    function _updateSpentOnMarketOnSell(
        address market,
        Position position,
        uint amount,
        uint sUSDPaid,
        uint sUSDFromBurning
    ) internal {
        uint safeBoxShare = sUSDPaid.mul(ONE).div(ONE.sub(safeBoxImpact)).sub(sUSDPaid);

        if (safeBoxImpact > 0) {
            sUSD.safeTransfer(safeBox, safeBoxShare);
        } else {
            safeBoxShare = 0;
        }

        spentOnGame[market] = spentOnGame[market].add(
            ISportPositionalMarketManager(manager).reverseTransformCollateral(sUSDPaid.add(safeBoxShare))
        );
        if (spentOnGame[market] <= ISportPositionalMarketManager(manager).reverseTransformCollateral(sUSDFromBurning)) {
            spentOnGame[market] = 0;
        } else {
            spentOnGame[market] = spentOnGame[market].sub(
                ISportPositionalMarketManager(manager).reverseTransformCollateral(sUSDFromBurning)
            );
        }
    }

    function _updateSpentOnOnMarketOnBuy(
        address market,
        Position position,
        uint amount,
        uint sUSDPaid
    ) internal {
        uint safeBoxShare = sUSDPaid.sub(sUSDPaid.mul(ONE).div(ONE.add(safeBoxImpact)));
        if (safeBoxImpact > 0) {
            sUSD.safeTransfer(safeBox, safeBoxShare);
        } else {
            safeBoxShare = 0;
        }

        if (
            spentOnGame[market] <=
            ISportPositionalMarketManager(manager).reverseTransformCollateral(sUSDPaid.sub(safeBoxShare))
        ) {
            spentOnGame[market] = 0;
        } else {
            spentOnGame[market] = spentOnGame[market].sub(
                ISportPositionalMarketManager(manager).reverseTransformCollateral(sUSDPaid.sub(safeBoxShare))
            );
        }
    }

    function _buyPriceImpact(
        address market,
        Position position,
        uint amount
    ) internal view returns (uint) {
        // take the balanceOtherSideMaximum
        (uint balancePosition, uint balanceOtherSide, ) = _balanceOfPositionsOnMarket(market, position);
        uint balancePositionAfter = balancePosition > amount ? balancePosition.sub(amount) : 0;
        uint balanceOtherSideAfter =
            balancePosition > amount ? balanceOtherSide : balanceOtherSide.add(amount.sub(balancePosition));

        if (balancePosition >= amount) {
            //minimal price impact as it will balance the AMM exposure
            return 0;
        } else {
            return
                _buyPriceImpactElse(
                    market,
                    position,
                    amount,
                    balanceOtherSide,
                    balancePosition,
                    balanceOtherSideAfter,
                    balancePositionAfter
                );
        }
    }

    function _buyPriceImpactElse(
        address market,
        Position position,
        uint amount,
        uint balanceOtherSide,
        uint balancePosition,
        uint balanceOtherSideAfter,
        uint balancePositionAfter
    ) internal view returns (uint) {
        uint maxPossibleSkew = balanceOtherSide.add(availableToBuyFromAMM(market, position)).sub(balancePosition);
        uint skew = balanceOtherSideAfter.sub(balancePositionAfter);
        uint newImpact = max_spread.mul(skew.mul(ONE).div(maxPossibleSkew)).div(ONE);
        if (balancePosition > 0) {
            if (balancePosition > amount) {
                return 0;
            }
            uint newPriceForMintedOnes = newImpact.div(2);
            uint tempMultiplier = amount.sub(balancePosition).mul(newPriceForMintedOnes);
            return tempMultiplier.div(amount);
        } else {
            uint previousSkew = balanceOtherSide;
            uint previousImpact = max_spread.mul(previousSkew.mul(ONE).div(maxPossibleSkew)).div(ONE);
            return newImpact.add(previousImpact).div(2);
        }
    }

    function _sellPriceImpact(
        address market,
        Position position,
        uint amount
    ) internal view returns (uint) {
        // take the balanceOtherSideMinimum
        (uint balancePosition, , uint balanceOtherSide) = _balanceOfPositionsOnMarket(market, position);
        uint balancePositionAfter =
            balancePosition > 0 ? balancePosition.add(amount) : balanceOtherSide > amount ? 0 : amount.sub(balanceOtherSide);
        uint balanceOtherSideAfter = balanceOtherSide > amount ? balanceOtherSide.sub(amount) : 0;
        if (balancePositionAfter < balanceOtherSideAfter) {
            //minimal price impact as it will balance the AMM exposure
            return 0;
        } else {
            return
                _sellPriceImpactElse(
                    market,
                    position,
                    amount,
                    balanceOtherSide,
                    balancePosition,
                    balanceOtherSideAfter,
                    balancePositionAfter
                );
        }
    }

    function _sellPriceImpactElse(
        address market,
        Position position,
        uint amount,
        uint balanceOtherSide,
        uint balancePosition,
        uint balanceOtherSideAfter,
        uint balancePositionAfter
    ) internal view returns (uint) {
        uint maxPossibleSkew = balancePosition.add(availableToSellToAMM(market, position)).sub(balanceOtherSide);
        uint skew = balancePositionAfter.sub(balanceOtherSideAfter);
        uint newImpact = max_spread.mul(skew.mul(ONE).div(maxPossibleSkew)).div(ONE);

        if (balanceOtherSide > 0) {
            uint newPriceForMintedOnes = newImpact.div(2);
            uint tempMultiplier = amount.sub(balancePosition).mul(newPriceForMintedOnes);
            return tempMultiplier.div(amount);
        } else {
            uint previousSkew = balancePosition;
            uint previousImpact = max_spread.mul(previousSkew.mul(ONE).div(maxPossibleSkew)).div(ONE);
            return newImpact.add(previousImpact).div(2);
        }
    }

    function _getMintableAmount(
        address market,
        Position position,
        uint amount
    ) internal view returns (uint mintable) {
        uint availableInContract = _balanceOfPositionOnMarket(market, position);
        if (availableInContract < amount) {
            mintable = amount.sub(availableInContract);
        }
    }

    function _balanceOfPositionOnMarket(address market, Position position) internal view returns (uint) {
        (IPosition home, IPosition away, IPosition draw) = ISportPositionalMarket(market).getOptions();
        uint balance = position == Position.Home ? home.getBalanceOf(address(this)) : away.getBalanceOf(address(this));
        if (ISportPositionalMarket(market).optionsCount() == 3 && position != Position.Home) {
            balance = position == Position.Away ? away.getBalanceOf(address(this)) : draw.getBalanceOf(address(this));
        }
        return balance;
    }

    function _balanceOfPositionsOnMarket(address market, Position position)
        internal
        view
        returns (
            uint,
            uint,
            uint
        )
    {
        (IPosition home, IPosition away, IPosition draw) = ISportPositionalMarket(market).getOptions();
        uint balance = position == Position.Home ? home.getBalanceOf(address(this)) : away.getBalanceOf(address(this));
        uint balanceOtherSideMax =
            position == Position.Home ? away.getBalanceOf(address(this)) : home.getBalanceOf(address(this));
        uint balanceOtherSideMin = balanceOtherSideMax;
        if (ISportPositionalMarket(market).optionsCount() == 3) {
            uint homeBalance = home.getBalanceOf(address(this));
            uint awayBalance = away.getBalanceOf(address(this));
            uint drawBalance = draw.getBalanceOf(address(this));
            if (position == Position.Home) {
                balance = homeBalance;
                if (awayBalance < drawBalance) {
                    balanceOtherSideMax = drawBalance;
                    balanceOtherSideMin = awayBalance;
                } else {
                    balanceOtherSideMax = awayBalance;
                    balanceOtherSideMin = drawBalance;
                }
            } else if (position == Position.Away) {
                balance = awayBalance;
                if (homeBalance < drawBalance) {
                    balanceOtherSideMax = drawBalance;
                    balanceOtherSideMin = homeBalance;
                } else {
                    balanceOtherSideMax = homeBalance;
                    balanceOtherSideMin = drawBalance;
                }
            } else if (position == Position.Draw) {
                balance = drawBalance;
                if (homeBalance < awayBalance) {
                    balanceOtherSideMax = awayBalance;
                    balanceOtherSideMin = homeBalance;
                } else {
                    balanceOtherSideMax = homeBalance;
                    balanceOtherSideMin = awayBalance;
                }
            }
        }
        return (balance, balanceOtherSideMax, balanceOtherSideMin);
    }

    function _mapCollateralToCurveIndex(address collateral) internal view returns (int128) {
        if (collateral == dai) {
            return 1;
        }
        if (collateral == usdc) {
            return 2;
        }
        if (collateral == usdt) {
            return 3;
        }
        return 0;
    }

    /// @notice Retrive all sUSD funds of the SportsAMM contract, in case of destroying
    /// @param account Address where to send the funds
    /// @param amount Amount of sUSD to be sent
    function retrieveSUSDAmount(address payable account, uint amount) external onlyOwner {
        sUSD.safeTransfer(account, amount);
    }

    // events
    event SoldToAMM(
        address seller,
        address market,
        Position position,
        uint amount,
        uint sUSDPaid,
        address susd,
        address asset
    );
    event BoughtFromAmm(
        address buyer,
        address market,
        Position position,
        uint amount,
        uint sUSDPaid,
        address susd,
        address asset
    );

    event SetSportsPositionalMarketManager(address _manager);
    event SetSUSD(address sUSD);
    event SetDefaultCapPerGame(uint _defaultCapPerGame);
    event SetMaxSpread(uint _spread);
    event SetMinSpread(uint _spread);
    event SetSafeBoxImpact(uint _safeBoxImpact);
    event SetSafeBox(address _safeBox);
    event SetMinimalTimeLeftToMaturity(uint _minimalTimeLeftToMaturity);
    event SetStakingThales(address _stakingThales);
    event SetMinSupportedOdds(uint _spread);
    event SetMaxSupportedOdds(uint _spread);
    event SetMaxSupportedPrice(uint _spread);
    event SetTherundownConsumer(address _theRundownConsumer);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the `nonReentrant` modifier
 * available, which can be aplied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
contract ProxyReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;
    bool private _initialized;

    function initNonReentrant() public {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Clone of syntetix contract without constructor
contract ProxyOwned {
    address public owner;
    address public nominatedOwner;
    bool private _initialized;
    bool private _transferredAtInit;

    function setOwner(address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
        require(!_initialized, "Already initialized, use nominateNewOwner");
        _initialized = true;
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    function transferOwnershipAtInit(address proxyAddress) external onlyOwner {
        require(proxyAddress != address(0), "Invalid address");
        require(!_transferredAtInit, "Already transferred");
        owner = proxyAddress;
        _transferredAtInit = true;
        emit OwnerChanged(owner, proxyAddress);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

import "../interfaces/IPositionalMarketManager.sol";
import "../interfaces/IPosition.sol";
import "../interfaces/IPriceFeed.sol";

interface ISportPositionalMarket {
    /* ========== TYPES ========== */

    enum Phase {Trading, Maturity, Expiry}
    enum Side {Cancelled, Home, Away, Draw}

    /* ========== VIEWS / VARIABLES ========== */

    function getOptions()
        external
        view
        returns (
            IPosition home,
            IPosition away,
            IPosition draw
        );

    function times() external view returns (uint maturity, uint destruction);

    function getGameDetails() external view returns (bytes32 gameId, string memory gameLabel);

    function getGameId() external view returns (bytes32);

    function deposited() external view returns (uint);

    function optionsCount() external view returns (uint);

    function creator() external view returns (address);

    function resolved() external view returns (bool);

    function cancelled() external view returns (bool);

    function paused() external view returns (bool);

    function phase() external view returns (Phase);

    function canResolve() external view returns (bool);

    function result() external view returns (Side);

    function getStampedOdds()
        external
        view
        returns (
            uint,
            uint,
            uint
        );

    function balancesOf(address account)
        external
        view
        returns (
            uint home,
            uint away,
            uint draw
        );

    function totalSupplies()
        external
        view
        returns (
            uint home,
            uint away,
            uint draw
        );

    function getMaximumBurnable(address account) external view returns (uint amount);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setPaused(bool _paused) external;

    function mint(uint value) external;

    function exerciseOptions() external;

    function restoreInvalidOdds(
        uint _homeOdds,
        uint _awayOdds,
        uint _drawOdds
    ) external;

    function burnOptions(uint amount) external;

    function burnOptionsMaximum() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ISportPositionalMarket.sol";

interface ISportPositionalMarketManager {
    /* ========== VIEWS / VARIABLES ========== */

    function marketCreationEnabled() external view returns (bool);

    function totalDeposited() external view returns (uint);

    function numActiveMarkets() external view returns (uint);

    function activeMarkets(uint index, uint pageSize) external view returns (address[] memory);

    function numMaturedMarkets() external view returns (uint);

    function maturedMarkets(uint index, uint pageSize) external view returns (address[] memory);

    function isActiveMarket(address candidate) external view returns (bool);

    function isKnownMarket(address candidate) external view returns (bool);

    function getActiveMarketAddress(uint _index) external view returns (address);

    function transformCollateral(uint value) external view returns (uint);

    function reverseTransformCollateral(uint value) external view returns (uint);

    function isMarketPaused(address _market) external view returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createMarket(
        bytes32 gameId,
        string memory gameLabel,
        uint maturity,
        uint initialMint, // initial sUSD to mint options for,
        uint positionCount,
        uint[] memory tags
    ) external returns (ISportPositionalMarket);

    function setMarketPaused(address _market, bool _paused) external;

    function resolveMarket(address market, uint outcome) external;

    function expireMarkets(address[] calldata market) external;

    function transferSusdTo(
        address sender,
        address receiver,
        uint amount
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import "./IPositionalMarket.sol";

interface IPosition {
    /* ========== VIEWS / VARIABLES ========== */

    function getBalanceOf(address account) external view returns (uint);

    function getTotalSupply() external view returns (uint);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITherundownConsumer {

    // view functions
    function isSupportedSport(uint _sportId) external view returns (bool);
    function isSupportedMarketType(string memory _market) external view returns (bool);
    function getNormalizedOdds(bytes32 _gameId) external view returns(uint[] memory);
    function getNormalizedOddsForTwoPosition(bytes32 _gameId) external view returns(uint[] memory);
    function getGameCreatedById(address _market) external view returns(bytes32);
    function getResult(bytes32 _gameId) external view returns(uint);

    // write functions
    function fulfillGamesCreated(bytes32 _requestId, bytes[] memory _games, uint _sportsId, uint _date) external;
    function fulfillGamesResolved(bytes32 _requestId, bytes[] memory _games, uint _sportsId) external;
    function fulfillGamesOdds(bytes32 _requestId, bytes[] memory _games, uint _date) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

interface ICurveSUSD {
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) external returns (uint256 );

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 _dx
    ) external view returns (uint256 );

    //    @notice Perform an exchange between two underlying coins
    //    @param i Index value for the underlying coin to send
    //    @param j Index valie of the underlying coin to receive
    //    @param _dx Amount of `i` being exchanged
    //    @param _min_dy Minimum amount of `j` to receive
    //    @param _receiver Address that receives `j`
    //    @return Actual amount of `j` received

    // indexes:
    // 0 = sUSD 18 dec 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9
    // 1= DAI 18 dec 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1
    // 2= USDC 6 dec 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
    // 3= USDT 6 dec 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import "../interfaces/IPositionalMarket.sol";

interface IPositionalMarketManager {
    /* ========== VIEWS / VARIABLES ========== */

    function durations() external view returns (uint expiryDuration, uint maxTimeToMaturity);

    function capitalRequirement() external view returns (uint);

    function marketCreationEnabled() external view returns (bool);

    function transformCollateral(uint value) external view returns (uint);

    function reverseTransformCollateral(uint value) external view returns (uint);

    function totalDeposited() external view returns (uint);

    function numActiveMarkets() external view returns (uint);

    function activeMarkets(uint index, uint pageSize) external view returns (address[] memory);

    function numMaturedMarkets() external view returns (uint);

    function maturedMarkets(uint index, uint pageSize) external view returns (address[] memory);

    function isActiveMarket(address candidate) external view returns (bool);

    function isKnownMarket(address candidate) external view returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createMarket(
        bytes32 oracleKey,
        uint strikePrice,
        uint maturity,
        uint initialMint, // initial sUSD to mint options for,
        bool customMarket,
        address customOracle
    ) external returns (IPositionalMarket);

    function resolveMarket(address market) external;

    function expireMarkets(address[] calldata market) external;

    function transferSusdTo(
        address sender,
        address receiver,
        uint amount
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IPriceFeed {
     // Structs
    struct RateAndUpdatedTime {
        uint216 rate;
        uint40 time;
    }
    
    // Mutative functions
    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external;

    function removeAggregator(bytes32 currencyKey) external;

    // Views

    function rateForCurrency(bytes32 currencyKey) external view returns (uint);

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time);

    function getRates() external view returns (uint[] memory);

    function getCurrencies() external view returns (bytes32[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import "../interfaces/IPositionalMarketManager.sol";
import "../interfaces/IPosition.sol";
import "../interfaces/IPriceFeed.sol";

interface IPositionalMarket {
    /* ========== TYPES ========== */

    enum Phase {Trading, Maturity, Expiry}
    enum Side {Up, Down}

    /* ========== VIEWS / VARIABLES ========== */

    function getOptions() external view returns (IPosition up, IPosition down);

    function times() external view returns (uint maturity, uint destructino);

    function getOracleDetails()
        external
        view
        returns (
            bytes32 key,
            uint strikePrice,
            uint finalPrice
        );

    function fees() external view returns (uint poolFee, uint creatorFee);

    function deposited() external view returns (uint);

    function creator() external view returns (address);

    function resolved() external view returns (bool);

    function phase() external view returns (Phase);

    function oraclePrice() external view returns (uint);

    function oraclePriceAndTimestamp() external view returns (uint price, uint updatedAt);

    function canResolve() external view returns (bool);

    function result() external view returns (Side);

    function balancesOf(address account) external view returns (uint up, uint down);

    function totalSupplies() external view returns (uint up, uint down);

    function getMaximumBurnable(address account) external view returns (uint amount);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function mint(uint value) external;

    function exerciseOptions() external returns (uint);

    function burnOptions(uint amount) external;

    function burnOptionsMaximum() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-4.4.1/proxy/Clones.sol";

// interfaces
import "../interfaces/IPriceFeed.sol";
import "../interfaces/IThalesAMM.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "../utils/libraries/AddressSetLib.sol";

import "./RangedPosition.sol";
import "./RangedPosition.sol";
import "./RangedMarket.sol";
import "../interfaces/IPositionalMarket.sol";
import "../interfaces/IStakingThales.sol";
import "../interfaces/IReferrals.sol";
import "../interfaces/ICurveSUSD.sol";

contract RangedMarketsAMM is Initializable, ProxyOwned, ProxyPausable, ProxyReentrancyGuard {
    using AddressSetLib for AddressSetLib.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint private constant ONE = 1e18;
    uint private constant ONE_PERCENT = 1e16;

    IThalesAMM public thalesAmm;

    uint public rangedAmmFee;

    mapping(address => mapping(address => address)) public createdRangedMarkets;
    AddressSetLib.AddressSet internal _knownMarkets;

    address public rangedMarketMastercopy;
    address public rangedPositionMastercopy;

    IERC20Upgradeable public sUSD;

    mapping(address => uint) public spentOnMarket;

    // IMPORTANT: AMM risks only half or the payout effectively, but it risks the whole amount on price movements
    uint public capPerMarket;

    uint public minSupportedPrice;
    uint public maxSupportedPrice;

    address public safeBox;
    uint public safeBoxImpact;

    uint public minimalDifBetweenStrikes;

    IStakingThales public stakingThales;

    uint public maximalDifBetweenStrikes;

    address public referrals;
    uint public referrerFee;

    ICurveSUSD public curveSUSD;

    address public usdc;
    address public usdt;
    address public dai;

    bool public curveOnrampEnabled;

    function initialize(
        address _owner,
        IThalesAMM _thalesAmm,
        uint _rangedAmmFee,
        uint _capPerMarket,
        IERC20Upgradeable _sUSD,
        address _safeBox,
        uint _safeBoxImpact
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        thalesAmm = _thalesAmm;
        capPerMarket = _capPerMarket;
        rangedAmmFee = _rangedAmmFee;
        sUSD = _sUSD;
        safeBox = _safeBox;
        safeBoxImpact = _safeBoxImpact;

        sUSD.approve(address(thalesAmm), type(uint256).max);
    }

    function createRangedMarket(address leftMarket, address rightMarket) external nonReentrant notPaused {
        require(canCreateRangedMarket(leftMarket, rightMarket), "Can't create such a ranged market!");

        RangedMarket rm = RangedMarket(Clones.clone(rangedMarketMastercopy));
        createdRangedMarkets[leftMarket][rightMarket] = address(rm);

        RangedPosition inp = RangedPosition(Clones.clone(rangedPositionMastercopy));
        inp.initialize(address(rm), "Position IN", "IN", address(this));

        RangedPosition outp = RangedPosition(Clones.clone(rangedPositionMastercopy));
        outp.initialize(address(rm), "Position OUT", "OUT", address(this));

        rm.initialize(leftMarket, rightMarket, address(inp), address(outp), address(this));

        _knownMarkets.add(address(rm));

        emit RangedMarketCreated(address(rm), leftMarket, rightMarket);
    }

    function canCreateRangedMarket(address leftMarket, address rightMarket) public view returns (bool) {
        if (!thalesAmm.isMarketInAMMTrading(leftMarket) || !thalesAmm.isMarketInAMMTrading(rightMarket)) {
            return false;
        }
        (uint maturityLeft, ) = IPositionalMarket(leftMarket).times();
        (uint maturityRight, ) = IPositionalMarket(rightMarket).times();
        if (maturityLeft != maturityRight) {
            return false;
        }

        (bytes32 leftkey, uint leftstrikePrice, ) = IPositionalMarket(leftMarket).getOracleDetails();
        (bytes32 rightkey, uint rightstrikePrice, ) = IPositionalMarket(rightMarket).getOracleDetails();
        if (leftkey != rightkey) {
            return false;
        }
        if (leftstrikePrice >= rightstrikePrice) {
            return false;
        }

        if (!(((ONE + minimalDifBetweenStrikes * ONE_PERCENT) * leftstrikePrice) / ONE < rightstrikePrice)) {
            return false;
        }

        if (!(((ONE + maximalDifBetweenStrikes * ONE_PERCENT) * leftstrikePrice) / ONE > rightstrikePrice)) {
            return false;
        }

        return createdRangedMarkets[leftMarket][rightMarket] == address(0);
    }

    function availableToBuyFromAMM(RangedMarket rangedMarket, RangedMarket.Position position)
        public
        view
        knownRangedMarket(address(rangedMarket))
        returns (uint)
    {
        uint availableLeft =
            thalesAmm.availableToBuyFromAMM(
                address(rangedMarket.leftMarket()),
                position == RangedMarket.Position.Out ? IThalesAMM.Position.Down : IThalesAMM.Position.Up
            );
        uint availableRight =
            thalesAmm.availableToBuyFromAMM(
                address(rangedMarket.rightMarket()),
                position == RangedMarket.Position.Out ? IThalesAMM.Position.Up : IThalesAMM.Position.Down
            );
        if (position == RangedMarket.Position.Out) {
            return availableLeft < availableRight ? availableLeft : availableRight;
        } else {
            uint availableThalesAMM = (availableLeft < availableRight ? availableLeft : availableRight) * 2;
            uint availableRangedAmm = _availableToBuyFromAMMOnlyRangedIN(rangedMarket);
            return availableThalesAMM > availableRangedAmm ? availableRangedAmm : availableThalesAMM;
        }
    }

    function _availableToBuyFromAMMOnlyRangedIN(RangedMarket rangedMarket)
        internal
        view
        knownRangedMarket(address(rangedMarket))
        returns (uint availableRangedAmm)
    {
        uint minPrice = minInPrice(rangedMarket);
        if (minPrice <= minSupportedPrice || minPrice >= maxSupportedPrice) {
            return 0;
        }
        uint rangedAMMRisk = ONE - minInPrice(rangedMarket);
        availableRangedAmm = ((capPerMarket - spentOnMarket[address(rangedMarket)]) * ONE) / rangedAMMRisk;
    }

    function minInPrice(RangedMarket rangedMarket)
        public
        view
        knownRangedMarket(address(rangedMarket))
        returns (uint quotedPrice)
    {
        uint leftQuote = thalesAmm.buyFromAmmQuote(address(rangedMarket.leftMarket()), IThalesAMM.Position.Up, ONE);
        uint rightQuote = thalesAmm.buyFromAmmQuote(address(rangedMarket.rightMarket()), IThalesAMM.Position.Down, ONE);
        quotedPrice = ((leftQuote + rightQuote) - ((ONE - leftQuote) + (ONE - rightQuote))) / 2;
    }

    function buyFromAmmQuote(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount
    ) public view knownRangedMarket(address(rangedMarket)) returns (uint sUSDPaid) {
        (sUSDPaid, , ) = buyFromAmmQuoteDetailed(rangedMarket, position, amount);
        uint basePrice = (sUSDPaid * ONE) / amount;
        if (basePrice < minSupportedPrice || basePrice >= ONE) {
            sUSDPaid = 0;
        }
    }

    function buyFromAmmQuoteDetailed(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount
    )
        public
        view
        knownRangedMarket(address(rangedMarket))
        returns (
            uint quoteWithFees,
            uint leftQuote,
            uint rightQuote
        )
    {
        amount = position == RangedMarket.Position.Out ? amount : amount / 2;
        leftQuote = thalesAmm.buyFromAmmQuote(
            address(rangedMarket.leftMarket()),
            position == RangedMarket.Position.Out ? IThalesAMM.Position.Down : IThalesAMM.Position.Up,
            amount
        );
        rightQuote = thalesAmm.buyFromAmmQuote(
            address(rangedMarket.rightMarket()),
            position == RangedMarket.Position.Out ? IThalesAMM.Position.Up : IThalesAMM.Position.Down,
            amount
        );
        uint summedQuotes = leftQuote + rightQuote;
        if (position == RangedMarket.Position.Out) {
            quoteWithFees = (summedQuotes * (rangedAmmFee + ONE)) / ONE;
        } else {
            uint quoteWithoutFees = ((summedQuotes) - ((amount - leftQuote) + (amount - rightQuote)));
            quoteWithFees = (quoteWithoutFees * (rangedAmmFee + safeBoxImpact + ONE)) / ONE;
        }
    }

    function buyFromAmmQuoteWithDifferentCollateral(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        address collateral
    ) public view returns (uint collateralQuote, uint sUSDToPay) {
        int128 curveIndex = _mapCollateralToCurveIndex(collateral);
        if (curveIndex == 0 || !curveOnrampEnabled) {
            return (0, 0);
        }

        sUSDToPay = buyFromAmmQuote(rangedMarket, position, amount);
        //cant get a quote on how much collateral is needed from curve for sUSD,
        //so rather get how much of collateral you get for the sUSD quote and add 0.2% to that
        collateralQuote = (curveSUSD.get_dy_underlying(0, curveIndex, sUSDToPay) * (ONE + (ONE_PERCENT / 5))) / ONE;
    }

    function buyFromAMMWithReferrer(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage,
        address referrer
    ) public knownRangedMarket(address(rangedMarket)) nonReentrant notPaused {
        if (referrer != address(0)) {
            IReferrals(referrals).setReferrer(referrer, msg.sender);
        }
        _buyFromAMM(rangedMarket, position, amount, expectedPayout, additionalSlippage, true);
    }

    function buyFromAMMWithDifferentCollateralAndReferrer(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage,
        address collateral,
        address _referrer
    ) public nonReentrant notPaused {
        if (_referrer != address(0)) {
            IReferrals(referrals).setReferrer(_referrer, msg.sender);
        }

        int128 curveIndex = _mapCollateralToCurveIndex(collateral);
        require(curveIndex > 0 && curveOnrampEnabled, "unsupported collateral");

        (uint collateralQuote, uint susdQuote) =
            buyFromAmmQuoteWithDifferentCollateral(rangedMarket, position, amount, collateral);

        require((collateralQuote * ONE) / expectedPayout <= (ONE + additionalSlippage), "Slippage too high");

        IERC20Upgradeable collateralToken = IERC20Upgradeable(collateral);
        collateralToken.safeTransferFrom(msg.sender, address(this), collateralQuote);
        curveSUSD.exchange_underlying(curveIndex, 0, collateralQuote, susdQuote);

        _buyFromAMM(rangedMarket, position, amount, susdQuote, additionalSlippage, false);
    }

    function buyFromAMM(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) public knownRangedMarket(address(rangedMarket)) nonReentrant notPaused {
        _buyFromAMM(rangedMarket, position, amount, expectedPayout, additionalSlippage, true);
    }

    function _buyFromAMM(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage,
        bool sendSUSD
    ) internal {
        require(
            position == RangedMarket.Position.Out || amount <= _availableToBuyFromAMMOnlyRangedIN(rangedMarket),
            "Not enough liquidity"
        );

        (uint sUSDPaid, uint leftQuote, uint rightQuote) = buyFromAmmQuoteDetailed(rangedMarket, position, amount);

        uint basePrice = (sUSDPaid * ONE) / amount;
        require(basePrice > minSupportedPrice && basePrice < ONE, "Invalid price");
        require((sUSDPaid * ONE) / expectedPayout <= (ONE + additionalSlippage), "Slippage too high");

        if (sendSUSD) {
            sUSD.safeTransferFrom(msg.sender, address(this), sUSDPaid);
        }

        address target;
        (RangedPosition inp, RangedPosition outp) = rangedMarket.positions();

        if (position == RangedMarket.Position.Out) {
            target = address(outp);
            _buyOUT(rangedMarket, amount, leftQuote, rightQuote, additionalSlippage);
        } else {
            target = address(inp);
            _buyIN(rangedMarket, amount, leftQuote, rightQuote, additionalSlippage);
            _updateSpentOnMarketAndSafeBoxOnBuy(address(rangedMarket), amount, sUSDPaid);
        }

        rangedMarket.mint(amount, position, msg.sender);

        _handleReferrer(msg.sender, sUSDPaid);

        if (address(stakingThales) != address(0)) {
            stakingThales.updateVolume(msg.sender, sUSDPaid);
        }

        emit BoughtFromAmm(msg.sender, address(rangedMarket), position, amount, sUSDPaid, address(sUSD), target);
    }

    function _buyOUT(
        RangedMarket rangedMarket,
        uint amount,
        uint leftQuote,
        uint rightQuote,
        uint additionalSlippage
    ) internal {
        thalesAmm.buyFromAMM(
            address(rangedMarket.leftMarket()),
            IThalesAMM.Position.Down,
            amount,
            leftQuote,
            additionalSlippage
        );

        thalesAmm.buyFromAMM(
            address(rangedMarket.rightMarket()),
            IThalesAMM.Position.Up,
            amount,
            rightQuote,
            additionalSlippage
        );
        // TODO: what if I got 1% less than amount via Thales AMM? set additional slippage to 0 for internal trades
        // apply the same in all places
        (, IPosition down) = IPositionalMarket(rangedMarket.leftMarket()).getOptions();
        IERC20Upgradeable(address(down)).safeTransfer(address(rangedMarket), amount);

        (IPosition up1, ) = IPositionalMarket(rangedMarket.rightMarket()).getOptions();
        IERC20Upgradeable(address(up1)).safeTransfer(address(rangedMarket), amount);
    }

    function _buyIN(
        RangedMarket rangedMarket,
        uint amount,
        uint leftQuote,
        uint rightQuote,
        uint additionalSlippage
    ) internal {
        thalesAmm.buyFromAMM(
            address(rangedMarket.leftMarket()),
            IThalesAMM.Position.Up,
            amount / 2,
            leftQuote,
            additionalSlippage
        );

        thalesAmm.buyFromAMM(
            address(rangedMarket.rightMarket()),
            IThalesAMM.Position.Down,
            amount / 2,
            rightQuote,
            additionalSlippage
        );
        (IPosition up, ) = IPositionalMarket(rangedMarket.leftMarket()).getOptions();
        IERC20Upgradeable(address(up)).safeTransfer(address(rangedMarket), amount / 2);

        (, IPosition down1) = IPositionalMarket(rangedMarket.rightMarket()).getOptions();
        IERC20Upgradeable(address(down1)).safeTransfer(address(rangedMarket), amount / 2);
    }

    function availableToSellToAMM(RangedMarket rangedMarket, RangedMarket.Position position)
        public
        view
        knownRangedMarket(address(rangedMarket))
        returns (uint _available)
    {
        uint availableLeft =
            thalesAmm.availableToSellToAMM(
                address(rangedMarket.leftMarket()),
                position == RangedMarket.Position.Out ? IThalesAMM.Position.Down : IThalesAMM.Position.Up
            );
        uint availableRight =
            thalesAmm.availableToSellToAMM(
                address(rangedMarket.rightMarket()),
                position == RangedMarket.Position.Out ? IThalesAMM.Position.Up : IThalesAMM.Position.Down
            );

        _available = availableLeft < availableRight ? availableLeft : availableRight;
        if (position == RangedMarket.Position.In) {
            _available = _available * 2;
        }
    }

    function sellToAmmQuote(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount
    ) public view knownRangedMarket(address(rangedMarket)) returns (uint pricePaid) {
        (pricePaid, , ) = sellToAmmQuoteDetailed(rangedMarket, position, amount);
    }

    function sellToAmmQuoteDetailed(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount
    )
        public
        view
        knownRangedMarket(address(rangedMarket))
        returns (
            uint quoteWithFees,
            uint leftQuote,
            uint rightQuote
        )
    {
        amount = position == RangedMarket.Position.Out ? amount : amount / 2;
        leftQuote = thalesAmm.sellToAmmQuote(
            address(rangedMarket.leftMarket()),
            position == RangedMarket.Position.Out ? IThalesAMM.Position.Down : IThalesAMM.Position.Up,
            amount
        );
        rightQuote = thalesAmm.sellToAmmQuote(
            address(rangedMarket.rightMarket()),
            position == RangedMarket.Position.Out ? IThalesAMM.Position.Up : IThalesAMM.Position.Down,
            amount
        );
        uint summedQuotes = leftQuote + rightQuote;
        if (position == RangedMarket.Position.Out) {
            quoteWithFees = (summedQuotes * (ONE - rangedAmmFee)) / ONE;
        } else {
            if (amount > leftQuote && amount > rightQuote && summedQuotes > ((amount - leftQuote) + (amount - rightQuote))) {
                uint quoteWithoutFees = summedQuotes - ((amount - leftQuote) + (amount - rightQuote));
                quoteWithFees = (quoteWithoutFees * (ONE - rangedAmmFee - safeBoxImpact)) / ONE;
            }
        }
    }

    function sellToAMM(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) public knownRangedMarket(address(rangedMarket)) nonReentrant notPaused {
        uint availableToSellToAMMATM = availableToSellToAMM(rangedMarket, position);
        require(availableToSellToAMMATM > 0 && amount <= availableToSellToAMMATM, "Not enough liquidity.");

        (uint pricePaid, uint leftQuote, uint rightQuote) = sellToAmmQuoteDetailed(rangedMarket, position, amount);
        require(pricePaid > 0 && (expectedPayout * ONE) / pricePaid <= (ONE + additionalSlippage), "Slippage too high");

        _handleApprovals(rangedMarket);

        if (position == RangedMarket.Position.Out) {
            rangedMarket.burnOut(amount, msg.sender);
        } else {
            rangedMarket.burnIn(amount, msg.sender);
            _updateSpentOnMarketAndSafeBoxOnSell(amount, rangedMarket, pricePaid);
        }

        _handleSellToAmm(rangedMarket, position, amount, additionalSlippage, leftQuote, rightQuote);

        sUSD.safeTransfer(msg.sender, pricePaid);

        _handleReferrer(msg.sender, pricePaid);

        if (address(stakingThales) != address(0)) {
            stakingThales.updateVolume(msg.sender, pricePaid);
        }

        (RangedPosition inp, RangedPosition outp) = rangedMarket.positions();
        address target = position == RangedMarket.Position.Out ? address(outp) : address(inp);
        emit SoldToAMM(msg.sender, address(rangedMarket), position, amount, pricePaid, address(sUSD), target);
    }

    function _handleSellToAmm(
        RangedMarket rangedMarket,
        RangedMarket.Position position,
        uint amount,
        uint additionalSlippage,
        uint leftQuote,
        uint rightQuote
    ) internal {
        uint baseAMMAmount = position == RangedMarket.Position.Out ? amount : amount / 2;
        thalesAmm.sellToAMM(
            address(rangedMarket.leftMarket()),
            position == RangedMarket.Position.Out ? IThalesAMM.Position.Down : IThalesAMM.Position.Up,
            baseAMMAmount,
            leftQuote,
            additionalSlippage
        );

        thalesAmm.sellToAMM(
            address(rangedMarket.rightMarket()),
            position == RangedMarket.Position.Out ? IThalesAMM.Position.Up : IThalesAMM.Position.Down,
            baseAMMAmount,
            rightQuote,
            additionalSlippage
        );
    }

    function _handleApprovals(RangedMarket rangedMarket) internal {
        (IPosition up, IPosition down) = IPositionalMarket(rangedMarket.leftMarket()).getOptions();
        (IPosition up1, IPosition down1) = IPositionalMarket(rangedMarket.rightMarket()).getOptions();
        IERC20Upgradeable(address(up)).approve(address(thalesAmm), type(uint256).max);
        IERC20Upgradeable(address(down)).approve(address(thalesAmm), type(uint256).max);
        IERC20Upgradeable(address(up1)).approve(address(thalesAmm), type(uint256).max);
        IERC20Upgradeable(address(down1)).approve(address(thalesAmm), type(uint256).max);
    }

    function _handleReferrer(address buyer, uint sUSDPaid) internal {
        if (referrerFee > 0 && referrals != address(0)) {
            address referrer = IReferrals(referrals).referrals(buyer);
            if (referrer != address(0)) {
                uint referrerShare = (sUSDPaid * (ONE + referrerFee)) / ONE - sUSDPaid;
                sUSD.transfer(referrer, referrerShare);
                emit ReferrerPaid(referrer, buyer, referrerShare, sUSDPaid);
            }
        }
    }

    function _mapCollateralToCurveIndex(address collateral) internal view returns (int128) {
        if (collateral == dai) {
            return 1;
        }
        if (collateral == usdc) {
            return 2;
        }
        if (collateral == usdt) {
            return 3;
        }
        return 0;
    }

    function _updateSpentOnMarketAndSafeBoxOnBuy(
        address rangedMarket,
        uint amount,
        uint sUSDPaid
    ) internal {
        uint safeBoxShare = 0;
        if (safeBoxImpact > 0) {
            safeBoxShare = sUSDPaid - ((sUSDPaid * ONE) / (ONE + safeBoxImpact));
            sUSD.transfer(safeBox, safeBoxShare);
        }

        spentOnMarket[rangedMarket] = spentOnMarket[rangedMarket] + amount + safeBoxShare - sUSDPaid;
    }

    function _updateSpentOnMarketAndSafeBoxOnSell(
        uint amount,
        RangedMarket rangedMarket,
        uint sUSDPaid
    ) internal {
        uint safeBoxShare = 0;

        if (safeBoxImpact > 0) {
            safeBoxShare = ((sUSDPaid * ONE) / (ONE - safeBoxImpact)) - sUSDPaid;
            sUSD.transfer(safeBox, safeBoxShare);
        }

        if (amount > (spentOnMarket[address(rangedMarket)] + sUSDPaid + safeBoxShare)) {
            spentOnMarket[address(rangedMarket)] = 0;
        } else {
            spentOnMarket[address(rangedMarket)] = spentOnMarket[address(rangedMarket)] + sUSDPaid + safeBoxShare - amount;
        }
    }

    function transferSusdTo(address receiver, uint amount) external {
        require(_knownMarkets.contains(msg.sender), "Not a known ranged market");
        sUSD.safeTransfer(receiver, amount);
    }

    function retrieveSUSDAmount(address payable account, uint amount) external onlyOwner {
        sUSD.safeTransfer(account, amount);
    }

    function setRangedMarketMastercopies(address _rangedMarketMastercopy, address _rangedPositionMastercopy)
        external
        onlyOwner
    {
        rangedMarketMastercopy = _rangedMarketMastercopy;
        rangedPositionMastercopy = _rangedPositionMastercopy;
    }

    function setMinMaxSupportedPrice(
        uint _minSupportedPrice,
        uint _maxSupportedPrice,
        uint _minDiffBetweenStrikes,
        uint _maxDiffBetweenStrikes
    ) public onlyOwner {
        minSupportedPrice = _minSupportedPrice;
        maxSupportedPrice = _maxSupportedPrice;
        minimalDifBetweenStrikes = _minDiffBetweenStrikes;
        maximalDifBetweenStrikes = _maxDiffBetweenStrikes;
        emit SetMinSupportedPrice(minSupportedPrice);
        emit SetMaxSupportedPrice(maxSupportedPrice);
        emit SetMinimalDifBetweenStrikes(minimalDifBetweenStrikes);
        emit SetMaxinalDifBetweenStrikes(maximalDifBetweenStrikes);
    }

    function setSafeBoxData(address _safeBox, uint _safeBoxImpact) external onlyOwner {
        safeBoxImpact = _safeBoxImpact;
        safeBox = _safeBox;
        emit SetSafeBoxImpact(_safeBoxImpact);
        emit SetSafeBox(_safeBox);
    }

    function setCapPerMarketAndRangedAMMFee(uint _capPerMarket, uint _rangedAMMFee) external onlyOwner {
        capPerMarket = _capPerMarket;
        rangedAmmFee = _rangedAMMFee;
        emit SetCapPerMarket(capPerMarket);
        emit SetRangedAmmFee(rangedAmmFee);
    }

    function setThalesAMMStakingThalesAndReferrals(
        address _thalesAMM,
        IStakingThales _stakingThales,
        address _referrals,
        uint _referrerFee
    ) external onlyOwner {
        thalesAmm = IThalesAMM(_thalesAMM);
        sUSD.approve(address(thalesAmm), type(uint256).max);
        stakingThales = _stakingThales;
        referrals = _referrals;
        referrerFee = _referrerFee;
    }

    function setCurveSUSD(
        address _curveSUSD,
        address _dai,
        address _usdc,
        address _usdt,
        bool _curveOnrampEnabled
    ) external onlyOwner {
        curveSUSD = ICurveSUSD(_curveSUSD);
        dai = _dai;
        usdc = _usdc;
        usdt = _usdt;
        IERC20(dai).approve(_curveSUSD, type(uint256).max);
        IERC20(usdc).approve(_curveSUSD, type(uint256).max);
        IERC20(usdt).approve(_curveSUSD, type(uint256).max);
        // not needed unless selling into different collateral is enabled
        //sUSD.approve(_curveSUSD, type(uint256).max);
        curveOnrampEnabled = _curveOnrampEnabled;
    }

    modifier knownRangedMarket(address market) {
        require(_knownMarkets.contains(market), "Not a known ranged market");
        _;
    }

    event SoldToAMM(
        address seller,
        address market,
        RangedMarket.Position position,
        uint amount,
        uint sUSDPaid,
        address susd,
        address asset
    );
    event BoughtFromAmm(
        address buyer,
        address market,
        RangedMarket.Position position,
        uint amount,
        uint sUSDPaid,
        address susd,
        address asset
    );

    event SetSUSD(address sUSD);
    event RangedMarketCreated(address market, address leftMarket, address rightMarket);
    event SetSafeBoxImpact(uint _safeBoxImpact);
    event SetSafeBox(address _safeBox);
    event SetMinSupportedPrice(uint _spread);
    event SetMaxSupportedPrice(uint _spread);
    event SetMinimalDifBetweenStrikes(uint _spread);
    event SetMaxinalDifBetweenStrikes(uint _spread);
    event SetCapPerMarket(uint capPerMarket);
    event SetRangedAmmFee(uint rangedAmmFee);
    event SetStakingThales(address _stakingThales);
    event ReferrerPaid(address refferer, address trader, uint amount, uint volume);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/Clones.sol)

pragma solidity ^0.8.0;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

interface IThalesAMM {
    enum Position {Up, Down}

    function manager() external view returns (address);

    function availableToBuyFromAMM(address market, Position position) external view returns (uint);

    function buyFromAmmQuote(
        address market,
        Position position,
        uint amount
    ) external view returns (uint);

    function buyFromAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) external;

    function availableToSellToAMM(address market, Position position) external view returns (uint);

    function sellToAmmQuote(
        address market,
        Position position,
        uint amount
    ) external view returns (uint);

    function sellToAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) external;

    function isMarketInAMMTrading(address market) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "./ProxyOwned.sol";

// Clone of syntetix contract without constructor

contract ProxyPausable is ProxyOwned {
    uint public lastPauseTime;
    bool public paused;

    

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library AddressSetLib {
    struct AddressSet {
        address[] elements;
        mapping(address => uint) indices;
    }

    function contains(AddressSet storage set, address candidate) internal view returns (bool) {
        if (set.elements.length == 0) {
            return false;
        }
        uint index = set.indices[candidate];
        return index != 0 || set.elements[0] == candidate;
    }

    function getPage(
        AddressSet storage set,
        uint index,
        uint pageSize
    ) internal view returns (address[] memory) {
        // NOTE: This implementation should be converted to slice operators if the compiler is updated to v0.6.0+
        uint endIndex = index + pageSize; // The check below that endIndex <= index handles overflow.

        // If the page extends past the end of the list, truncate it.
        if (endIndex > set.elements.length) {
            endIndex = set.elements.length;
        }
        if (endIndex <= index) {
            return new address[](0);
        }

        uint n = endIndex - index; // We already checked for negative overflow.
        address[] memory page = new address[](n);
        for (uint i; i < n; i++) {
            page[i] = set.elements[i + index];
        }
        return page;
    }

    function add(AddressSet storage set, address element) internal {
        // Adding to a set is an idempotent operation.
        if (!contains(set, element)) {
            set.indices[element] = set.elements.length;
            set.elements.push(element);
        }
    }

    function remove(AddressSet storage set, address element) internal {
        require(contains(set, element), "Element not in set.");
        // Replace the removed element with the last element of the list.
        uint index = set.indices[element];
        uint lastIndex = set.elements.length - 1; // We required that element is in the list, so it is not empty.
        if (index != lastIndex) {
            // No need to shift the last element if it is the one we want to delete.
            address shiftedElement = set.elements[lastIndex];
            set.elements[index] = shiftedElement;
            set.indices[shiftedElement] = index;
        }
        set.elements.pop();
        delete set.indices[element];
    }
}

// in position collaterized by 0.5 UP on the left leg and 0.5 DOWN on the right leg

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "../interfaces/IPosition.sol";

// Internal references
import "./RangedMarket.sol";

contract RangedPosition is IERC20 {
    /* ========== STATE VARIABLES ========== */

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    RangedMarket public rangedMarket;

    mapping(address => uint) public override balanceOf;
    uint public override totalSupply;

    // The argument order is allowance[owner][spender]
    mapping(address => mapping(address => uint)) private allowances;

    // Enforce a 1 cent minimum amount
    uint internal constant _MINIMUM_AMOUNT = 1e16;

    address public thalesRangedAMM;
    /* ========== CONSTRUCTOR ========== */

    bool public initialized = false;

    function initialize(
        address market,
        string calldata _name,
        string calldata _symbol,
        address _thalesRangedAMM
    ) external {
        require(!initialized, "Ranged Market already initialized");
        initialized = true;
        rangedMarket = RangedMarket(market);
        name = _name;
        symbol = _symbol;
        thalesRangedAMM = _thalesRangedAMM;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        if (spender == thalesRangedAMM) {
            return type(uint256).max;
        } else {
            return allowances[owner][spender];
        }
    }

    function burn(address claimant, uint amount) external onlyRangedMarket {
        balanceOf[claimant] = balanceOf[claimant] - amount;
        totalSupply = totalSupply - amount;
        emit Burned(claimant, amount);
        emit Transfer(claimant, address(0), amount);
    }

    function mint(address minter, uint amount) external onlyRangedMarket {
        _requireMinimumAmount(amount);
        totalSupply = totalSupply + amount;
        balanceOf[minter] = balanceOf[minter] + amount; // Increment rather than assigning since a transfer may have occurred.
        emit Mint(minter, amount);
        emit Transfer(address(0), minter, amount);
    }

    /* ---------- ERC20 Functions ---------- */

    function _transfer(
        address _from,
        address _to,
        uint _value
    ) internal returns (bool success) {
        require(_to != address(0) && _to != address(this), "Invalid address");

        uint fromBalance = balanceOf[_from];
        require(_value <= fromBalance, "Insufficient balance");

        balanceOf[_from] = fromBalance - _value;
        balanceOf[_to] = balanceOf[_to] + _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint _value) external override returns (bool success) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint _value
    ) external override returns (bool success) {
        if (msg.sender != thalesRangedAMM) {
            uint fromAllowance = allowances[_from][msg.sender];
            require(_value <= fromAllowance, "Insufficient allowance");
            allowances[_from][msg.sender] = fromAllowance - _value;
        }
        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint _value) external override returns (bool success) {
        require(_spender != address(0));
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function getBalanceOf(address account) external view returns (uint) {
        return balanceOf[account];
    }

    function getTotalSupply() external view returns (uint) {
        return totalSupply;
    }

    modifier onlyRangedMarket {
        require(msg.sender == address(rangedMarket), "only the Ranged Market may perform these methods");
        _;
    }

    function _requireMinimumAmount(uint amount) internal pure returns (uint) {
        require(amount >= _MINIMUM_AMOUNT || amount == 0, "Balance < $0.01");
        return amount;
    }

    event Mint(address minter, uint amount);
    event Burned(address burner, uint amount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/utils/SafeERC20.sol";

// Internal references
import "./RangedPosition.sol";
import "./RangedMarketsAMM.sol";
import "../interfaces/IPositionalMarket.sol";
import "../interfaces/IPositionalMarketManager.sol";

contract RangedMarket {
    using SafeERC20 for IERC20;

    enum Position {In, Out}

    IPositionalMarket public leftMarket;
    IPositionalMarket public rightMarket;

    struct Positions {
        RangedPosition inp;
        RangedPosition outp;
    }

    Positions public positions;

    RangedMarketsAMM public rangedMarketsAMM;

    bool public resolved = false;

    uint finalPrice;

    /* ========== CONSTRUCTOR ========== */

    bool public initialized = false;

    function initialize(
        address _leftMarket,
        address _rightMarket,
        address _in,
        address _out,
        address _rangedMarketsAMM
    ) external {
        require(!initialized, "Ranged Market already initialized");
        initialized = true;
        leftMarket = IPositionalMarket(_leftMarket);
        rightMarket = IPositionalMarket(_rightMarket);
        positions.inp = RangedPosition(_in);
        positions.outp = RangedPosition(_out);
        rangedMarketsAMM = RangedMarketsAMM(_rangedMarketsAMM);
    }

    function mint(
        uint value,
        Position _position,
        address minter
    ) external onlyAMM {
        if (value == 0) {
            return;
        }
        _mint(minter, value, _position);
    }

    function _mint(
        address minter,
        uint amount,
        Position _position
    ) internal {
        if (_position == Position.In) {
            positions.inp.mint(minter, amount);
        } else {
            positions.outp.mint(minter, amount);
        }
        emit Mint(minter, amount, _position);
    }

    function burnIn(uint value, address claimant) external onlyAMM {
        if (value == 0) {
            return;
        }
        (IPosition up, ) = IPositionalMarket(leftMarket).getOptions();
        IERC20(address(up)).safeTransfer(msg.sender, value / 2);

        (, IPosition down1) = IPositionalMarket(rightMarket).getOptions();
        IERC20(address(down1)).safeTransfer(msg.sender, value / 2);

        positions.inp.burn(claimant, value);
        emit Burn(claimant, value, Position.In);
    }

    function burnOut(uint value, address claimant) external onlyAMM {
        if (value == 0) {
            return;
        }
        (, IPosition down) = IPositionalMarket(leftMarket).getOptions();
        IERC20(address(down)).safeTransfer(msg.sender, value);

        (IPosition up1, ) = IPositionalMarket(rightMarket).getOptions();
        IERC20(address(up1)).safeTransfer(msg.sender, value);

        positions.outp.burn(claimant, value);

        emit Burn(claimant, value, Position.Out);
    }

    function canExercisePositions() external view returns (bool) {
        if (!leftMarket.resolved() && !leftMarket.canResolve()) {
            return false;
        }
        if (!rightMarket.resolved() && !rightMarket.canResolve()) {
            return false;
        }

        uint inBalance = positions.inp.balanceOf(msg.sender);
        uint outBalance = positions.outp.balanceOf(msg.sender);

        if (inBalance == 0 && outBalance == 0) {
            return false;
        }

        return true;
    }

    function exercisePositions() external {
        if (leftMarket.canResolve()) {
            IPositionalMarketManager(rangedMarketsAMM.thalesAmm().manager()).resolveMarket(address(leftMarket));
        }
        if (rightMarket.canResolve()) {
            IPositionalMarketManager(rangedMarketsAMM.thalesAmm().manager()).resolveMarket(address(rightMarket));
        }
        require(leftMarket.resolved() && rightMarket.resolved(), "Left or Right market not resolved yet!");

        uint inBalance = positions.inp.balanceOf(msg.sender);
        uint outBalance = positions.outp.balanceOf(msg.sender);

        require(inBalance != 0 || outBalance != 0, "Nothing to exercise");

        if (!resolved) {
            resolveMarket();
        }

        // Each option only needs to be exercised if the account holds any of it.
        if (inBalance != 0) {
            positions.inp.burn(msg.sender, inBalance);
        }
        if (outBalance != 0) {
            positions.outp.burn(msg.sender, outBalance);
        }

        Position curResult = Position.Out;
        if ((leftMarket.result() == IPositionalMarket.Side.Up) && (rightMarket.result() == IPositionalMarket.Side.Down)) {
            curResult = Position.In;
        }

        // Only pay out the side that won.
        uint payout = (curResult == Position.In) ? inBalance : outBalance;
        if (payout != 0) {
            rangedMarketsAMM.transferSusdTo(msg.sender, payout);
        }
        emit Exercised(msg.sender, payout, curResult);
    }

    function canResolve() external view returns (bool) {
        // The markets must be resolved
        if (!leftMarket.resolved() && !leftMarket.canResolve()) {
            return false;
        }
        if (!rightMarket.resolved() && !rightMarket.canResolve()) {
            return false;
        }

        return !resolved;
    }

    function resolveMarket() public {
        // The markets must be resolved
        if (leftMarket.canResolve()) {
            IPositionalMarketManager(rangedMarketsAMM.thalesAmm().manager()).resolveMarket(address(leftMarket));
        }
        if (rightMarket.canResolve()) {
            IPositionalMarketManager(rangedMarketsAMM.thalesAmm().manager()).resolveMarket(address(rightMarket));
        }
        require(leftMarket.resolved() && rightMarket.resolved(), "Left or Right market not resolved yet!");
        require(!resolved, "Already resolved!");

        if (positions.inp.totalSupply() > 0 || positions.outp.totalSupply() > 0) {
            leftMarket.exerciseOptions();
            rightMarket.exerciseOptions();
        }
        resolved = true;

        if (rangedMarketsAMM.sUSD().balanceOf(address(this)) > 0) {
            rangedMarketsAMM.sUSD().transfer(address(rangedMarketsAMM), rangedMarketsAMM.sUSD().balanceOf(address(this)));
        }

        (, , uint _finalPrice) = leftMarket.getOracleDetails();
        finalPrice = _finalPrice;
        emit Resolved(result(), finalPrice);
    }

    function result() public view returns (Position) {
        Position resultToReturn = Position.Out;
        if ((leftMarket.result() == IPositionalMarket.Side.Up) && (rightMarket.result() == IPositionalMarket.Side.Down)) {
            resultToReturn = Position.In;
        }
        return resultToReturn;
    }

    function withdrawCollateral(address recipient) external onlyAMM {
        rangedMarketsAMM.sUSD().transfer(recipient, rangedMarketsAMM.sUSD().balanceOf(address(this)));
    }

    modifier onlyAMM {
        require(msg.sender == address(rangedMarketsAMM), "only the AMM may perform these methods");
        _;
    }

    event Mint(address minter, uint amount, Position _position);
    event Burn(address burner, uint amount, Position _position);
    event Exercised(address exerciser, uint amount, Position _position);
    event Resolved(Position winningPosition, uint finalPrice);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

interface IReferrals {
    function referrals(address) external view returns (address);

    function setReferrer(address, address) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";

import "../../interfaces/IPosition.sol";

// Libraries
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
import "./SportPositionalMarket.sol";

contract SportPosition is IERC20, IPosition {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;

    /* ========== STATE VARIABLES ========== */

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    SportPositionalMarket public market;

    mapping(address => uint) public override balanceOf;
    uint public override totalSupply;

    // The argument order is allowance[owner][spender]
    mapping(address => mapping(address => uint)) private allowances;

    // Enforce a 1 cent minimum amount
    uint internal constant _MINIMUM_AMOUNT = 1e16;

    address public sportsAMM;
    /* ========== CONSTRUCTOR ========== */

    bool public initialized = false;

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _sportsAMM
    ) external {
        require(!initialized, "Positional Market already initialized");
        initialized = true;
        name = _name;
        symbol = _symbol;
        market = SportPositionalMarket(msg.sender);
        // add through constructor
        sportsAMM = _sportsAMM;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        if (spender == sportsAMM) {
            return 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        } else {
            return allowances[owner][spender];
        }
    }

    function _requireMinimumAmount(uint amount) internal pure returns (uint) {
        require(amount >= _MINIMUM_AMOUNT || amount == 0, "Balance < $0.01");
        return amount;
    }

    function mint(address minter, uint amount) external onlyMarket {
        _requireMinimumAmount(amount);
        totalSupply = totalSupply.add(amount);
        balanceOf[minter] = balanceOf[minter].add(amount); // Increment rather than assigning since a transfer may have occurred.

        emit Transfer(address(0), minter, amount);
        emit Issued(minter, amount);
    }

    // This must only be invoked after maturity.
    function exercise(address claimant) external onlyMarket {
        uint balance = balanceOf[claimant];

        if (balance == 0) {
            return;
        }

        balanceOf[claimant] = 0;
        totalSupply = totalSupply.sub(balance);

        emit Transfer(claimant, address(0), balance);
        emit Burned(claimant, balance);
    }

    // This must only be invoked after maturity.
    function exerciseWithAmount(address claimant, uint amount) external onlyMarket {
        require(amount > 0, "Can not exercise zero amount!");

        require(balanceOf[claimant] >= amount, "Balance must be greather or equal amount that is burned");

        balanceOf[claimant] = balanceOf[claimant] - amount;
        totalSupply = totalSupply.sub(amount);

        emit Transfer(claimant, address(0), amount);
        emit Burned(claimant, amount);
    }

    // This must only be invoked after the exercise window is complete.
    // Note that any options which have not been exercised will linger.
    function expire(address payable beneficiary) external onlyMarket {
        selfdestruct(beneficiary);
    }

    /* ---------- ERC20 Functions ---------- */

    function _transfer(
        address _from,
        address _to,
        uint _value
    ) internal returns (bool success) {
        market.requireUnpaused();
        require(_to != address(0) && _to != address(this), "Invalid address");

        uint fromBalance = balanceOf[_from];
        require(_value <= fromBalance, "Insufficient balance");

        balanceOf[_from] = fromBalance.sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint _value) external override returns (bool success) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint _value
    ) external override returns (bool success) {
        if (msg.sender != sportsAMM) {
            uint fromAllowance = allowances[_from][msg.sender];
            require(_value <= fromAllowance, "Insufficient allowance");
            allowances[_from][msg.sender] = fromAllowance.sub(_value);
        }
        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint _value) external override returns (bool success) {
        require(_spender != address(0));
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function getBalanceOf(address account) external view override returns (uint) {
        return balanceOf[account];
    }

    function getTotalSupply() external view override returns (uint) {
        return totalSupply;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyMarket() {
        require(msg.sender == address(market), "Only market allowed");
        _;
    }

    /* ========== EVENTS ========== */

    event Issued(address indexed account, uint value);
    event Burned(address indexed account, uint value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "../../OwnedWithInit.sol";
import "../../interfaces/ISportPositionalMarket.sol";
import "../../interfaces/ITherundownConsumer.sol";

// Libraries
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
import "./SportPositionalMarketManager.sol";
import "./SportPosition.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";

contract SportPositionalMarket is OwnedWithInit, ISportPositionalMarket {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;

    /* ========== TYPES ========== */

    struct Options {
        SportPosition home;
        SportPosition away;
        SportPosition draw;
    }

    struct Times {
        uint maturity;
        uint expiry;
    }

    struct GameDetails {
        bytes32 gameId;
        string gameLabel;
    }

    struct SportPositionalMarketParameters {
        address owner;
        IERC20 sUSD;
        address creator;
        bytes32 gameId;
        string gameLabel;
        uint[2] times; // [maturity, expiry]
        uint deposit; // sUSD deposit
        address theRundownConsumer;
        address sportsAMM;
        uint positionCount;
        address[] positions;
        uint[] tags;
    }

    /* ========== STATE VARIABLES ========== */

    Options public options;
    uint public override optionsCount;
    Times public override times;
    GameDetails public gameDetails;
    ITherundownConsumer public theRundownConsumer;
    IERC20 public sUSD;
    address public sportsAMM;
    uint[] public tags;
    uint public finalResult;

    // `deposited` tracks the sum of all deposits.
    // This must explicitly be kept, in case tokens are transferred to the contract directly.
    uint public override deposited;
    uint public initialMint;
    address public override creator;
    bool public override resolved;
    bool public override cancelled;
    uint public homeOddsOnCancellation;
    uint public awayOddsOnCancellation;
    uint public drawOddsOnCancellation;

    bool public invalidOdds;
    bool public initialized = false;
    bool public override paused;

    /* ========== CONSTRUCTOR ========== */
    function initialize(SportPositionalMarketParameters calldata _parameters) external {
        require(!initialized, "Positional Market already initialized");
        initialized = true;
        initOwner(_parameters.owner);
        sUSD = _parameters.sUSD;
        creator = _parameters.creator;
        theRundownConsumer = ITherundownConsumer(_parameters.theRundownConsumer);

        gameDetails = GameDetails(_parameters.gameId, _parameters.gameLabel);

        tags = _parameters.tags;
        times = Times(_parameters.times[0], _parameters.times[1]);

        deposited = _parameters.deposit;
        initialMint = _parameters.deposit;
        optionsCount = _parameters.positionCount;
        sportsAMM = _parameters.sportsAMM;
        require(optionsCount == _parameters.positions.length, "Position count mismatch");
        // Instantiate the options themselves
        options.home = SportPosition(_parameters.positions[0]);
        options.away = SportPosition(_parameters.positions[1]);
        // abi.encodePacked("sUP: ", _oracleKey)
        // consider naming the option: sUpBTC>[email protected]
        options.home.initialize(gameDetails.gameLabel, "HOME", _parameters.sportsAMM);
        options.away.initialize(gameDetails.gameLabel, "AWAY", _parameters.sportsAMM);

        if (optionsCount > 2) {
            options.draw = SportPosition(_parameters.positions[2]);
            options.draw.initialize(gameDetails.gameLabel, "DRAW", _parameters.sportsAMM);
        }
        if (initialMint > 0) {
            _mint(creator, initialMint);
        }

        // Note: the ERC20 base contract does not have a constructor, so we do not have to worry
        // about initializing its state separately
    }

    /* ---------- External Contracts ---------- */

    function _manager() internal view returns (SportPositionalMarketManager) {
        return SportPositionalMarketManager(owner);
    }

    /* ---------- Phases ---------- */

    function _matured() internal view returns (bool) {
        return times.maturity < block.timestamp;
    }

    function _expired() internal view returns (bool) {
        return resolved && (times.expiry < block.timestamp || deposited == 0);
    }

    function phase() external view override returns (Phase) {
        if (!_matured()) {
            return Phase.Trading;
        }
        if (!_expired()) {
            return Phase.Maturity;
        }
        return Phase.Expiry;
    }

    function setPaused(bool _paused) external override onlyOwner managerNotPaused {
        require(paused != _paused, "State not changed");
        paused = _paused;
        emit PauseUpdated(_paused);
    }

    /* ---------- Market Resolution ---------- */

    function canResolve() public view override returns (bool) {
        return !resolved && _matured() && !paused;
    }

    function getGameDetails() external view override returns (bytes32 gameId, string memory gameLabel) {
        return (gameDetails.gameId, gameDetails.gameLabel);
    }

    function _result() internal view returns (Side) {
        if (!resolved || cancelled) {
            return Side.Cancelled;
        } else if (finalResult == 3 && optionsCount > 2) {
            return Side.Draw;
        } else {
            return finalResult == 1 ? Side.Home : Side.Away;
        }
    }

    function result() external view override returns (Side) {
        return _result();
    }

    /* ---------- Option Balances and Mints ---------- */
    function getGameId() external view override returns (bytes32) {
        return gameDetails.gameId;
    }

    function getStampedOdds()
        external
        view
        override
        returns (
            uint,
            uint,
            uint
        )
    {
        if (cancelled) {
            return (homeOddsOnCancellation, awayOddsOnCancellation, drawOddsOnCancellation);
        } else {
            return (0, 0, 0);
        }
    }

    function _balancesOf(address account)
        internal
        view
        returns (
            uint home,
            uint away,
            uint draw
        )
    {
        if (optionsCount > 2) {
            return (
                options.home.getBalanceOf(account),
                options.away.getBalanceOf(account),
                options.draw.getBalanceOf(account)
            );
        }
        return (options.home.getBalanceOf(account), options.away.getBalanceOf(account), 0);
    }

    function balancesOf(address account)
        external
        view
        override
        returns (
            uint home,
            uint away,
            uint draw
        )
    {
        return _balancesOf(account);
    }

    function totalSupplies()
        external
        view
        override
        returns (
            uint home,
            uint away,
            uint draw
        )
    {
        if (optionsCount > 2) {
            return (options.home.totalSupply(), options.away.totalSupply(), options.draw.totalSupply());
        }
        return (options.home.totalSupply(), options.away.totalSupply(), 0);
    }

    function getMaximumBurnable(address account) external view override returns (uint amount) {
        return _getMaximumBurnable(account);
    }

    function getOptions()
        external
        view
        override
        returns (
            IPosition home,
            IPosition away,
            IPosition draw
        )
    {
        home = options.home;
        away = options.away;
        draw = options.draw;
    }

    function _getMaximumBurnable(address account) internal view returns (uint amount) {
        (uint homeBalance, uint awayBalance, uint drawBalance) = _balancesOf(account);
        uint min = homeBalance;
        if (min > awayBalance) {
            min = awayBalance;
            if (optionsCount > 2 && drawBalance < min) {
                min = drawBalance;
            }
        } else {
            if (optionsCount > 2 && drawBalance < min) {
                min = drawBalance;
            }
        }
        return min;
    }

    /* ---------- Utilities ---------- */

    function _incrementDeposited(uint value) internal returns (uint _deposited) {
        _deposited = deposited.add(value);
        deposited = _deposited;
        _manager().incrementTotalDeposited(value);
    }

    function _decrementDeposited(uint value) internal returns (uint _deposited) {
        _deposited = deposited.sub(value);
        deposited = _deposited;
        _manager().decrementTotalDeposited(value);
    }

    function _requireManagerNotPaused() internal view {
        require(!_manager().paused(), "This action cannot be performed while the contract is paused");
    }

    function requireUnpaused() external view {
        _requireManagerNotPaused();
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Minting ---------- */

    function mint(uint value) external override {
        require(!_matured() && !paused, "Minting inactive");
        require(msg.sender == sportsAMM, "Invalid minter");
        if (value == 0) {
            return;
        }

        _mint(msg.sender, value);

        _incrementDeposited(value);
        _manager().transferSusdTo(msg.sender, address(this), value);
    }

    function _mint(address minter, uint amount) internal {
        options.home.mint(minter, amount);
        options.away.mint(minter, amount);
        emit Mint(Side.Home, minter, amount);
        emit Mint(Side.Away, minter, amount);
        if (optionsCount > 2) {
            options.draw.mint(minter, amount);
            emit Mint(Side.Draw, minter, amount);
        }
    }

    function burnOptionsMaximum() external override {
        _burnOptions(msg.sender, _getMaximumBurnable(msg.sender));
    }

    function burnOptions(uint amount) external override {
        _burnOptions(msg.sender, amount);
    }

    function _burnOptions(address account, uint amount) internal {
        require(amount > 0, "Can not burn zero amount!");
        require(!paused, "Market paused");
        require(_getMaximumBurnable(account) >= amount, "There is not enough options!");

        // decrease deposit
        _decrementDeposited(amount);

        // decrease home and away options
        options.home.exerciseWithAmount(account, amount);
        options.away.exerciseWithAmount(account, amount);
        if (optionsCount > 2) {
            options.draw.exerciseWithAmount(account, amount);
        }

        // transfer balance
        sUSD.transfer(account, amount);

        // emit events
        emit OptionsBurned(account, amount);
    }

    /* ---------- Custom oracle configuration ---------- */
    function setTherundownConsumer(address _theRundownConsumer) external onlyOwner {
        theRundownConsumer = ITherundownConsumer(_theRundownConsumer);
        emit SetTherundownConsumer(_theRundownConsumer);
    }

    function setsUSD(address _address) external onlyOwner {
        sUSD = IERC20(_address);
        emit SetsUSD(_address);
    }

    /* ---------- Market Resolution ---------- */

    function resolve(uint _outcome) external onlyOwner managerNotPaused {
        require(_outcome <= optionsCount, "Invalid outcome");
        if (_outcome == 0) {
            cancelled = true;
            stampOdds();
        } else {
            require(canResolve(), "Can not resolve market");
        }
        finalResult = _outcome;
        resolved = true;
        emit MarketResolved(_result(), deposited, 0, 0);
    }

    function stampOdds() internal {
        uint[] memory odds = new uint[](optionsCount);
        odds = ITherundownConsumer(theRundownConsumer).getNormalizedOdds(gameDetails.gameId);
        if (odds[0] == 0 || odds[1] == 0) {
            invalidOdds = true;
        }
        homeOddsOnCancellation = odds[0];
        awayOddsOnCancellation = odds[1];
        drawOddsOnCancellation = optionsCount > 2 ? odds[2] : 0;
        emit StoredOddsOnCancellation(homeOddsOnCancellation, awayOddsOnCancellation, drawOddsOnCancellation);
    }

    /* ---------- Claiming and Exercising Options ---------- */

    function exerciseOptions() external override {
        // The market must be resolved if it has not been.
        require(resolved, "Unresolved");
        require(!paused, "Paused");
        // If the account holds no options, revert.
        (uint homeBalance, uint awayBalance, uint drawBalance) = _balancesOf(msg.sender);
        require(homeBalance != 0 || awayBalance != 0 || drawBalance != 0, "Nothing to exercise");

        // Each option only needs to be exercised if the account holds any of it.
        if (homeBalance != 0) {
            options.home.exercise(msg.sender);
        }
        if (awayBalance != 0) {
            options.away.exercise(msg.sender);
        }
        if (optionsCount > 2 && drawBalance != 0) {
            options.draw.exercise(msg.sender);
        }
        uint result = uint(_result());
        // Only pay out the side that won.
        uint payout = (_result() == Side.Home) ? homeBalance : awayBalance;

        if (optionsCount > 2 && _result() != Side.Home) {
            payout = _result() == Side.Away ? awayBalance : drawBalance;
        }
        if (cancelled) {
            require(!invalidOdds, "Invalid stamped odds");
            payout = calculatePayoutOnCancellation(homeBalance, awayBalance, drawBalance);
        }
        emit OptionsExercised(msg.sender, payout);
        if (payout != 0) {
            _decrementDeposited(payout);
            sUSD.transfer(msg.sender, payout);
        }
    }

    function restoreInvalidOdds(
        uint _homeOdds,
        uint _awayOdds,
        uint _drawOdds
    ) external override onlyOwner {
        require(_homeOdds > 0 && _awayOdds > 0, "Invalid odd");
        homeOddsOnCancellation = _homeOdds;
        awayOddsOnCancellation = _awayOdds;
        drawOddsOnCancellation = optionsCount > 2 ? _drawOdds : 0;
        invalidOdds = false;
        emit StoredOddsOnCancellation(homeOddsOnCancellation, awayOddsOnCancellation, drawOddsOnCancellation);
    }

    function calculatePayoutOnCancellation(
        uint _homeBalance,
        uint _awayBalance,
        uint _drawBalance
    ) public view returns (uint) {
        if (!cancelled) {
            return 0;
        } else {
            uint payout = _homeBalance.mul(homeOddsOnCancellation).div(1e18);
            payout = payout.add(_awayBalance.mul(awayOddsOnCancellation).div(1e18));
            payout = payout.add(_drawBalance.mul(drawOddsOnCancellation).div(1e18));
            return payout;
        }
    }

    /* ---------- Market Expiry ---------- */

    function _selfDestruct(address payable beneficiary) internal {
        uint _deposited = deposited;
        if (_deposited != 0) {
            _decrementDeposited(_deposited);
        }

        // Transfer the balance rather than the deposit value in case there are any synths left over
        // from direct transfers.
        uint balance = sUSD.balanceOf(address(this));
        if (balance != 0) {
            sUSD.transfer(beneficiary, balance);
        }

        // Destroy the option tokens before destroying the market itself.
        options.home.expire(beneficiary);
        options.away.expire(beneficiary);
        selfdestruct(beneficiary);
    }

    function expire(address payable beneficiary) external onlyOwner {
        require(_expired(), "Unexpired options remaining");
        emit Expired(beneficiary);
        _selfDestruct(beneficiary);
    }

    /* ========== MODIFIERS ========== */

    modifier managerNotPaused() {
        _requireManagerNotPaused();
        _;
    }

    /* ========== EVENTS ========== */

    event Mint(Side side, address indexed account, uint value);
    event MarketResolved(Side result, uint deposited, uint poolFees, uint creatorFees);

    event OptionsExercised(address indexed account, uint value);
    event OptionsBurned(address indexed account, uint value);
    event SetsUSD(address _address);
    event SetTherundownConsumer(address _address);
    event Expired(address beneficiary);
    event StoredOddsOnCancellation(uint homeOdds, uint awayOdds, uint drawOdds);
    event PauseUpdated(bool _paused);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract OwnedWithInit {
    address public owner;
    address public nominatedOwner;

    constructor() {}

    function initOwner(address _owner) internal {
        require(owner == address(0), "Init can only be called when owner is 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "../../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../../utils/proxy/solidity-0.8.0/ProxyPausable.sol";

// Libraries
import "../../utils/libraries/AddressSetLib.sol";
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
import "./SportPositionalMarketFactory.sol";
import "./SportPositionalMarket.sol";
import "./SportPosition.sol";
import "../../interfaces/ISportPositionalMarketManager.sol";
import "../../interfaces/ISportPositionalMarket.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SportPositionalMarketManager is Initializable, ProxyOwned, ProxyPausable, ISportPositionalMarketManager {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;
    using AddressSetLib for AddressSetLib.AddressSet;

    /* ========== STATE VARIABLES ========== */

    uint public expiryDuration;

    bool public override marketCreationEnabled;
    bool public customMarketCreationEnabled;

    uint public override totalDeposited;

    AddressSetLib.AddressSet internal _activeMarkets;
    AddressSetLib.AddressSet internal _maturedMarkets;

    SportPositionalMarketManager internal _migratingManager;

    IERC20 public sUSD;

    address public theRundownConsumer;
    address public sportPositionalMarketFactory;
    bool public needsTransformingCollateral;

    /* ========== CONSTRUCTOR ========== */

    function initialize(address _owner, IERC20 _sUSD) external initializer {
        setOwner(_owner);
        sUSD = _sUSD;

        // Temporarily change the owner so that the setters don't revert.
        owner = msg.sender;

        marketCreationEnabled = true;
        customMarketCreationEnabled = false;
    }

    /* ========== SETTERS ========== */
    function setSportPositionalMarketFactory(address _sportPositionalMarketFactory) external onlyOwner {
        sportPositionalMarketFactory = _sportPositionalMarketFactory;
        emit SetSportPositionalMarketFactory(_sportPositionalMarketFactory);
    }

    function setTherundownConsumer(address _theRundownConsumer) external onlyOwner {
        theRundownConsumer = _theRundownConsumer;
        emit SetTherundownConsumer(_theRundownConsumer);
    }

    /* ========== VIEWS ========== */

    /* ---------- Market Information ---------- */

    function isKnownMarket(address candidate) public view override returns (bool) {
        return _activeMarkets.contains(candidate) || _maturedMarkets.contains(candidate);
    }

    function isActiveMarket(address candidate) public view override returns (bool) {
        return _activeMarkets.contains(candidate) && !ISportPositionalMarket(candidate).paused();
    }

    function numActiveMarkets() external view override returns (uint) {
        return _activeMarkets.elements.length;
    }

    function activeMarkets(uint index, uint pageSize) external view override returns (address[] memory) {
        return _activeMarkets.getPage(index, pageSize);
    }

    function numMaturedMarkets() external view override returns (uint) {
        return _maturedMarkets.elements.length;
    }

    function getActiveMarketAddress(uint _index) external view override returns (address) {
        if (_index < _activeMarkets.elements.length) {
            return _activeMarkets.elements[_index];
        } else {
            return address(0);
        }
    }

    function maturedMarkets(uint index, uint pageSize) external view override returns (address[] memory) {
        return _maturedMarkets.getPage(index, pageSize);
    }

    function setMarketPaused(address _market, bool _paused) external override {
        require(msg.sender == owner || msg.sender == theRundownConsumer, "Invalid caller");
        require(ISportPositionalMarket(_market).paused() != _paused, "No state change");
        ISportPositionalMarket(_market).setPaused(_paused);
    }

    function isMarketPaused(address _market) external view override returns (bool) {
        return ISportPositionalMarket(_market).paused();
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Setters ---------- */

    function setExpiryDuration(uint _expiryDuration) public onlyOwner {
        expiryDuration = _expiryDuration;
        emit ExpiryDurationUpdated(_expiryDuration);
    }

    function setsUSD(address _address) external onlyOwner {
        sUSD = IERC20(_address);
        emit SetsUSD(_address);
    }

    /* ---------- Deposit Management ---------- */

    function incrementTotalDeposited(uint delta) external onlyActiveMarkets notPaused {
        totalDeposited = totalDeposited.add(delta);
    }

    function decrementTotalDeposited(uint delta) external onlyKnownMarkets notPaused {
        // NOTE: As individual market debt is not tracked here, the underlying markets
        //       need to be careful never to subtract more debt than they added.
        //       This can't be enforced without additional state/communication overhead.
        totalDeposited = totalDeposited.sub(delta);
    }

    /* ---------- Market Lifecycle ---------- */

    function createMarket(
        bytes32 gameId,
        string memory gameLabel,
        uint maturity,
        uint initialMint, // initial sUSD to mint options for,
        uint positionCount,
        uint[] memory tags
    )
        external
        override
        notPaused
        returns (
            ISportPositionalMarket // no support for returning PositionalMarket polymorphically given the interface
        )
    {
        require(marketCreationEnabled, "Market creation is disabled");
        require(msg.sender == theRundownConsumer, "Invalid creator");

        uint expiry = maturity.add(expiryDuration);

        require(block.timestamp < maturity, "Maturity has to be in the future");
        // We also require maturity < expiry. But there is no need to check this.
        // The market itself validates the capital and skew requirements.

        SportPositionalMarket market =
            SportPositionalMarketFactory(sportPositionalMarketFactory).createMarket(
                SportPositionalMarketFactory.SportPositionCreationMarketParameters(
                    msg.sender,
                    sUSD,
                    gameId,
                    gameLabel,
                    [maturity, expiry],
                    initialMint,
                    positionCount,
                    msg.sender,
                    tags
                )
            );

        _activeMarkets.add(address(market));

        // The debt can't be incremented in the new market's constructor because until construction is complete,
        // the manager doesn't know its address in order to grant it permission.
        totalDeposited = totalDeposited.add(initialMint);
        sUSD.transferFrom(msg.sender, address(market), initialMint);

        (IPosition up, IPosition down, IPosition draw) = market.getOptions();

        emit MarketCreated(
            address(market),
            msg.sender,
            gameId,
            gameLabel,
            maturity,
            expiry,
            address(up),
            address(down),
            address(draw)
        );
        return market;
    }

    function transferSusdTo(
        address sender,
        address receiver,
        uint amount
    ) external override {
        //only to be called by markets themselves
        require(isKnownMarket(address(msg.sender)), "Market unknown.");
        bool success = sUSD.transferFrom(sender, receiver, amount);
        if (!success) {
            revert("TransferFrom function failed");
        }
    }

    function resolveMarket(address market, uint _outcome) external override {
        require(msg.sender == theRundownConsumer || msg.sender == owner, "Invalid resolver");
        require(_activeMarkets.contains(market), "Not an active market");
        SportPositionalMarket(market).resolve(_outcome);
        _activeMarkets.remove(market);
        _maturedMarkets.add(market);
    }

    function expireMarkets(address[] calldata markets) external override notPaused onlyOwner {
        for (uint i = 0; i < markets.length; i++) {
            address market = markets[i];

            require(isKnownMarket(address(market)), "Market unknown.");

            // The market itself handles decrementing the total deposits.
            SportPositionalMarket(market).expire(payable(msg.sender));

            // Note that we required that the market is known, which guarantees
            // its index is defined and that the list of markets is not empty.
            _maturedMarkets.remove(market);

            emit MarketExpired(market);
        }
    }

    function restoreInvalidOddsForMarket(
        address _market,
        uint _homeOdds,
        uint _awayOdds,
        uint _drawOdds
    ) external onlyOwner {
        require(isKnownMarket(address(_market)), "Market unknown.");
        require(SportPositionalMarket(_market).cancelled(), "Market not cancelled.");
        SportPositionalMarket(_market).restoreInvalidOdds(_homeOdds, _awayOdds, _drawOdds);
        emit OddsForMarketRestored(_market, _homeOdds, _awayOdds, _drawOdds);
    }

    function setMarketCreationEnabled(bool enabled) external onlyOwner {
        if (enabled != marketCreationEnabled) {
            marketCreationEnabled = enabled;
            emit MarketCreationEnabledUpdated(enabled);
        }
    }

    // support USDC with 6 decimals
    function transformCollateral(uint value) external view override returns (uint) {
        return _transformCollateral(value);
    }

    function _transformCollateral(uint value) internal view returns (uint) {
        if (needsTransformingCollateral) {
            return value / 1e12;
        } else {
            return value;
        }
    }

    function reverseTransformCollateral(uint value) external view override returns (uint) {
        if (needsTransformingCollateral) {
            return value * 1e12;
        } else {
            return value;
        }
    }

    /* ========== MODIFIERS ========== */

    modifier onlyActiveMarkets() {
        require(_activeMarkets.contains(msg.sender), "Permitted only for active markets.");
        _;
    }

    modifier onlyKnownMarkets() {
        require(isKnownMarket(msg.sender), "Permitted only for known markets.");
        _;
    }

    /* ========== EVENTS ========== */

    event MarketCreated(
        address market,
        address indexed creator,
        bytes32 indexed gameId,
        string gameLabel,
        uint maturityDate,
        uint expiryDate,
        address up,
        address down,
        address draw
    );
    event MarketExpired(address market);
    event MarketCreationEnabledUpdated(bool enabled);
    event MarketsMigrated(SportPositionalMarketManager receivingManager, SportPositionalMarket[] markets);
    event MarketsReceived(SportPositionalMarketManager migratingManager, SportPositionalMarket[] markets);
    event SetMigratingManager(address migratingManager);
    event ExpiryDurationUpdated(uint duration);
    event MaxTimeToMaturityUpdated(uint duration);
    event CreatorCapitalRequirementUpdated(uint value);
    event SetSportPositionalMarketFactory(address _sportPositionalMarketFactory);
    event SetsUSD(address _address);
    event SetTherundownConsumer(address theRundownConsumer);
    event OddsForMarketRestored(address _market, uint _homeOdds, uint _awayOdds, uint _drawOdds);
}

pragma solidity ^0.8.0;

// Inheritance
import "../../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

// Internal references
import "./SportPosition.sol";
import "./SportPositionalMarket.sol";
import "./SportPositionalMarketFactory.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-4.4.1/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SportPositionalMarketFactory is Initializable, ProxyOwned {
    /* ========== STATE VARIABLES ========== */
    address public positionalMarketManager;

    address public positionalMarketMastercopy;
    address public positionMastercopy;

    address public sportsAMM;

    struct SportPositionCreationMarketParameters {
        address creator;
        IERC20 _sUSD;
        bytes32 gameId;
        string gameLabel;
        uint[2] times; // [maturity, expiry]
        uint initialMint;
        uint positionCount;
        address theRundownConsumer;
        uint[] tags;
    }

    /* ========== INITIALIZER ========== */

    function initialize(address _owner) external initializer {
        setOwner(_owner);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createMarket(SportPositionCreationMarketParameters calldata _parameters)
        external
        returns (SportPositionalMarket)
    {
        require(positionalMarketManager == msg.sender, "Only permitted by the manager.");

        SportPositionalMarket pom = SportPositionalMarket(Clones.clone(positionalMarketMastercopy));
        address[] memory positions = new address[](_parameters.positionCount);
        for (uint i = 0; i < _parameters.positionCount; i++) {
            positions[i] = address(SportPosition(Clones.clone(positionMastercopy)));
        }

        pom.initialize(
            SportPositionalMarket.SportPositionalMarketParameters(
                positionalMarketManager,
                _parameters._sUSD,
                _parameters.creator,
                _parameters.gameId,
                _parameters.gameLabel,
                _parameters.times,
                _parameters.initialMint,
                _parameters.theRundownConsumer,
                sportsAMM,
                _parameters.positionCount,
                positions,
                _parameters.tags
            )
        );
        emit MarketCreated(
            address(pom),
            _parameters.gameId,
            _parameters.gameLabel,
            _parameters.times[0],
            _parameters.times[1],
            _parameters.initialMint,
            _parameters.positionCount,
            _parameters.tags
        );
        return pom;
    }

    /* ========== SETTERS ========== */
    function setSportPositionalMarketManager(address _positionalMarketManager) external onlyOwner {
        positionalMarketManager = _positionalMarketManager;
        emit SportPositionalMarketManagerChanged(_positionalMarketManager);
    }

    function setSportPositionalMarketMastercopy(address _positionalMarketMastercopy) external onlyOwner {
        positionalMarketMastercopy = _positionalMarketMastercopy;
        emit SportPositionalMarketMastercopyChanged(_positionalMarketMastercopy);
    }

    function setSportPositionMastercopy(address _positionMastercopy) external onlyOwner {
        positionMastercopy = _positionMastercopy;
        emit SportPositionMastercopyChanged(_positionMastercopy);
    }

    function setSportsAMM(address _sportsAMM) external onlyOwner {
        sportsAMM = _sportsAMM;
        emit SetSportsAMM(_sportsAMM);
    }

    event SportPositionalMarketManagerChanged(address _positionalMarketManager);
    event SportPositionalMarketMastercopyChanged(address _positionalMarketMastercopy);
    event SportPositionMastercopyChanged(address _positionMastercopy);
    event SetSportsAMM(address _sportsAMM);
    event SetLimitOrderProvider(address _limitOrderProvider);
    event MarketCreated(
        address market,
        bytes32 indexed gameId,
        string gameLabel,
        uint maturityDate,
        uint expiryDate,
        uint initialMint,
        uint positionCount,
        uint[] tags
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Internal references
import "./SportPosition.sol";

contract SportPositionMastercopy is SportPosition {
    constructor() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// interfaces
import "../interfaces/IPriceFeed.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

contract ThalesRoyalePrivateRoom is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    /* ========== LIBRARIES ========== */

    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS =========== */

    uint public constant DOWN = 1;
    uint public constant UP = 2;

    /* ========== ROOM TYPES ========== */

    enum GameType {LAST_MAN_STANDING, LIMITED_NUMBER_OF_ROUNDS}
    enum RoomType {OPEN, CLOSED}

    /* ========== ROOM VARIABLES ========== */

    mapping(uint => address) public roomOwner;
    mapping(uint => bool) public roomPublished;
    mapping(uint => bytes32) public oracleKeyPerRoom;
    mapping(uint => uint) public roomCreationTime;
    mapping(uint => uint) public roomEndTime;
    mapping(uint => uint) public roomSignUpPeriod;
    mapping(uint => uint) public numberOfRoundsInRoom;
    mapping(uint => uint) public roundChoosingLengthInRoom;
    mapping(uint => uint) public roundLengthInRoom;
    mapping(uint => uint) public currentRoundInRoom;
    mapping(uint => bool) public roomStarted;
    mapping(uint => bool) public roomFinished;
    mapping(uint => bool) public isReversedPositioningInRoom;
    mapping(uint => RoomType) public roomTypePerRoom;
    mapping(uint => GameType) public gameTypeInRoom;
    mapping(uint => address[]) public playersPerRoom;
    mapping(uint => address[]) public alowedPlayersPerRoom;
    mapping(uint => mapping(address => uint256)) public playerSignedUpPerRoom;
    mapping(uint => mapping(address => bool)) public playerCanPlayInRoom;
    mapping(uint => uint) public buyInPerPlayerRerRoom;
    mapping(uint => uint) public numberOfPlayersInRoom;
    mapping(uint => uint) public numberOfAlowedPlayersInRoom;

    mapping(uint => uint) public roundTargetPriceInRoom;

    mapping(uint => mapping(uint => uint)) public roundResultPerRoom;
    mapping(uint => mapping(uint => uint)) public targetPricePerRoundPerRoom;
    mapping(uint => mapping(uint => uint)) public finalPricePerRoundPerRoom;
    mapping(uint => mapping(uint => uint)) public totalPlayersInARoomInARound;
    mapping(uint => mapping(uint => uint)) public eliminatedPerRoundPerRoom;

    mapping(uint => uint) public roundStartTimeInRoom;
    mapping(uint => uint) public roundEndTimeInRoom;

    mapping(uint => mapping(uint256 => mapping(uint256 => uint256))) public positionsPerRoundPerRoom;
    mapping(uint => mapping(address => mapping(uint256 => uint256))) public positionInARoundPerRoom;

    mapping(uint => uint) public rewardPerRoom;
    mapping(uint => uint) public rewardPerWinnerPerRoom;
    mapping(uint => mapping(address => bool)) public rewardCollectedPerRoom;
    mapping(uint => uint) public unclaimedRewardPerRoom;

    /* ========== STATE VARIABLES ========== */

    IERC20Upgradeable public rewardToken;
    IPriceFeed public priceFeed;

    address public safeBox;
    uint public safeBoxPercentage;

    uint public roomNumberCounter;

    uint public minTimeSignUp;
    uint public minRoundTime;
    uint public minChooseTime;
    uint public offsetBeteweenChooseAndEndRound;
    uint public maxPlayersInClosedRoom;
    uint public minBuyIn;
    uint public minNumberOfRounds;
    bytes32[] public allowedAssets;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _owner,
        IPriceFeed _priceFeed,
        address _rewardToken,
        uint _minTimeSignUp,
        uint _minRoundTime,
        uint _minChooseTime,
        uint _offsetBeteweenChooseAndEndRound,
        uint _maxPlayersInClosedRoom,
        uint _minBuyIn,
        bytes32[] memory _allowedAssets,
        uint _minNumberOfRounds
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        priceFeed = _priceFeed;
        rewardToken = IERC20Upgradeable(_rewardToken);
        minTimeSignUp = _minTimeSignUp;
        minRoundTime = _minRoundTime;
        minChooseTime = _minChooseTime;
        offsetBeteweenChooseAndEndRound = _offsetBeteweenChooseAndEndRound;
        maxPlayersInClosedRoom = _maxPlayersInClosedRoom;
        minBuyIn = _minBuyIn;
        allowedAssets = _allowedAssets;
        minNumberOfRounds = _minNumberOfRounds;
    }

    /* ========== ROOM CREATION ========== */

    function createOpenRoom(
        bytes32 _oracleKey,
        GameType _gameType,
        uint _buyInAmount,
        uint _amuontOfPlayersinRoom,
        uint _roomSignUpPeriod,
        uint _numberOfRoundsInRoom,
        uint _roundChoosingLength,
        uint _roundLength
    ) external {
        require(_buyInAmount >= minBuyIn, "Buy in must be greather then minimum");
        require(_roomSignUpPeriod >= minTimeSignUp, "Sign in period lower then minimum");
        require(_numberOfRoundsInRoom >= minNumberOfRounds, "Must be more minimum rounds");
        require(_roundChoosingLength >= minChooseTime, "Round chosing lower then minimum");
        require(_roundLength >= minRoundTime, "Round length lower then minimum");
        require(_roundLength >= _roundChoosingLength + offsetBeteweenChooseAndEndRound, "Offset lower then minimum");
        require(_amuontOfPlayersinRoom > 1, "Room must be open and have total players in room");
        require(isAssetAllowed(_oracleKey), "Not allowed assets");
        require(rewardToken.balanceOf(msg.sender) >= _buyInAmount, "No enough sUSD's");
        require(rewardToken.allowance(msg.sender, address(this)) >= _buyInAmount, "No allowance.");

        // set room_id
        roomNumberCounter++;

        // setting global room variables
        roomOwner[roomNumberCounter] = msg.sender;
        roomCreationTime[roomNumberCounter] = block.timestamp;
        roomSignUpPeriod[roomNumberCounter] = _roomSignUpPeriod;
        numberOfRoundsInRoom[roomNumberCounter] = _numberOfRoundsInRoom;
        roundChoosingLengthInRoom[roomNumberCounter] = _roundChoosingLength;
        roundLengthInRoom[roomNumberCounter] = _roundLength;
        roomTypePerRoom[roomNumberCounter] = RoomType.OPEN;
        gameTypeInRoom[roomNumberCounter] = _gameType;
        oracleKeyPerRoom[roomNumberCounter] = _oracleKey;

        // open room properties
        numberOfAlowedPlayersInRoom[roomNumberCounter] = _amuontOfPlayersinRoom;

        // adding amount
        buyInPerPlayerRerRoom[roomNumberCounter] = _buyInAmount;

        // first emit event for room creation
        emit RoomCreated(msg.sender, roomNumberCounter, RoomType.OPEN, _gameType);

        // automaticlly sign up owner of a group as first player
        _signUpOwnerIntoRoom(msg.sender, roomNumberCounter);

        roomPublished[roomNumberCounter] = true;
    }

    function createClosedRoom(
        bytes32 _oracleKey,
        GameType _gameType,
        address[] calldata _alowedPlayers,
        uint _buyInAmount,
        uint _roomSignUpPeriod,
        uint _numberOfRoundsInRoom,
        uint _roundChoosingLength,
        uint _roundLength
    ) external {
        require(_buyInAmount >= minBuyIn, "Buy in must be greather then minimum");
        require(_roomSignUpPeriod >= minTimeSignUp, "Sign in period lower then minimum");
        require(_numberOfRoundsInRoom >= minNumberOfRounds, "Must be more minimum rounds");
        require(_roundChoosingLength >= minChooseTime, "Round chosing lower then minimum");
        require(_roundLength >= minRoundTime, "Round length lower then minimum");
        require(_roundLength >= _roundChoosingLength + offsetBeteweenChooseAndEndRound, "Offset lower then minimum");
        require(
            _alowedPlayers.length > 0 && _alowedPlayers.length < maxPlayersInClosedRoom,
            "Need to have allowed player which number is not greather then max allowed players"
        );
        require(isAssetAllowed(_oracleKey), "Not allowed assets");
        require(rewardToken.balanceOf(msg.sender) >= _buyInAmount, "No enough sUSD's");
        require(rewardToken.allowance(msg.sender, address(this)) >= _buyInAmount, "No allowance.");

        // set room_id
        roomNumberCounter++;

        // setting global room variables
        roomOwner[roomNumberCounter] = msg.sender;
        roomCreationTime[roomNumberCounter] = block.timestamp;
        roomSignUpPeriod[roomNumberCounter] = _roomSignUpPeriod;
        numberOfRoundsInRoom[roomNumberCounter] = _numberOfRoundsInRoom;
        roundChoosingLengthInRoom[roomNumberCounter] = _roundChoosingLength;
        roundLengthInRoom[roomNumberCounter] = _roundLength;
        roomTypePerRoom[roomNumberCounter] = RoomType.CLOSED;
        gameTypeInRoom[roomNumberCounter] = _gameType;
        oracleKeyPerRoom[roomNumberCounter] = _oracleKey;

        // closed room properies
        alowedPlayersPerRoom[roomNumberCounter] = _alowedPlayers;
        alowedPlayersPerRoom[roomNumberCounter].push(msg.sender);
        numberOfAlowedPlayersInRoom[roomNumberCounter] = alowedPlayersPerRoom[roomNumberCounter].length;

        for (uint i = 0; i < alowedPlayersPerRoom[roomNumberCounter].length; i++) {
            playerCanPlayInRoom[roomNumberCounter][alowedPlayersPerRoom[roomNumberCounter][i]] = true;
        }

        // adding amount
        buyInPerPlayerRerRoom[roomNumberCounter] = _buyInAmount;

        // first emit event for room creation
        emit RoomCreated(msg.sender, roomNumberCounter, RoomType.CLOSED, _gameType);

        // automaticlly sign up owner of a group as first player
        _signUpOwnerIntoRoom(msg.sender, roomNumberCounter);

        roomPublished[roomNumberCounter] = true;
    }

    /* ========== GAME ========== */

    function signUpForRoom(uint _roomNumber) external {
        require(roomPublished[_roomNumber], "Room deleted or not published yet");
        require(
            block.timestamp < (roomCreationTime[_roomNumber] + roomSignUpPeriod[_roomNumber]),
            "Sign up period has expired"
        );
        require(playerSignedUpPerRoom[_roomNumber][msg.sender] == 0, "Player already signed up, for this room.");
        require(
            (roomTypePerRoom[_roomNumber] == RoomType.CLOSED && isPlayerAllowed(msg.sender, _roomNumber)) ||
                (roomTypePerRoom[_roomNumber] == RoomType.OPEN && haveSpaceInRoom(_roomNumber)),
            "Can not sign up for room, not allowed or it is full"
        );
        require(rewardToken.balanceOf(msg.sender) >= buyInPerPlayerRerRoom[_roomNumber], "No enough sUSD's");
        require(rewardToken.allowance(msg.sender, address(this)) >= buyInPerPlayerRerRoom[_roomNumber], "No allowance.");

        numberOfPlayersInRoom[_roomNumber]++;
        playerSignedUpPerRoom[_roomNumber][msg.sender] = block.timestamp;

        _buyIn(msg.sender, _roomNumber, buyInPerPlayerRerRoom[_roomNumber]);

        emit SignedUpInARoom(msg.sender, _roomNumber);
    }

    function startRoyaleInRoom(uint _roomNumber) external onlyRoomParticipants(_roomNumber) {
        require(roomPublished[_roomNumber], "Room deleted or not published yet");
        require(
            block.timestamp > (roomCreationTime[_roomNumber] + roomSignUpPeriod[_roomNumber]),
            "Can not start until signup period expires for that room"
        );
        require(!roomStarted[_roomNumber], "Royale already started for that room");

        roundTargetPriceInRoom[_roomNumber] = priceFeed.rateForCurrency(oracleKeyPerRoom[_roomNumber]);
        targetPricePerRoundPerRoom[_roomNumber][1] = roundTargetPriceInRoom[_roomNumber];
        roomStarted[_roomNumber] = true;
        currentRoundInRoom[_roomNumber] = 1;
        roundStartTimeInRoom[_roomNumber] = block.timestamp;
        roundEndTimeInRoom[_roomNumber] = roundStartTimeInRoom[_roomNumber] + roundLengthInRoom[_roomNumber];
        totalPlayersInARoomInARound[_roomNumber][1] = numberOfPlayersInRoom[_roomNumber];
        unclaimedRewardPerRoom[_roomNumber] = rewardPerRoom[_roomNumber];

        emit RoyaleStartedForRoom(_roomNumber, numberOfPlayersInRoom[_roomNumber], rewardPerRoom[_roomNumber]);
    }

    function takeAPositionInRoom(uint _roomNumber, uint _position) external onlyRoomParticipants(_roomNumber) {
        require(_position == DOWN || _position == UP, "Position can only be 1 or 2");
        require(roomStarted[_roomNumber], "Competition not started yet");
        require(!roomFinished[_roomNumber], "Competition finished");
        require(
            positionInARoundPerRoom[_roomNumber][msg.sender][currentRoundInRoom[_roomNumber]] != _position,
            "Same position"
        );

        if (currentRoundInRoom[_roomNumber] != 1) {
            require(isPlayerAliveInASpecificRoom(msg.sender, _roomNumber), "Player no longer alive");
        }

        require(
            block.timestamp < roundStartTimeInRoom[_roomNumber] + roundChoosingLengthInRoom[_roomNumber],
            "Round positioning finished"
        );

        // this block is when sender change positions in a round - first reduce
        if (positionInARoundPerRoom[_roomNumber][msg.sender][currentRoundInRoom[_roomNumber]] == DOWN) {
            positionsPerRoundPerRoom[_roomNumber][currentRoundInRoom[_roomNumber]][DOWN] = positionsPerRoundPerRoom[
                _roomNumber
            ][currentRoundInRoom[_roomNumber]][DOWN]
                .sub(1);
        } else if (positionInARoundPerRoom[_roomNumber][msg.sender][currentRoundInRoom[_roomNumber]] == UP) {
            positionsPerRoundPerRoom[_roomNumber][currentRoundInRoom[_roomNumber]][UP] = positionsPerRoundPerRoom[
                _roomNumber
            ][currentRoundInRoom[_roomNumber]][UP]
                .sub(1);
        }

        // set new value
        positionInARoundPerRoom[_roomNumber][msg.sender][currentRoundInRoom[_roomNumber]] = _position;

        // add number of positions
        if (_position == UP) {
            positionsPerRoundPerRoom[_roomNumber][currentRoundInRoom[_roomNumber]][_position]++;
        } else {
            positionsPerRoundPerRoom[_roomNumber][currentRoundInRoom[_roomNumber]][_position]++;
        }

        emit TookAPosition(msg.sender, _roomNumber, currentRoundInRoom[_roomNumber], _position);
    }

    function closeRoundInARoom(uint _roomNumber) external onlyRoomParticipants(_roomNumber) {
        require(roomStarted[_roomNumber], "Competition not started yet");
        require(!roomFinished[_roomNumber], "Competition finished");
        require(
            block.timestamp > (roundStartTimeInRoom[_roomNumber] + roundLengthInRoom[_roomNumber]),
            "Can not close round yet"
        );

        uint currentRound = currentRoundInRoom[_roomNumber];
        uint nextRound = currentRound + 1;

        // getting price
        uint currentPriceFromOracle = priceFeed.rateForCurrency(oracleKeyPerRoom[_roomNumber]);

        finalPricePerRoundPerRoom[_roomNumber][currentRound] = currentPriceFromOracle;
        roundResultPerRoom[_roomNumber][currentRound] = currentPriceFromOracle >= roundTargetPriceInRoom[_roomNumber]
            ? UP
            : DOWN;
        roundTargetPriceInRoom[_roomNumber] = currentPriceFromOracle;

        uint winningPositionsPerRound =
            roundResultPerRoom[_roomNumber][currentRound] == UP
                ? positionsPerRoundPerRoom[_roomNumber][currentRound][UP]
                : positionsPerRoundPerRoom[_roomNumber][currentRound][DOWN];
        uint losingPositions =
            roundResultPerRoom[_roomNumber][currentRound] == DOWN
                ? positionsPerRoundPerRoom[_roomNumber][currentRound][UP]
                : positionsPerRoundPerRoom[_roomNumber][currentRound][DOWN];

        if (nextRound <= numberOfRoundsInRoom[_roomNumber] || gameTypeInRoom[_roomNumber] == GameType.LAST_MAN_STANDING) {
            // setting total players for next round (round + 1) to be result of position in a previous round
            if (winningPositionsPerRound == 0 && gameTypeInRoom[_roomNumber] == GameType.LAST_MAN_STANDING) {
                totalPlayersInARoomInARound[_roomNumber][nextRound] = losingPositions;
            } else {
                totalPlayersInARoomInARound[_roomNumber][nextRound] = winningPositionsPerRound;
            }
        }

        // setting eliminated players to be total players - number of winning players
        if (winningPositionsPerRound == 0 && gameTypeInRoom[_roomNumber] == GameType.LAST_MAN_STANDING) {
            eliminatedPerRoundPerRoom[_roomNumber][currentRound] =
                totalPlayersInARoomInARound[_roomNumber][currentRound] -
                losingPositions;
        } else {
            eliminatedPerRoundPerRoom[_roomNumber][currentRound] =
                totalPlayersInARoomInARound[_roomNumber][currentRound] -
                winningPositionsPerRound;
        }

        // if no one is left no need to set values
        if (
            winningPositionsPerRound > 0 ||
            (winningPositionsPerRound == 0 && gameTypeInRoom[_roomNumber] == GameType.LAST_MAN_STANDING)
        ) {
            currentRoundInRoom[_roomNumber] = nextRound;
            targetPricePerRoundPerRoom[_roomNumber][nextRound] = roundTargetPriceInRoom[_roomNumber];
            isReversedPositioningInRoom[_roomNumber] = false;
        }

        // IF number of rounds is limmited and next round is crosses that limmit
        // OR winning people is less or equal to 1 FINISH game (LIMITED_NUMBER_OF_ROUNDS)
        // OR winning people is equal to 1 FINISH game (LAST_MAN_STANDING)
        if (
            (nextRound > numberOfRoundsInRoom[_roomNumber] &&
                gameTypeInRoom[_roomNumber] == GameType.LIMITED_NUMBER_OF_ROUNDS) ||
            (winningPositionsPerRound <= 1 && gameTypeInRoom[_roomNumber] == GameType.LIMITED_NUMBER_OF_ROUNDS) ||
            (winningPositionsPerRound == 1 && gameTypeInRoom[_roomNumber] == GameType.LAST_MAN_STANDING)
        ) {
            roomFinished[_roomNumber] = true;
            uint numberOfWinneres = 0;

            // in no one is winner pick from lest round
            if (winningPositionsPerRound == 0) {
                numberOfWinneres = totalPlayersInARoomInARound[_roomNumber][currentRound];
                _populateRewardForRoom(_roomNumber, totalPlayersInARoomInARound[_roomNumber][currentRound]);
                emit SplitBetweenLoosers(_roomNumber, currentRound, totalPlayersInARoomInARound[_roomNumber][currentRound]);
            } else {
                // there is min 1 winner
                numberOfWinneres = winningPositionsPerRound;
                _populateRewardForRoom(_roomNumber, winningPositionsPerRound);
            }

            roomEndTime[_roomNumber] = block.timestamp;
            // first close previous round then royale
            emit RoundClosedInRoom(_roomNumber, currentRound, roundResultPerRoom[_roomNumber][currentRound]);
            emit RoyaleFinishedForRoom(_roomNumber, numberOfWinneres, rewardPerWinnerPerRoom[_roomNumber]);
        } else {
            // need to reverse result because of isPlayerAliveInASpecificRoom() in positioning a new round so the play can continue
            if (winningPositionsPerRound == 0 && gameTypeInRoom[_roomNumber] == GameType.LAST_MAN_STANDING) {
                isReversedPositioningInRoom[_roomNumber] = true;
            }

            roundStartTimeInRoom[_roomNumber] = block.timestamp;
            roundEndTimeInRoom[_roomNumber] = roundStartTimeInRoom[_roomNumber] + roundLengthInRoom[_roomNumber];
            emit RoundClosedInRoom(_roomNumber, currentRound, roundResultPerRoom[_roomNumber][currentRound]);
        }
    }

    function claimRewardForRoom(uint _roomNumber) external onlyWinners(_roomNumber) {
        require(rewardPerRoom[_roomNumber] > 0, "Reward must be set");
        require(!rewardCollectedPerRoom[_roomNumber][msg.sender], "Player already collected reward");

        // set collected -> true
        rewardCollectedPerRoom[_roomNumber][msg.sender] = true;
        unclaimedRewardPerRoom[_roomNumber] = unclaimedRewardPerRoom[_roomNumber].sub(rewardPerWinnerPerRoom[_roomNumber]);
        // transfering rewardPerPlayer
        rewardToken.safeTransfer(msg.sender, rewardPerWinnerPerRoom[_roomNumber]);
        // emit event
        emit RewardClaimed(_roomNumber, msg.sender, rewardPerWinnerPerRoom[_roomNumber]);
    }

    /* ========== INTERNALS ========== */

    function _signUpOwnerIntoRoom(address _owner, uint _roomNumber) internal {
        numberOfPlayersInRoom[_roomNumber]++;
        playerSignedUpPerRoom[_roomNumber][_owner] = block.timestamp;
        playersPerRoom[_roomNumber].push(_owner);

        _buyIn(_owner, _roomNumber, buyInPerPlayerRerRoom[_roomNumber]);

        emit SignedUpInARoom(_owner, _roomNumber);
    }

    function _populateRewardForRoom(uint _roomNumber, uint _numberOfWinners) internal {
        rewardPerWinnerPerRoom[_roomNumber] = rewardPerRoom[_roomNumber].div(_numberOfWinners);
    }

    function _buyIn(
        address _sender,
        uint _roomNumber,
        uint _amount
    ) internal {
        (uint amountBuyIn, uint amountSafeBox) = _calculateSafeBoxOnAmount(_amount);

        if (amountSafeBox > 0) {
            rewardToken.safeTransferFrom(_sender, safeBox, amountSafeBox);
        }

        rewardToken.safeTransferFrom(_sender, address(this), amountBuyIn);
        rewardPerRoom[_roomNumber] += amountBuyIn;

        emit BuyIn(_sender, _amount, _roomNumber);
    }

    function _calculateSafeBoxOnAmount(uint _amount) internal view returns (uint, uint) {
        uint amountSafeBox = 0;

        if (safeBoxPercentage > 0) {
            amountSafeBox = _amount.div(100).mul(safeBoxPercentage);
        }

        uint amountBuyIn = _amount.sub(amountSafeBox);

        return (amountBuyIn, amountSafeBox);
    }

    function _isPlayerAliveInASpecificRoomReverseOrder(address player, uint _roomNumber) internal view returns (bool) {
        if (roundResultPerRoom[_roomNumber][currentRoundInRoom[_roomNumber] - 1] == DOWN) {
            return positionInARoundPerRoom[_roomNumber][player][currentRoundInRoom[_roomNumber] - 1] == UP;
        } else if (roundResultPerRoom[_roomNumber][currentRoundInRoom[_roomNumber] - 1] == UP) {
            return positionInARoundPerRoom[_roomNumber][player][currentRoundInRoom[_roomNumber] - 1] == DOWN;
        } else {
            return false;
        }
    }

    function _isPlayerAliveInASpecificRoomNormalOrder(address player, uint _roomNumber) internal view returns (bool) {
        if (currentRoundInRoom[_roomNumber] > 1) {
            return (positionInARoundPerRoom[_roomNumber][player][currentRoundInRoom[_roomNumber] - 1] ==
                roundResultPerRoom[_roomNumber][currentRoundInRoom[_roomNumber] - 1]);
        } else {
            return playerSignedUpPerRoom[_roomNumber][player] != 0;
        }
    }

    /* ========== VIEW ========== */

    function isAssetAllowed(bytes32 _oracleKey) public view returns (bool) {
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            if (allowedAssets[i] == _oracleKey) {
                return true;
            }
        }
        return false;
    }

    function isPlayerAliveInASpecificRoom(address player, uint _roomNumber) public view returns (bool) {
        if (!isReversedPositioningInRoom[_roomNumber]) {
            return _isPlayerAliveInASpecificRoomNormalOrder(player, _roomNumber);
        } else {
            return _isPlayerAliveInASpecificRoomReverseOrder(player, _roomNumber);
        }
    }

    function isPlayerAllowed(address _player, uint _roomNumber) public view returns (bool) {
        return playerCanPlayInRoom[_roomNumber][_player];
    }

    function haveSpaceInRoom(uint _roomNumber) public view returns (bool) {
        return numberOfPlayersInRoom[_roomNumber] < numberOfAlowedPlayersInRoom[roomNumberCounter];
    }

    function isPlayerOwner(address _player, uint _roomNumber) public view returns (bool) {
        return _player == roomOwner[_roomNumber];
    }

    function canStartRoyaleInRoom(uint _roomNumber) public view returns (bool) {
        return
            block.timestamp > (roomCreationTime[_roomNumber] + roomSignUpPeriod[_roomNumber]) && !roomStarted[_roomNumber];
    }

    function canCloseRoundInRoom(uint _roomNumber) public view returns (bool) {
        return
            roomStarted[_roomNumber] &&
            !roomFinished[_roomNumber] &&
            block.timestamp > (roundStartTimeInRoom[_roomNumber] + roundLengthInRoom[_roomNumber]);
    }

    function getPlayersForRoom(uint _room) public view returns (address[] memory) {
        return playersPerRoom[_room];
    }

    /* ========== ROOM MANAGEMENT ========== */

    function setBuyInAmount(uint _roomNumber, uint _buyInAmount) public canChangeRoomVariables(_roomNumber) {
        require(_buyInAmount >= minBuyIn, "Buy in must be greather then minimum");
        require(buyInPerPlayerRerRoom[_roomNumber] != _buyInAmount, "Same amount");

        // if _buyInAmount is increased
        if (_buyInAmount > buyInPerPlayerRerRoom[_roomNumber]) {
            require(
                rewardToken.allowance(msg.sender, address(this)) >= _buyInAmount.sub(buyInPerPlayerRerRoom[_roomNumber]),
                "No allowance."
            );

            _buyIn(msg.sender, _roomNumber, _buyInAmount - buyInPerPlayerRerRoom[_roomNumber]);
            buyInPerPlayerRerRoom[_roomNumber] = _buyInAmount;
            // or decreased
        } else {
            (uint amountBuyIn, ) = _calculateSafeBoxOnAmount(_buyInAmount);
            uint differenceInReward = rewardPerRoom[_roomNumber].sub(amountBuyIn);
            buyInPerPlayerRerRoom[_roomNumber] = _buyInAmount;
            rewardPerRoom[_roomNumber] = amountBuyIn;
            rewardToken.safeTransfer(msg.sender, differenceInReward);
        }

        emit BuyInAmountChanged(_roomNumber, _buyInAmount);
    }

    function setRoundLength(uint _roomNumber, uint _roundLength) public canChangeRoomVariables(_roomNumber) {
        require(_roundLength >= minRoundTime, "Round length lower then minimum");
        require(
            _roundLength >= roundChoosingLengthInRoom[_roomNumber] + offsetBeteweenChooseAndEndRound,
            "Offset lower then minimum"
        );

        roundLengthInRoom[_roomNumber] = _roundLength;

        emit NewRoundLength(_roomNumber, _roundLength);
    }

    function setRoomSignUpPeriod(uint _roomNumber, uint _roomSignUpPeriod) public canChangeRoomVariables(_roomNumber) {
        require(_roomSignUpPeriod >= minTimeSignUp, "Sign in period lower then minimum");

        roomSignUpPeriod[_roomNumber] = _roomSignUpPeriod;

        emit NewRoomSignUpPeriod(_roomNumber, _roomSignUpPeriod);
    }

    function setNumberOfRoundsInRoom(uint _roomNumber, uint _numberOfRoundsInRoom)
        public
        canChangeRoomVariables(_roomNumber)
    {
        require(_numberOfRoundsInRoom > minNumberOfRounds, "Must be more then minimum");

        numberOfRoundsInRoom[_roomNumber] = _numberOfRoundsInRoom;

        emit NewNumberOfRounds(_roomNumber, _numberOfRoundsInRoom);
    }

    function setRoundChoosingLength(uint _roomNumber, uint _roundChoosingLength) public canChangeRoomVariables(_roomNumber) {
        require(_roundChoosingLength >= minChooseTime, "Round chosing lower then minimum");
        require(
            roundLengthInRoom[_roomNumber] >= _roundChoosingLength + offsetBeteweenChooseAndEndRound,
            "Round length lower then minimum"
        );

        roundChoosingLengthInRoom[_roomNumber] = _roundChoosingLength;

        emit NewRoundChoosingLength(_roomNumber, _roundChoosingLength);
    }

    function setOracleKey(uint _roomNumber, bytes32 _oracleKey) public canChangeRoomVariables(_roomNumber) {
        require(isAssetAllowed(_oracleKey), "Not allowed assets");

        oracleKeyPerRoom[_roomNumber] = _oracleKey;

        emit NewOracleKeySetForRoom(_roomNumber, _oracleKey);
    }

    function setNewAllowedPlayersPerRoomClosedRoom(uint _roomNumber, address[] memory _alowedPlayers)
        public
        canChangeRoomVariables(_roomNumber)
    {
        require(
            roomTypePerRoom[_roomNumber] == RoomType.CLOSED && _alowedPlayers.length > 0,
            "Room need to be closed and  allowed players not empty"
        );

        // setting players - no play
        for (uint i = 0; i < alowedPlayersPerRoom[roomNumberCounter].length; i++) {
            playerCanPlayInRoom[roomNumberCounter][alowedPlayersPerRoom[roomNumberCounter][i]] = false;
        }

        // setting players that can play
        alowedPlayersPerRoom[_roomNumber] = _alowedPlayers;
        alowedPlayersPerRoom[_roomNumber].push(msg.sender);
        numberOfAlowedPlayersInRoom[_roomNumber] = alowedPlayersPerRoom[_roomNumber].length;

        for (uint i = 0; i < alowedPlayersPerRoom[_roomNumber].length; i++) {
            playerCanPlayInRoom[_roomNumber][alowedPlayersPerRoom[_roomNumber][i]] = true;
        }

        emit NewPlayersAllowed(_roomNumber, numberOfAlowedPlayersInRoom[_roomNumber]);
    }

    function addAllowedPlayerPerRoomClosedRoom(uint _roomNumber, address _alowedPlayer)
        public
        canChangeRoomVariables(_roomNumber)
    {
        require(roomTypePerRoom[_roomNumber] == RoomType.CLOSED, "Type of room needs to be closed");
        require(!playerCanPlayInRoom[_roomNumber][_alowedPlayer], "Already allowed");

        alowedPlayersPerRoom[_roomNumber].push(_alowedPlayer);
        playerCanPlayInRoom[_roomNumber][_alowedPlayer] = true;
        numberOfAlowedPlayersInRoom[_roomNumber]++;

        emit NewPlayerAddedIntoRoom(_roomNumber, _alowedPlayer);
    }

    function setAmuontOfPlayersInOpenRoom(uint _roomNumber, uint _amuontOfPlayersinRoom)
        public
        canChangeRoomVariables(_roomNumber)
    {
        require(
            roomTypePerRoom[_roomNumber] == RoomType.OPEN && _amuontOfPlayersinRoom > 1,
            "Must be more then one player and open room"
        );

        numberOfAlowedPlayersInRoom[_roomNumber] = _amuontOfPlayersinRoom;

        emit NewAmountOfPlayersInOpenRoom(_roomNumber, _amuontOfPlayersinRoom);
    }

    function deleteRoom(uint _roomNumber) public canChangeRoomVariables(_roomNumber) {
        require(roomPublished[_roomNumber], "Already deleted");

        roomPublished[_roomNumber] = false;
        rewardToken.safeTransfer(msg.sender, buyInPerPlayerRerRoom[_roomNumber]);

        emit RoomDeleted(_roomNumber, msg.sender);
    }

    /* ========== CONTRACT MANAGEMENT ========== */

    function addAsset(bytes32 _asset) public onlyOwner {
        allowedAssets.push(_asset);
        emit NewAssetAllowed(_asset);
    }

    function setPriceFeed(IPriceFeed _priceFeed) public onlyOwner {
        priceFeed = _priceFeed;
        emit NewPriceFeed(_priceFeed);
    }

    function setMinTimeSignUp(uint _minTimeSignUp) public onlyOwner {
        minTimeSignUp = _minTimeSignUp;
        emit NewMinTimeSignUp(_minTimeSignUp);
    }

    function setMinRoundTime(uint _minRoundTime) public onlyOwner {
        minRoundTime = _minRoundTime;
        emit NewMinRoundTime(_minRoundTime);
    }

    function setMinChooseTime(uint _minChooseTime) public onlyOwner {
        minChooseTime = _minChooseTime;
        emit NewMinChooseTime(_minChooseTime);
    }

    function setOffsetBeteweenChooseAndEndRound(uint _offsetBeteweenChooseAndEndRound) public onlyOwner {
        offsetBeteweenChooseAndEndRound = _offsetBeteweenChooseAndEndRound;
        emit NewOffsetBeteweenChooseAndEndRound(_offsetBeteweenChooseAndEndRound);
    }

    function setMaxPlayersInClosedRoom(uint _maxPlayersInClosedRoom) public onlyOwner {
        maxPlayersInClosedRoom = _maxPlayersInClosedRoom;
        emit NewMaxPlayersInClosedRoom(_maxPlayersInClosedRoom);
    }

    function setMinBuyIn(uint _minBuyIn) public onlyOwner {
        minBuyIn = _minBuyIn;
        emit NewMinBuyIn(_minBuyIn);
    }

    function setSafeBoxPercentage(uint _safeBoxPercentage) public onlyOwner {
        require(_safeBoxPercentage >= 0 && _safeBoxPercentage <= 100, "Must be in between 0 and 100 %");
        safeBoxPercentage = _safeBoxPercentage;
        emit NewSafeBoxPercentage(_safeBoxPercentage);
    }

    function setSafeBox(address _safeBox) public onlyOwner {
        safeBox = _safeBox;
        emit NewSafeBox(_safeBox);
    }

    function pullFunds(address payable _account) external onlyOwner {
        rewardToken.safeTransfer(_account, rewardToken.balanceOf(address(this)));
        emit PullFunds(_account, rewardToken.balanceOf(address(this)));
    }

    /* ========== MODIFIERS ========== */

    modifier canChangeRoomVariables(uint _roomNumber) {
        require(msg.sender == roomOwner[_roomNumber], "You are not owner of room.");
        require(numberOfPlayersInRoom[_roomNumber] < 2, "Player already sign up for room, no change allowed");
        require(roomPublished[_roomNumber], "Deleted room");
        _;
    }

    modifier onlyRoomParticipants(uint _roomNumber) {
        require(playerSignedUpPerRoom[_roomNumber][msg.sender] != 0, "You are not room participant");
        _;
    }

    modifier onlyWinners(uint _roomNumber) {
        require(roomFinished[_roomNumber], "Royale must be finished!");
        require(isPlayerAliveInASpecificRoom(msg.sender, _roomNumber) == true, "Player is not alive");
        _;
    }

    /* ========== EVENTS ========== */

    event RoomCreated(address _owner, uint _roomNumberCounter, RoomType _roomType, GameType _gameType);
    event SignedUpInARoom(address _account, uint _roomNumber);
    event RoyaleStartedForRoom(uint _roomNumber, uint _playersNumber, uint _totalReward);
    event TookAPosition(address _user, uint _roomNumber, uint _round, uint _position);
    event RoundClosedInRoom(uint _roomNumber, uint _round, uint _result);
    event SplitBetweenLoosers(uint _roomNumber, uint _round, uint _numberOfPlayers);
    event RoyaleFinishedForRoom(uint _roomNumber, uint _numberOfWinners, uint _rewardPerWinner);
    event BuyIn(address _user, uint _amount, uint _roomNumber);
    event RewardClaimed(uint _roomNumber, address _winner, uint _reward);
    event NewAmountOfPlayersInOpenRoom(uint _roomNumber, uint _amuontOfPlayersinRoom);
    event NewPlayerAddedIntoRoom(uint _roomNumber, address _alowedPlayer);
    event NewPlayersAllowed(uint _roomNumber, uint _numberOfPlayers);
    event NewOracleKeySetForRoom(uint _roomNumber, bytes32 _oracleKey);
    event BuyInAmountChanged(uint _roomNumber, uint _buyInAmount);
    event NewRoundLength(uint _roomNumber, uint _roundLength);
    event NewRoundChoosingLength(uint _roomNumber, uint _roundChoosingLength);
    event NewRoomSignUpPeriod(uint _roomNumber, uint _signUpPeriod);
    event NewNumberOfRounds(uint _roomNumber, uint _numberRounds);
    event RoomDeleted(uint _roomNumber, address _roomOwner);
    event NewAssetAllowed(bytes32 _asset);
    event NewPriceFeed(IPriceFeed _priceFeed);
    event NewMinTimeSignUp(uint _minTimeSignUp);
    event NewMinRoundTime(uint _minRoundTime);
    event NewMinChooseTime(uint _minChooseTime);
    event NewOffsetBeteweenChooseAndEndRound(uint _offsetBeteweenChooseAndEndRound);
    event NewMaxPlayersInClosedRoom(uint _maxPlayersInClosedRoom);
    event NewMinBuyIn(uint _minBuyIn);
    event PullFunds(address _account, uint _amount);
    event NewSafeBoxPercentage(uint _safeBoxPercentage);
    event NewSafeBox(address _safeBox);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// interfaces
import "../interfaces/IPriceFeed.sol";
import "../interfaces/IThalesRoyalePass.sol";
import "../interfaces/IThalesRoyalePassport.sol";
import "../interfaces/IPassportPosition.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

contract ThalesRoyale is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    /* ========== LIBRARIES ========== */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS =========== */

    uint public constant DOWN = 1;
    uint public constant UP = 2;

    /* ========== STATE VARIABLES ========== */

    IERC20Upgradeable public rewardToken;
    bytes32 public oracleKey;
    IPriceFeed public priceFeed;

    address public safeBox;
    uint public safeBoxPercentage;

    uint public rounds;
    uint public signUpPeriod;
    uint public roundChoosingLength;
    uint public roundLength;

    bool public nextSeasonStartsAutomatically;
    uint public pauseBetweenSeasonsTime;

    uint public roundTargetPrice;
    uint public buyInAmount;

    /* ========== SEASON VARIABLES ========== */

    uint public season;

    mapping(uint => uint) public rewardPerSeason;
    mapping(uint => uint) public signedUpPlayersCount;
    mapping(uint => uint) public roundInASeason;
    mapping(uint => bool) public seasonStarted;
    mapping(uint => bool) public seasonFinished;
    mapping(uint => uint) public seasonCreationTime;
    mapping(uint => bool) public royaleInSeasonStarted;
    mapping(uint => uint) public royaleSeasonEndTime;
    mapping(uint => uint) public roundInSeasonEndTime;
    mapping(uint => uint) public roundInASeasonStartTime;
    mapping(uint => address[]) public playersPerSeason;
    mapping(uint => mapping(address => uint256)) public playerSignedUpPerSeason;
    mapping(uint => mapping(uint => uint)) public roundResultPerSeason;
    mapping(uint => mapping(uint => uint)) public targetPricePerRoundPerSeason;
    mapping(uint => mapping(uint => uint)) public finalPricePerRoundPerSeason;
    mapping(uint => mapping(uint256 => mapping(uint256 => uint256))) public positionsPerRoundPerSeason;
    mapping(uint => mapping(uint => uint)) public totalPlayersPerRoundPerSeason;
    mapping(uint => mapping(uint => uint)) public eliminatedPerRoundPerSeason;

    mapping(uint => mapping(address => mapping(uint256 => uint256))) public positionInARoundPerSeason;
    mapping(uint => mapping(address => bool)) public rewardCollectedPerSeason;
    mapping(uint => uint) public rewardPerWinnerPerSeason;
    mapping(uint => uint) public unclaimedRewardPerSeason;

    IThalesRoyalePass public royalePass;
    mapping(uint => bytes32) public oracleKeyPerSeason;

    IThalesRoyalePassport public thalesRoyalePassport;

    mapping(uint => uint) public mintedTokensCount;
    mapping(uint => uint[]) public tokensPerSeason;
    mapping(uint => uint) public tokenSeason;
    mapping(uint => mapping(uint => uint256)) public tokensMintedPerSeason;
    mapping(uint => mapping(uint => uint)) public totalTokensPerRoundPerSeason;
    mapping(uint => mapping(uint256 => uint256)) public tokenPositionInARoundPerSeason;
    mapping(uint => IPassportPosition.Position[]) public tokenPositions;
    mapping(uint => bool) public tokenRewardCollectedPerSeason;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _owner,
        bytes32 _oracleKey,
        IPriceFeed _priceFeed,
        address _rewardToken,
        uint _rounds,
        uint _signUpPeriod,
        uint _roundChoosingLength,
        uint _roundLength,
        uint _buyInAmount,
        uint _pauseBetweenSeasonsTime,
        bool _nextSeasonStartsAutomatically
    ) external initializer {
        setOwner(_owner);
        initNonReentrant();
        oracleKey = _oracleKey;
        priceFeed = _priceFeed;
        rewardToken = IERC20Upgradeable(_rewardToken);
        rounds = _rounds;
        signUpPeriod = _signUpPeriod;
        roundChoosingLength = _roundChoosingLength;
        roundLength = _roundLength;
        buyInAmount = _buyInAmount;
        pauseBetweenSeasonsTime = _pauseBetweenSeasonsTime;
        nextSeasonStartsAutomatically = _nextSeasonStartsAutomatically;
    }

    /* ========== GAME ========== */

    function signUp() external playerCanSignUp {
        uint[] memory positions = new uint[](rounds);
        for(uint i = 0; i < positions.length; i++) {
            positions[i] = 0;
        }
        _signUpPlayer(msg.sender, positions, 0);
    }

    function signUpWithPosition(uint[] memory _positions) external playerCanSignUp {
        require(_positions.length == rounds, "Number of positions exceeds number of rounds");
        for(uint i = 0; i < _positions.length; i++) {
            require(_positions[i] == DOWN || _positions[i] == UP, "Position can only be 1 or 2");
        }
        _signUpPlayer(msg.sender, _positions, 0);
    }

    function signUpWithPass(uint passId) external playerCanSignUpWithPass(passId) {
        uint[] memory positions = new uint[](rounds);
        for(uint i = 0; i < positions.length; i++) {
            positions[i] = 0;
        }
        _signUpPlayer(msg.sender, positions, passId);
    }

    function signUpWithPassWithPosition(uint passId, uint[] memory _positions) external playerCanSignUpWithPass(passId) {
        require(_positions.length == rounds, "Number of positions exceeds number of rounds");
        for(uint i = 0; i < _positions.length; i++) {
            require(_positions[i] == DOWN || _positions[i] == UP, "Position can only be 1 or 2");
        }
        _signUpPlayer(msg.sender, _positions, passId);
    }

    function signUpOnBehalf(address player) external playerCanSignUp {
        // don't set positions to winners
        uint[] memory positions = new uint[](rounds);
        for(uint i = 0; i < positions.length; i++) {
            positions[i] = 0;
        }

        // pass id is 0 so it will be sUSD buyin
        _signUpPlayerOnBehalf(msg.sender, player, positions);
    }

    function startRoyaleInASeason() external {
        require(block.timestamp > (seasonCreationTime[season] + signUpPeriod), "Can't start until signup period expires");
        require(mintedTokensCount[season] > 0, "Can not start, no tokens in a season");
        require(!royaleInSeasonStarted[season], "Already started");
        require(seasonStarted[season], "Season not started yet");

        roundTargetPrice = priceFeed.rateForCurrency(oracleKeyPerSeason[season]);
        roundInASeason[season] = 1;
        targetPricePerRoundPerSeason[season][roundInASeason[season]] = roundTargetPrice;
        royaleInSeasonStarted[season] = true;
        roundInASeasonStartTime[season] = block.timestamp;
        roundInSeasonEndTime[season] = roundInASeasonStartTime[season] + roundLength;
        totalTokensPerRoundPerSeason[season][roundInASeason[season]] = mintedTokensCount[season];

        unclaimedRewardPerSeason[season] = rewardPerSeason[season];

        emit RoyaleStarted(season, mintedTokensCount[season], rewardPerSeason[season]);
    }

    function takeAPosition(uint tokenId, uint position) external {
        require(position == DOWN || position == UP, "Position can only be 1 or 2");
        require(msg.sender == thalesRoyalePassport.ownerOf(tokenId), "Not an owner");
        require(season == tokenSeason[tokenId], "Wrong season");
        require(royaleInSeasonStarted[season], "Competition not started yet");
        require(!seasonFinished[season], "Competition finished");

        require(tokenPositionInARoundPerSeason[tokenId][roundInASeason[season]] != position, "Same position");

        if (roundInASeason[season] != 1) {
            require(isTokenAlive(tokenId),"Token no longer valid");
        }

        require(block.timestamp < roundInASeasonStartTime[season] + roundChoosingLength, "Round positioning finished");

        // this block is when sender change positions in a round - first reduce
        if (tokenPositionInARoundPerSeason[tokenId][roundInASeason[season]] == DOWN) {
            positionsPerRoundPerSeason[season][roundInASeason[season]][DOWN]--;
        } else if (tokenPositionInARoundPerSeason[tokenId][roundInASeason[season]] == UP) {
            positionsPerRoundPerSeason[season][roundInASeason[season]][UP]--;
        }

        _putPosition(msg.sender, season, roundInASeason[season], position, tokenId);
    }

    function closeRound() external {
        require(royaleInSeasonStarted[season], "Competition not started yet");
        require(!seasonFinished[season], "Competition finished");
        require(block.timestamp > (roundInASeasonStartTime[season] + roundLength), "Can't close round yet");

        uint currentSeasonRound = roundInASeason[season];
        uint nextRound = currentSeasonRound + 1;

        // getting price
        uint currentPriceFromOracle = priceFeed.rateForCurrency(oracleKeyPerSeason[season]);

        require(currentPriceFromOracle > 0, "Oracle Price must be larger than 0");

        uint stikePrice = roundTargetPrice;

        finalPricePerRoundPerSeason[season][currentSeasonRound] = currentPriceFromOracle;
        roundResultPerSeason[season][currentSeasonRound] = currentPriceFromOracle >= stikePrice ? UP : DOWN;
        uint losingResult = currentPriceFromOracle >= stikePrice ? DOWN : UP;
        roundTargetPrice = currentPriceFromOracle;

        uint winningPositionsPerRound =
            roundResultPerSeason[season][currentSeasonRound] == UP
                ? positionsPerRoundPerSeason[season][currentSeasonRound][UP]
                : positionsPerRoundPerSeason[season][currentSeasonRound][DOWN];

        if (nextRound <= rounds) {
            // setting total players for next round (round + 1) to be result of position in a previous round
            totalTokensPerRoundPerSeason[season][nextRound] = winningPositionsPerRound;
        }

        // setting eliminated players to be total players - number of winning players
        eliminatedPerRoundPerSeason[season][currentSeasonRound] =
            totalTokensPerRoundPerSeason[season][currentSeasonRound] -
            winningPositionsPerRound;

        _cleanPositions(losingResult, nextRound);

        // if no one is left no need to set values
        if (winningPositionsPerRound > 0) {
            roundInASeason[season] = nextRound;
            targetPricePerRoundPerSeason[season][nextRound] = roundTargetPrice;
        }

        if (nextRound > rounds || winningPositionsPerRound <= 1) {
            seasonFinished[season] = true;

            uint numberOfWinners = 0;

            // in no one is winner pick from lest round
            if (winningPositionsPerRound == 0) {
                numberOfWinners = totalTokensPerRoundPerSeason[season][currentSeasonRound];
                _populateReward(numberOfWinners);
            } else {
                // there is min 1 winner
                numberOfWinners = winningPositionsPerRound;
                _populateReward(numberOfWinners);
            }

            royaleSeasonEndTime[season] = block.timestamp;
            // first close previous round then royale
            emit RoundClosed(
                season,
                currentSeasonRound,
                roundResultPerSeason[season][currentSeasonRound],
                stikePrice,
                finalPricePerRoundPerSeason[season][currentSeasonRound],
                eliminatedPerRoundPerSeason[season][currentSeasonRound],
                numberOfWinners
            );
            emit RoyaleFinished(season, numberOfWinners, rewardPerWinnerPerSeason[season]);
        } else {
            roundInASeasonStartTime[season] = block.timestamp;
            roundInSeasonEndTime[season] = roundInASeasonStartTime[season] + roundLength;
            emit RoundClosed(
                season,
                currentSeasonRound,
                roundResultPerSeason[season][currentSeasonRound],
                stikePrice,
                finalPricePerRoundPerSeason[season][currentSeasonRound],
                eliminatedPerRoundPerSeason[season][currentSeasonRound],
                winningPositionsPerRound
            );
        }
    }

    function startNewSeason() external seasonCanStart {
        season = season + 1;
        seasonCreationTime[season] = block.timestamp;
        seasonStarted[season] = true;
        oracleKeyPerSeason[season] = oracleKey;

        emit NewSeasonStarted(season);
    }

    function claimRewardForSeason(uint _season, uint tokenId) external onlyWinners(_season, tokenId) {
        _claimRewardForSeason(msg.sender, _season, tokenId);
    }

    /* ========== VIEW ========== */

    function canCloseRound() public view returns (bool) {
        return
            royaleInSeasonStarted[season] &&
            !seasonFinished[season] &&
            block.timestamp > (roundInASeasonStartTime[season] + roundLength);
    }

    function canStartRoyale() public view returns (bool) {
        return
            seasonStarted[season] &&
            !royaleInSeasonStarted[season] &&
            block.timestamp > (seasonCreationTime[season] + signUpPeriod);
    }

    function canSeasonBeAutomaticallyStartedAfterSomePeriod() public view returns (bool) {
        return nextSeasonStartsAutomatically && (block.timestamp > seasonCreationTime[season] + pauseBetweenSeasonsTime);
    }

    function canStartNewSeason() public view returns (bool) {
        return canSeasonBeAutomaticallyStartedAfterSomePeriod() && (seasonFinished[season] || season == 0);
    }

    function hasParticipatedInCurrentOrLastRoyale(address _player) external view returns (bool) {
        if (season > 1) {
            return playerSignedUpPerSeason[season][_player] > 0 || playerSignedUpPerSeason[season - 1][_player] > 0;
        } else {
            return playerSignedUpPerSeason[season][_player] > 0;
        }
    }

    function isTokenAliveInASpecificSeason(uint tokenId, uint _season) public view returns (bool) {
        if(_season != tokenSeason[tokenId]) {
            return false;
        }
        if (roundInASeason[_season] > 1) {
            return (tokenPositionInARoundPerSeason[tokenId][roundInASeason[_season] - 1] ==
                roundResultPerSeason[_season][roundInASeason[_season] - 1]);
        } else {
            return tokensMintedPerSeason[_season][tokenId] != 0;
        }
    }

    function isTokenAlive(uint tokenId) public view returns (bool) {
        if(season != tokenSeason[tokenId]) {
            return false;
        }
        if (roundInASeason[season] > 1) {
            return (tokenPositionInARoundPerSeason[tokenId][roundInASeason[season] - 1] ==
                roundResultPerSeason[season][roundInASeason[season] - 1]);
        } else {
            return tokensMintedPerSeason[season][tokenId] != 0;
        }
    }

    function getTokensForSeason(uint _season) public view returns (uint[] memory) {
        return tokensPerSeason[_season];
    }

    function getTokenPositions(uint tokenId) public view returns (IPassportPosition.Position[] memory) {
        return tokenPositions[tokenId];
    }

    // deprecated from passport impl
    function getPlayersForSeason(uint _season) public view returns (address[] memory) {
        return playersPerSeason[_season];
    }

    function getBuyInAmount() public view returns (uint) {
        return buyInAmount;
    }

    /* ========== INTERNALS ========== */

    function _signUpPlayer(address _player, uint[] memory _positions, uint _passId) internal {
        uint tokenId = thalesRoyalePassport.safeMint(_player);
        tokenSeason[tokenId] = season;

        tokensMintedPerSeason[season][tokenId] = block.timestamp;
        tokensPerSeason[season].push(tokenId);
        mintedTokensCount[season]++;

        playerSignedUpPerSeason[season][_player] = block.timestamp;

        for(uint i = 0; i < _positions.length; i++){
            if(_positions[i] != 0) {
                _putPosition(_player, season, i+1, _positions[i], tokenId);
            }
        }
        if(_passId != 0) {
            _buyInWithPass(_player, _passId);
        } else {
            _buyIn(_player, buyInAmount);
        }

        emit SignedUpPassport(_player, tokenId, season, _positions);
    }

    function _signUpPlayerOnBehalf(address _sender, address _player, uint[] memory _positions) internal {
        uint tokenId = thalesRoyalePassport.safeMint(_player);
        tokenSeason[tokenId] = season;

        tokensMintedPerSeason[season][tokenId] = block.timestamp;
        tokensPerSeason[season].push(tokenId);
        mintedTokensCount[season]++;

        playerSignedUpPerSeason[season][_player] = block.timestamp;

        // sender buy-in
        _buyIn(_sender, buyInAmount);

        emit SignedUpPassport(_player, tokenId, season, _positions);
    }

    function _putPosition(
        address _player,
        uint _season,
        uint _round,
        uint _position,
        uint _tokenId
    ) internal {
        // set value
        positionInARoundPerSeason[_season][_player][_round] = _position;
        // set token value
        tokenPositionInARoundPerSeason[_tokenId][_round] = _position;
        

        if(tokenPositions[_tokenId].length >= _round) {
            tokenPositions[_tokenId][_round - 1] = IPassportPosition.Position(_round, _position);   
        } else {
            tokenPositions[_tokenId].push(IPassportPosition.Position(_round, _position));
        }
        
        // add number of positions
        if (_position == UP) {
            positionsPerRoundPerSeason[_season][_round][_position]++;
        } else {
            positionsPerRoundPerSeason[_season][_round][_position]++;
        }

        emit TookAPositionPassport(_player, _tokenId, _season, _round, _position);
    }

    function _populateReward(uint numberOfWinners) internal {
        require(seasonFinished[season], "Royale must be finished");
        require(numberOfWinners > 0, "There is no alive players left in Royale");

        rewardPerWinnerPerSeason[season] = rewardPerSeason[season] / numberOfWinners;
    }

    function _buyIn(address _sender, uint _amount) internal {
        (uint amountBuyIn, uint amountSafeBox) = _calculateSafeBoxOnAmount(_amount);

        if (amountSafeBox > 0) {
            rewardToken.safeTransferFrom(_sender, safeBox, amountSafeBox);
        }

        rewardToken.safeTransferFrom(_sender, address(this), amountBuyIn);
        rewardPerSeason[season] += amountBuyIn;
    }

    function _buyInWithPass(address _player, uint _passId) internal {
        // burning pass
        royalePass.burnWithTransfer(_player, _passId);

        // increase reward
        rewardPerSeason[season] += buyInAmount;
    }

    function _calculateSafeBoxOnAmount(uint _amount) internal view returns (uint, uint) {
        uint amountSafeBox = 0;

        if (safeBoxPercentage > 0) {
            amountSafeBox = (_amount * safeBoxPercentage) / 100;
        }

        uint amountBuyIn = _amount - amountSafeBox;

        return (amountBuyIn, amountSafeBox);
    }

    function _claimRewardForSeason(address _winner, uint _season, uint _tokenId) internal {
        require(rewardPerSeason[_season] > 0, "Reward must be set");
        require(!tokenRewardCollectedPerSeason[_tokenId], "Reward already collected");
        require(rewardToken.balanceOf(address(this)) >= rewardPerWinnerPerSeason[_season], "Not enough balance for rewards");

        // set collected -> true
        tokenRewardCollectedPerSeason[_tokenId] = true;

        unclaimedRewardPerSeason[_season] = unclaimedRewardPerSeason[_season] - rewardPerWinnerPerSeason[_season];

        // transfering rewardPerToken
        rewardToken.safeTransfer(_winner, rewardPerWinnerPerSeason[_season]);

        // emit event
        emit RewardClaimedPassport(_season, _winner, _tokenId, rewardPerWinnerPerSeason[_season]);
    }

    function _putFunds(
        address _from,
        uint _amount,
        uint _season
    ) internal {
        rewardPerSeason[_season] = rewardPerSeason[_season] + _amount;
        unclaimedRewardPerSeason[_season] = unclaimedRewardPerSeason[_season] + _amount;
        rewardToken.safeTransferFrom(_from, address(this), _amount);
        emit PutFunds(_from, _season, _amount);
    }

    function _cleanPositions(uint _losingPosition, uint _nextRound) internal {
            
        uint[] memory tokens = tokensPerSeason[season];

        for(uint i = 0; i < tokens.length; i++){
            if(tokenPositionInARoundPerSeason[tokens[i]][_nextRound - 1] == _losingPosition
                || tokenPositionInARoundPerSeason[tokens[i]][_nextRound - 1] == 0){
                // decrease position count
                if (tokenPositionInARoundPerSeason[tokens[i]][_nextRound] == DOWN) {
                        positionsPerRoundPerSeason[season][_nextRound][DOWN]--;
                } else if (tokenPositionInARoundPerSeason[tokens[i]][_nextRound] == UP) {
                        positionsPerRoundPerSeason[season][_nextRound][UP]--;
                    }
                // setting 0 position
                tokenPositionInARoundPerSeason[tokens[i]][_nextRound] = 0;
            }
        }
    }

    /* ========== CONTRACT MANAGEMENT ========== */

    function putFunds(uint _amount, uint _season) external {
        require(_amount > 0, "Amount must be more then zero");
        require(_season >= season, "Cant put funds in a past");
        require(!seasonFinished[_season], "Season is finished");
        require(rewardToken.allowance(msg.sender, address(this)) >= _amount, "No allowance.");
        require(rewardToken.balanceOf(msg.sender) >= _amount, "No enough sUSD for buy in");

        _putFunds(msg.sender, _amount, _season);
    }

    function setNextSeasonStartsAutomatically(bool _nextSeasonStartsAutomatically) external onlyOwner {
        nextSeasonStartsAutomatically = _nextSeasonStartsAutomatically;
        emit NewNextSeasonStartsAutomatically(_nextSeasonStartsAutomatically);
    }

    function setPauseBetweenSeasonsTime(uint _pauseBetweenSeasonsTime) external onlyOwner {
        pauseBetweenSeasonsTime = _pauseBetweenSeasonsTime;
        emit NewPauseBetweenSeasonsTime(_pauseBetweenSeasonsTime);
    }

    function setSignUpPeriod(uint _signUpPeriod) external onlyOwner {
        signUpPeriod = _signUpPeriod;
        emit NewSignUpPeriod(_signUpPeriod);
    }

    function setRoundChoosingLength(uint _roundChoosingLength) external onlyOwner {
        roundChoosingLength = _roundChoosingLength;
        emit NewRoundChoosingLength(_roundChoosingLength);
    }

    function setRoundLength(uint _roundLength) external onlyOwner {
        roundLength = _roundLength;
        emit NewRoundLength(_roundLength);
    }

    function setPriceFeed(IPriceFeed _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
        emit NewPriceFeed(_priceFeed);
    }

    function setThalesRoyalePassport(IThalesRoyalePassport _thalesRoyalePassport) external onlyOwner {
        require(address(_thalesRoyalePassport) != address(0), "Invalid address");
        thalesRoyalePassport = _thalesRoyalePassport;
        emit NewThalesRoyalePassport(_thalesRoyalePassport);
    }

    function setBuyInAmount(uint _buyInAmount) external onlyOwner {
        buyInAmount = _buyInAmount;
        emit NewBuyInAmount(_buyInAmount);
    }

    function setSafeBoxPercentage(uint _safeBoxPercentage) external onlyOwner {
        require(_safeBoxPercentage <= 100, "Must be in between 0 and 100 %");
        safeBoxPercentage = _safeBoxPercentage;
        emit NewSafeBoxPercentage(_safeBoxPercentage);
    }

    function setSafeBox(address _safeBox) external onlyOwner {
        require(_safeBox != address(0), "Invalid address");
        safeBox = _safeBox;
        emit NewSafeBox(_safeBox);
    }

    function setRoyalePassAddress(address _royalePass) external onlyOwner {
        require(address(_royalePass) != address(0), "Invalid address");
        royalePass = IThalesRoyalePass(_royalePass);
        emit NewThalesRoyalePass(_royalePass);
    }

    function setOracleKey(bytes32 _oracleKey) external onlyOwner {
        oracleKey = _oracleKey;
        emit NewOracleKey(_oracleKey);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        require(address(_rewardToken) != address(0), "Invalid address");
        rewardToken = IERC20Upgradeable(_rewardToken);
        emit NewRewardToken(_rewardToken);
    }

    function setNumberOfRounds(uint _rounds) external onlyOwner {
        rounds = _rounds;
        emit NewNumberOfRounds(_rounds);
    }

    /* ========== MODIFIERS ========== */

    modifier playerCanSignUp() {
        require(season > 0, "Initialize first season");
        require(block.timestamp < (seasonCreationTime[season] + signUpPeriod), "Sign up period has expired");
        require(rewardToken.balanceOf(msg.sender) >= buyInAmount, "No enough sUSD for buy in");
        require(rewardToken.allowance(msg.sender, address(this)) >= buyInAmount, "No allowance.");
        require(address(thalesRoyalePassport) != address(0), "ThalesRoyale Passport not set");
        _;
    }

    modifier playerCanSignUpWithPass(uint passId) {
        require(season > 0, "Initialize first season");
        require(block.timestamp < (seasonCreationTime[season] + signUpPeriod), "Sign up period has expired");
        require(royalePass.ownerOf(passId) == msg.sender, "Owner of the token not valid");
        require(rewardToken.balanceOf(address(royalePass)) >= buyInAmount, "No enough sUSD on royale pass contract");
        require(address(thalesRoyalePassport) != address(0), "ThalesRoyale Passport not set");
        _;
    }

    modifier seasonCanStart() {
        require(
            msg.sender == owner || canSeasonBeAutomaticallyStartedAfterSomePeriod(),
            "Only owner can start season before pause between two seasons"
        );
        require(seasonFinished[season] || season == 0, "Previous season must be finished");
        _;
    }

    modifier onlyWinners(uint _season, uint tokenId) {
        require(seasonFinished[_season], "Royale must be finished!");
        require(thalesRoyalePassport.ownerOf(tokenId) == msg.sender, "Not an owner");
        require(isTokenAliveInASpecificSeason(tokenId, _season), "Token is not alive");
        _;
    }

    /* ========== EVENTS ========== */

    event SignedUpPassport(address user, uint tokenId, uint season, uint[] positions);
    event SignedUp(address user, uint season, uint position); //deprecated from passport impl.
    event RoundClosed(
        uint season,
        uint round,
        uint result,
        uint strikePrice,
        uint finalPrice,
        uint numberOfEliminatedPlayers,
        uint numberOfWinningPlayers
    );
    event TookAPosition(address user, uint season, uint round, uint position); //deprecated from passport impl.
    event TookAPositionPassport(address user, uint tokenId, uint season, uint round, uint position);
    event RoyaleStarted(uint season, uint totalTokens, uint totalReward);
    event RoyaleFinished(uint season, uint numberOfWinners, uint rewardPerWinner);
    event RewardClaimedPassport(uint season, address winner, uint tokenId, uint reward);
    event RewardClaimed(uint season, address winner, uint reward); //deprecated from passport impl.
    event NewSeasonStarted(uint season);
    event NewBuyInAmount(uint buyInAmount);
    event NewPriceFeed(IPriceFeed priceFeed);
    event NewThalesRoyalePassport(IThalesRoyalePassport _thalesRoyalePassport);
    event NewRoundLength(uint roundLength);
    event NewRoundChoosingLength(uint roundChoosingLength);
    event NewPauseBetweenSeasonsTime(uint pauseBetweenSeasonsTime);
    event NewSignUpPeriod(uint signUpPeriod);
    event NewNextSeasonStartsAutomatically(bool nextSeasonStartsAutomatically);
    event PutFunds(address from, uint season, uint amount);
    event NewSafeBoxPercentage(uint _safeBoxPercentage);
    event NewSafeBox(address _safeBox);
    event NewThalesRoyalePass(address _royalePass);
    event NewOracleKey(bytes32 _oracleKey);
    event NewRewardToken(address _rewardToken);
    event NewNumberOfRounds(uint _rounds);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IThalesRoyalePass is IERC721Upgradeable {
    
    function burn(uint256 tokenId) external;

    function burnWithTransfer(address player, uint256 tokenId) external;

    function pricePaidForVoucher(uint tokenId) external view returns (uint);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
interface IThalesRoyalePassport {

    function ownerOf(uint256 tokenId) external view returns (address);

    function safeMint(address recipient) external returns (uint tokenId);

    function burn(uint tokenId) external;
    
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function setPause(bool _state) external;

    function setThalesRoyale(address _thalesRoyaleAddress) external;

}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IPassportPosition {
   
    struct Position {
       uint round;
       uint position;
   }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";

contract VestingEscrowProxy is Initializable, ProxyReentrancyGuard, ProxyOwned, ProxyPausable {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public token;
    uint256 public startTime;
    uint256 public endTime;
    mapping(address => uint256) public initialLocked;
    mapping(address => uint256) public totalClaimed;

    uint256 public initialLockedSupply;

    function initialize(
        address _owner,
        address _token,
        uint256 _startTime,
        uint256 _endTime
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        require(_startTime >= block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be greater than start time");
        token = _token;
        startTime = _startTime;
        endTime = _endTime;
    }

    function fund(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner {
        uint256 _totalAmount = 0;
        for (uint256 index = 0; index < _recipients.length; index++) {
            uint256 amount = _amounts[index];
            address recipient = _recipients[index];
            if (recipient == address(0)) {
                break;
            }
            _totalAmount = _totalAmount.add(amount);
            initialLocked[recipient] = initialLocked[recipient].add(amount);
            emit Fund(recipient, amount);
        }

        initialLockedSupply = initialLockedSupply.add(_totalAmount);
    }

    function _totalVestedOf(address _recipient, uint256 _time) internal view returns (uint256) {
        uint256 start = startTime;
        uint256 end = endTime;
        uint256 locked = initialLocked[_recipient];

        if (_time < start) return 0;
        return MathUpgradeable.min(locked.mul(_time.sub(start)).div(end.sub(start)), locked);
    }

    function _totalVested() internal view returns (uint256) {
        uint256 start = startTime;
        uint256 end = endTime;
        uint256 locked = initialLockedSupply;

        if (block.timestamp < start) {
            return 0;
        }

        return MathUpgradeable.min(locked.mul(block.timestamp.sub(start)).div(end.sub(start)), locked);
    }

    function vestedSupply() public view returns (uint256) {
        return _totalVested();
    }

    function vestedOf(address _recipient) public view returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp);
    }

    function lockedSupply() public view returns (uint256) {
        return initialLockedSupply.sub(_totalVested());
    }

    function balanceOf(address _recipient) public view returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp).sub(totalClaimed[_recipient]);
    }

    function lockedOf(address _recipient) public view returns (uint256) {
        return initialLocked[_recipient].sub(_totalVestedOf(_recipient, block.timestamp));
    }

    function claim() external nonReentrant notPaused {
        uint256 claimable = balanceOf(msg.sender);
        require(claimable > 0, "nothing to claim");
        totalClaimed[msg.sender] = totalClaimed[msg.sender].add(claimable);
        IERC20Upgradeable(token).safeTransfer(msg.sender, claimable);
        emit Claim(msg.sender, claimable);
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        startTime = _startTime;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        endTime = _endTime;
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
    }

    event Fund(address indexed _recipient, uint256 _amount);
    event Claim(address indexed _address, uint256 _amount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "../utils/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../utils/libraries/UniswapMath.sol";

contract MockSafeBox is ProxyOwned, Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public sUSD;
    IERC20Upgradeable public thalesToken;
    address public WETH9;

    ISwapRouter public swapRouter;
    IUniswapV3Factory public uniswapFactory;

    uint256 public sUSDperTick;
    uint256 public tickLength;
    uint256 public lastBuyback;

    function initialize(address _owner, IERC20Upgradeable _sUSD) public initializer {
        setOwner(_owner);
        sUSD = _sUSD;
    }

    /// @notice executeBuyback buys THALES tokens for predefined amount of sUSD stored in sUSDperTick value
    /// @dev executeBuyback can be called if at least 1 tickLength has passed since last buyback, 
    /// it then calculates how many ticks passes and executes buyback via Uniswap V3 integrated contract.
    function executeBuyback() external {
        // check zero addresses

        uint ticksFromLastBuyBack = lastBuyback != 0 ? (block.timestamp - lastBuyback) / tickLength : 1;
        require(ticksFromLastBuyBack > 0, "Not enough ticks have passed since last buyback");

        // buy THALES via Uniswap
        uint256 amountThales = _swapExactInput(sUSDperTick * ticksFromLastBuyBack, address(sUSD), address(thalesToken), 3000);

        lastBuyback = block.timestamp;
        emit BuybackExecuted(sUSDperTick, amountThales);
    }

    /// @notice setTickRate sets sUSDperTick amount 
    /// @param _sUSDperTick New sUSDperTick value 
    function setTickRate(uint256 _sUSDperTick) external onlyOwner {
        sUSDperTick = _sUSDperTick;
        emit TickRateChanged(_sUSDperTick);
    }

    /// @notice setTickLength sets tickLength value needed to execute next buyback
    /// @param _tickLength New tickLength value measuered in seconds
    function setTickLength(uint256 _tickLength) external onlyOwner {
        tickLength = _tickLength;
        emit TickLengthChanged(_tickLength);
    }

    /// @notice setThalesToken sets address for THALES token
    /// @param _tokenAddress New address of the token
    function setThalesToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid address");
        thalesToken = IERC20Upgradeable(_tokenAddress);
        emit ThalesTokenAddressChanged(_tokenAddress);
    }

    /// @notice setWETHAddress sets address for WETH token
    /// @param _tokenAddress New address of the token
    function setWETHAddress(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid address");
        WETH9 = _tokenAddress;
        emit WETHTokenAddressChanged(_tokenAddress);
    }

    /// @notice setSwapRouter sets address for Uniswap V3 ISwapRouter
    /// @param _swapRouter New address of the router
    function setSwapRouter(address _swapRouter) external onlyOwner {
        require(_swapRouter != address(0), "Invalid address");
        swapRouter = ISwapRouter(_swapRouter);
        emit SwapRouterAddressChanged(_swapRouter);
    }

    /// @notice setUniswapV3Factory sets address for Uniswap V3 Factory
    /// @param _uniswapFactory New address of the factory
    function setUniswapV3Factory(address _uniswapFactory) external onlyOwner {
        require(_uniswapFactory != address(0), "Invalid address");
        uniswapFactory = IUniswapV3Factory(_uniswapFactory);
        emit UniswapV3FactoryAddressChanged(_uniswapFactory);
    }

    /// @notice swapExactInputSingle swaps a fixed amount of tokenIn for a maximum possible amount of tokenOut
    /// @param amountIn The exact amount of tokenIn that will be swapped for tokenOut.
    /// @param tokenIn Address of first token
    /// @param tokenOut Address of second token
    /// @param poolFee Fee value of tokenIn/tokenOut pool
    /// @return amountOut The amount of tokenOut received.
    function _swapExactInput(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        // Approve the router to spend tokenIn.
        // TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        // uint256 ratio = _getRatio(tokenIn, tokenOut, poolFee);

        // // Multiple pool swaps are encoded through bytes called a `path`. A path is a sequence of token addresses and poolFees that define the pools used in the swaps.
        // // The format for pool encoding is (tokenIn, fee, tokenOut/tokenIn, fee, tokenOut) where tokenIn/tokenOut parameter is the shared token across the pools.
        //  ISwapRouter.ExactInputParams memory params =
        //     ISwapRouter.ExactInputParams({
        //         path: abi.encodePacked(address(tokenIn), poolFee, WETH9, poolFee, address(tokenOut)),
        //         recipient: msg.sender,
        //         deadline: block.timestamp,
        //         amountIn: amountIn,
        //         amountOutMinimum: amountIn * ratio * 99 / 100
        //     });


        // // The call to `exactInput` executes the swap.
        // amountOut = swapRouter.exactInput(params);
    }

    function _getRatio(address tokenA, address tokenB, uint24 poolFee) internal view returns (uint256 ratio) {
        uint256 ratioA = _getWETHPoolRatio(tokenA, poolFee);
        uint256 ratioB = _getWETHPoolRatio(tokenB, poolFee);

        ratio = ratioA / ratioB;
    }

    function _getWETHPoolRatio(address token, uint24 poolFee) internal view returns (uint256 ratio) {
        address pool = IUniswapV3Factory(uniswapFactory).getPool(WETH9, token, poolFee);
        (uint160 sqrtPriceX96token, , , , , , ) = IUniswapV3Pool(pool).slot0();
        if(IUniswapV3Pool(pool).token0() == WETH9) {
            ratio = 1 / _getPriceFromSqrtPrice(sqrtPriceX96token);
        } else {
            ratio = _getPriceFromSqrtPrice(sqrtPriceX96token);
        }
    }
    function _getPriceFromSqrtPrice(uint160 sqrtPriceX96) internal pure returns (uint256 priceX96) {
        uint256 price = UniswapMath.mulDiv(sqrtPriceX96, sqrtPriceX96, UniswapMath.Q96);
        return UniswapMath.mulDiv(price, 10**18, UniswapMath.Q96);
    }

    event TickRateChanged(uint256 _sUSDperTick);
    event TickLengthChanged(uint256 _tickLength);
    event ThalesTokenAddressChanged(address _tokenAddress);
    event WETHTokenAddressChanged(address _tokenAddress);
    event SwapRouterAddressChanged(address _swapRouter);
    event UniswapV3FactoryAddressChanged(address _uniswapFactory);
    event BuybackExecuted(uint256 _amountIn, uint256 _amountOut);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IUniswapV3PoolImmutables.sol';
import './pool/IUniswapV3PoolState.sol';
import './pool/IUniswapV3PoolDerivedState.sol';
import './pool/IUniswapV3PoolActions.sol';
import './pool/IUniswapV3PoolOwnerActions.sol';
import './pool/IUniswapV3PoolEvents.sol';

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolEvents
{

}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The interface for the Uniswap V3 Factory
/// @notice The Uniswap V3 Factory facilitates creation of Uniswap V3 pools and control over the protocol fees
interface IUniswapV3Factory {
    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a pool is created
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param pool The address of the created pool
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );

    /// @notice Emitted when a new fee amount is enabled for pool creation via the factory
    /// @param fee The enabled fee, denominated in hundredths of a bip
    /// @param tickSpacing The minimum number of ticks between initialized ticks for pools created with the given fee
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Returns the tick spacing for a given fee amount, if enabled, or 0 if not enabled
    /// @dev A fee amount can never be removed, so this value should be hard coded or cached in the calling context
    /// @param fee The enabled fee, denominated in hundredths of a bip. Returns 0 in case of unenabled fee
    /// @return The tick spacing
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    /// @notice Returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return pool The pool address
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /// @notice Creates a pool for the given two tokens and fee
    /// @param tokenA One of the two tokens in the desired pool
    /// @param tokenB The other of the two tokens in the desired pool
    /// @param fee The desired fee for the pool
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0. tickSpacing is retrieved
    /// from the fee. The call will revert if the pool already exists, the fee is invalid, or the token arguments
    /// are invalid.
    /// @return pool The address of the newly created pool
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;

    /// @notice Enables a fee amount with the given tickSpacing
    /// @dev Fee amounts may never be removed once enabled
    /// @param fee The fee amount to enable, denominated in hundredths of a bip (i.e. 1e-6)
    /// @param tickSpacing The spacing between ticks to be enforced for all pools created with the given fee amount
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;

/// @title Math library for computing sqrt prices from ticks and vice versa; Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision;
/// Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits

library UniswapMath {
    uint256 internal constant Q192 = 0x1000000000000000000000000000000000000000000000000;
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = denominator & (~denominator + 1);
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(int256(MAX_TICK)), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
    /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
    /// ever return.
    /// @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
    /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        // second inequality must be < because the price can never reach the price at the max tick
        require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, 'R');
        uint256 ratio = uint256(sqrtPriceX96) << 32;

        uint256 r = ratio;
        uint256 msb = 0;

        assembly {
            let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(5, gt(r, 0xFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(4, gt(r, 0xFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(3, gt(r, 0xFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(2, gt(r, 0xF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(1, gt(r, 0x3))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := gt(r, 0x1)
            msb := or(msb, f)
        }

        if (msb >= 128) r = ratio >> (msb - 127);
        else r = ratio << (127 - msb);

        int256 log_2 = (int256(msb) - 128) << 64;

        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(63, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(62, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(61, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(60, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(59, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(58, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(57, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(56, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(55, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(54, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(53, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(52, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(51, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(50, f))
        }

        int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

        int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
        int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

        tick = tickLow == tickHi ? tickLow : getSqrtRatioAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
    /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
    /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
    /// snapshot is taken and the second snapshot is taken.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
    /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
    /// @return secondsInside The snapshot of seconds per liquidity for the range
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// @return amount0 The protocol fee collected in token0
    /// @return amount1 The protocol fee collected in token1
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./interfaces/IUniswapPool.sol";
import "./libraries/Tick.sol";
import "./libraries/Oracle.sol";
import "../utils/libraries/UniswapMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

abstract contract NoDelegateCall {
    /// @dev The original address of this contract
    address private immutable original;

    constructor() {
        // Immutables are computed in the init code of the contract, and then inlined into the deployed bytecode.
        // In other words, this variable won't change when it's checked at runtime.
        original = address(this);
    }

    /// @dev Private method is used instead of inlining into modifier because modifiers are copied into each method,
    ///     and the use of immutable means the address bytes are copied in every place the modifier is used.
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    /// @notice Prevents delegatecall into the modified method
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}

contract MockUniswapV3Pool is IUniswapPool, NoDelegateCall {
    using Tick for mapping(int24 => Tick.Info);
    using Oracle for Oracle.Observation[65535];
    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;
    uint24 public immutable override fee;
    int24 public immutable override tickSpacing;
    uint128 public immutable override maxLiquidityPerTick;
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
        uint8 feeProtocol;
        bool unlocked;
    }
    Slot0 public override slot0;
    uint128 public liquidity;
    Oracle.Observation[65535] public observations;
    modifier lock() {
        require(slot0.unlocked, "LOK");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }
    modifier onlyFactoryOwner() {
        require(msg.sender == IUniswapV3Factory(factory).owner());
        _;
    }

    constructor() {
        int24 _tickSpacing;
        (factory, token0, token1, fee, _tickSpacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
        tickSpacing = _tickSpacing;
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
    }

    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) = token0.staticcall(
            abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this))
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) = token1.staticcall(
            abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this))
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        noDelegateCall
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        return
            observations.observe(
                _blockTimestamp(),
                secondsAgos,
                slot0.tick,
                slot0.observationIndex,
                liquidity,
                slot0.observationCardinality
            );
    }

    function initialize(uint160 sqrtPriceX96) external override {
        require(slot0.sqrtPriceX96 == 0, "AI");
        int24 tick = UniswapMath.getTickAtSqrtRatio(sqrtPriceX96);
        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());
        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 0,
            unlocked: true
        });
        emit Initialize(sqrtPriceX96, tick);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapPool {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);

    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);


    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);



}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/v3-core/contracts/libraries/SafeCast.sol";

import "@uniswap/v3-core/contracts/libraries/LiquidityMath.sol";

/// @title Tick
/// @notice Contains functions for managing tick processes and relevant calculations
library Tick {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    using LowGasSafeMath for int256;
    using SafeCast for int256;

    // info stored for each initialized individual tick
    struct Info {
        // the total position liquidity that references this tick
        uint128 liquidityGross;
        // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left),
        int128 liquidityNet;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        // the cumulative tick value on the other side of the tick
        int56 tickCumulativeOutside;
        // the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint160 secondsPerLiquidityOutsideX128;
        // the seconds spent on the other side of the tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // true iff the tick is initialized, i.e. the value is exactly equivalent to the expression liquidityGross != 0
        // these 8 bits are set to prevent fresh sstores when crossing newly initialized ticks
        bool initialized;
    }

    /// @notice Derives max liquidity per tick from given tick spacing
    /// @dev Executed within the pool constructor
    /// @param tickSpacing The amount of required tick separation, realized in multiples of `tickSpacing`
    ///     e.g., a tickSpacing of 3 requires ticks to be initialized every 3rd tick i.e., ..., -6, -3, 0, 3, 6, ...
    /// @return The max liquidity per tick
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    /// @notice Retrieves fee growth data
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @param tickCurrent The current tick
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1
    /// @return feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    /// @return feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        // calculate fee growth below
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        // calculate fee growth above
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    /// @notice Updates a tick and returns true if the tick was flipped from initialized to uninitialized, or vice versa
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param tick The tick that will be updated
    /// @param tickCurrent The current tick
    /// @param liquidityDelta A new amount of liquidity to be added (subtracted) when tick is crossed from left to right (right to left)
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1
    /// @param secondsPerLiquidityCumulativeX128 The all-time seconds per max(1, liquidity) of the pool
    /// @param time The current block timestamp cast to a uint32
    /// @param upper true for updating a position's upper tick, or false for updating a position's lower tick
    /// @param maxLiquidity The maximum liquidity allocation for a single tick
    /// @return flipped Whether the tick was flipped from initialized to uninitialized, or vice versa
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();
    }

    /// @notice Clears tick data
    /// @param self The mapping containing all initialized tick information for initialized ticks
    /// @param tick The tick that will be cleared
    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    /// @notice Transitions to next tick as needed by price movement
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param tick The destination tick of the transition
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1
    /// @param secondsPerLiquidityCumulativeX128 The current seconds per liquidity
    /// @param time The current block.timestamp
    /// @return liquidityNet The amount of liquidity added (subtracted) when tick is crossed from left to right (right to left)
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside = tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title Oracle
/// @notice Provides price and liquidity data useful for a wide variety of system designs
/// @dev Instances of stored oracle data, "observations", are collected in the oracle array
/// Every pool is initialized with an oracle array length of 1. Anyone can pay the SSTOREs to increase the
/// maximum length of the oracle array. New slots will be added when the array is fully populated.
/// Observations are overwritten when the full length of the oracle array is populated.
/// The most recent observation is available, independent of the length of the oracle array, by passing 0 to observe()
library Oracle {
    struct Observation {
        // the block timestamp of the observation
        uint32 blockTimestamp;
        // the tick accumulator, i.e. tick * time elapsed since the pool was first initialized
        int56 tickCumulative;
        // the seconds per liquidity, i.e. seconds elapsed / max(1, liquidity) since the pool was first initialized
        uint160 secondsPerLiquidityCumulativeX128;
        // whether or not the observation is initialized
        bool initialized;
    }

    /// @notice Transforms a previous observation into a new observation, given the passage of time and the current tick and liquidity values
    /// @dev blockTimestamp _must_ be chronologically equal to or greater than last.blockTimestamp, safe for 0 or 1 overflows
    /// @param last The specified observation to be transformed
    /// @param blockTimestamp The timestamp of the new observation
    /// @param tick The active tick at the time of the new observation
    /// @param liquidity The total in-range liquidity at the time of the new observation
    /// @return Observation The newly populated observation
    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns (Observation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * int56(uint56(delta)),
                secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
                initialized: true
            });
    }

    /// @notice Initialize the oracle array by writing the first slot. Called once for the lifecycle of the observations array
    /// @param self The stored oracle array
    /// @param time The time of the oracle initialization, via block.timestamp truncated to uint32
    /// @return cardinality The number of populated elements in the oracle array
    /// @return cardinalityNext The new length of the oracle array, independent of population
    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({
            blockTimestamp: time,
            tickCumulative: 0,
            secondsPerLiquidityCumulativeX128: 0,
            initialized: true
        });
        return (1, 1);
    }

    /// @notice Writes an oracle observation to the array
    /// @dev Writable at most once per block. Index represents the most recently written element. cardinality and index must be tracked externally.
    /// If the index is at the end of the allowable array length (according to cardinality), and the next cardinality
    /// is greater than the current one, cardinality may be increased. This restriction is created to preserve ordering.
    /// @param self The stored oracle array
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param blockTimestamp The timestamp of the new observation
    /// @param tick The active tick at the time of the new observation
    /// @param liquidity The total in-range liquidity at the time of the new observation
    /// @param cardinality The number of populated elements in the oracle array
    /// @param cardinalityNext The new length of the oracle array, independent of population
    /// @return indexUpdated The new index of the most recently written element in the oracle array
    /// @return cardinalityUpdated The new cardinality of the oracle array
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // early return if we've already written an observation this block
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // if the conditions are right, we can bump the cardinality
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, blockTimestamp, tick, liquidity);
    }

    /// @notice Prepares the oracle array to store up to `next` observations
    /// @param self The stored oracle array
    /// @param current The current next cardinality of the oracle array
    /// @param next The proposed next cardinality which will be populated in the oracle array
    /// @return next The next cardinality which will be populated in the oracle array
    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        require(current > 0, 'I');
        // no-op if the passed next value isn't greater than the current next value
        if (next <= current) return current;
        // store in each slot to prevent fresh SSTOREs in swaps
        // this data will not be used because the initialized boolean is still false
        for (uint16 i = current; i < next; i++) self[i].blockTimestamp = 1;
        return next;
    }

    /// @notice comparator for 32-bit timestamps
    /// @dev safe for 0 or 1 overflows, a and b _must_ be chronologically before or equal to time
    /// @param time A timestamp truncated to 32 bits
    /// @param a A comparison timestamp from which to determine the relative position of `time`
    /// @param b From which to determine the relative position of `time`
    /// @return bool Whether `a` is chronologically <= `b`
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust
        if (a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }

    /// @notice Fetches the observations beforeOrAt and atOrAfter a target, i.e. where [beforeOrAt, atOrAfter] is satisfied.
    /// The result may be the same observation, or adjacent observations.
    /// @dev The answer must be contained in the array, used when the target is located within the stored observation
    /// boundaries: older than the most recent observation and younger, or the same age as, the oldest observation
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param target The timestamp at which the reserved observation should be for
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param cardinality The number of populated elements in the oracle array
    /// @return beforeOrAt The observation recorded before, or at, the target
    /// @return atOrAfter The observation recorded at, or after, the target
    function binarySearch(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // oldest observation
        uint256 r = l + cardinality - 1; // newest observation
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % cardinality];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // check if we've found the answer!
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    /// @notice Fetches the observations beforeOrAt and atOrAfter a given target, i.e. where [beforeOrAt, atOrAfter] is satisfied
    /// @dev Assumes there is at least 1 initialized observation.
    /// Used by observeSingle() to compute the counterfactual accumulator values as of a given block timestamp.
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param target The timestamp at which the reserved observation should be for
    /// @param tick The active tick at the time of the returned or simulated observation
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param liquidity The total pool liquidity at the time of the call
    /// @param cardinality The number of populated elements in the oracle array
    /// @return beforeOrAt The observation which occurred at, or before, the given timestamp
    /// @return atOrAfter The observation which occurred at, or after, the given timestamp
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // optimistically set before to the newest observation
        beforeOrAt = self[index];

        // if the target is chronologically at or after the newest observation, we can early return
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                // if newest observation equals target, we're in the same block, so we can ignore atOrAfter
                return (beforeOrAt, atOrAfter);
            } else {
                // otherwise, we need to transform
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidity));
            }
        }

        // now, set before to the oldest observation
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // ensure that the target is chronologically at or after the oldest observation
        require(lte(time, beforeOrAt.blockTimestamp, target), 'OLD');

        // if we've reached this point, we have to binary search
        return binarySearch(self, time, target, index, cardinality);
    }

    /// @dev Reverts if an observation at or before the desired observation timestamp does not exist.
    /// 0 may be passed as `secondsAgo' to return the current cumulative values.
    /// If called with a timestamp falling between two observations, returns the counterfactual accumulator values
    /// at exactly the timestamp between the two observations.
    /// @param self The stored oracle array
    /// @param time The current block timestamp
    /// @param secondsAgo The amount of time to look back, in seconds, at which point to return an observation
    /// @param tick The current tick
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param liquidity The current in-range pool liquidity
    /// @param cardinality The number of populated elements in the oracle array
    /// @return tickCumulative The tick * time elapsed since the pool was first initialized, as of `secondsAgo`
    /// @return secondsPerLiquidityCumulativeX128 The time elapsed / max(1, liquidity) since the pool was first initialized, as of `secondsAgo`
    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
        if (secondsAgo == 0) {
            Observation memory last = self[index];
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidity);
            return (last.tickCumulative, last.secondsPerLiquidityCumulativeX128);
        }

        uint32 target = time - secondsAgo;

        (Observation memory beforeOrAt, Observation memory atOrAfter) =
            getSurroundingObservations(self, time, target, tick, index, liquidity, cardinality);

        if (target == beforeOrAt.blockTimestamp) {
            // we're at the left boundary
            return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
        } else if (target == atOrAfter.blockTimestamp) {
            // we're at the right boundary
            return (atOrAfter.tickCumulative, atOrAfter.secondsPerLiquidityCumulativeX128);
        } else {
            // we're in the middle
            uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
            uint32 targetDelta = target - beforeOrAt.blockTimestamp;
            return (
                beforeOrAt.tickCumulative +
                    ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / int56(uint56(observationTimeDelta))) *
                    int56(uint56(targetDelta)),
                beforeOrAt.secondsPerLiquidityCumulativeX128 +
                    uint160(
                        (uint256(
                            atOrAfter.secondsPerLiquidityCumulativeX128 - beforeOrAt.secondsPerLiquidityCumulativeX128
                        ) * targetDelta) / observationTimeDelta
                    )
            );
        }
    }

    /// @notice Returns the accumulator values as of each time seconds ago from the given time in the array of `secondsAgos`
    /// @dev Reverts if `secondsAgos` > oldest observation
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param secondsAgos Each amount of time to look back, in seconds, at which point to return an observation
    /// @param tick The current tick
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param liquidity The current in-range pool liquidity
    /// @param cardinality The number of populated elements in the oracle array
    /// @return tickCumulatives The tick * time elapsed since the pool was first initialized, as of each `secondsAgo`
    /// @return secondsPerLiquidityCumulativeX128s The cumulative seconds / max(1, liquidity) since the pool was first initialized, as of each `secondsAgo`
    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        require(cardinality > 0, 'I');

        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            (tickCumulatives[i], secondsPerLiquidityCumulativeX128s[i]) = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                liquidity,
                cardinality
            );
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title An interface for a contract that is capable of deploying Uniswap V3 Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface IUniswapV3PoolDeployer {
    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool
    /// Returns factory The factory address
    /// Returns token0 The first token of the pool by address sort order
    /// Returns token1 The second token of the pool by address sort order
    /// Returns fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// Returns tickSpacing The minimum number of ticks between initialized ticks
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        );
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Minimal ERC20 interface for Uniswap
/// @notice Contains a subset of the full ERC20 interface that is used in Uniswap V3
interface IERC20Minimal {
    /// @notice Returns the balance of a token
    /// @param account The account for which to look up the number of tokens it has, i.e. its balance
    /// @return The number of tokens held by the account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers the amount of token from the `msg.sender` to the recipient
    /// @param recipient The account that will receive the amount transferred
    /// @param amount The number of tokens to send from the sender to the recipient
    /// @return Returns true for a successful transfer, false for an unsuccessful transfer
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Returns the current allowance given to a spender by an owner
    /// @param owner The account of the token owner
    /// @param spender The account of the token spender
    /// @return The current allowance granted by `owner` to `spender`
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets the allowance of a spender from the `msg.sender` to the value `amount`
    /// @param spender The account which will be allowed to spend a given amount of the owners tokens
    /// @param amount The amount of tokens allowed to be used by `spender`
    /// @return Returns true for a successful approval, false for unsuccessful
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers `amount` tokens from `sender` to `recipient` up to the allowance given to the `msg.sender`
    /// @param sender The account from which the transfer will be initiated
    /// @param recipient The recipient of the transfer
    /// @param amount The amount of the transfer
    /// @return Returns true for a successful transfer, false for unsuccessful
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @notice Event emitted when tokens are transferred from one address to another, either via `#transfer` or `#transferFrom`.
    /// @param from The account from which the tokens were sent, i.e. the balance decreased
    /// @param to The account to which the tokens were sent, i.e. the balance increased
    /// @param value The amount of tokens that were transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Event emitted when the approval amount for the spender of a given owner's tokens changes.
    /// @param owner The account that approved spending of its tokens
    /// @param spender The account for which the spending allowance was modified
    /// @param value The new allowance from the owner to the spender
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#mint
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IUniswapV3MintCallback {
    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#flash
/// @notice Any contract that calls IUniswapV3PoolActions#flash must implement this interface
interface IUniswapV3FlashCallback {
    /// @notice Called to `msg.sender` after transferring to the recipient from IUniswapV3Pool#flash.
    /// @dev In the implementation you must repay the pool the tokens sent by flash plus the computed fee amounts.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param fee0 The fee amount in token0 due to the pool by the end of the flash
    /// @param fee1 The fee amount in token1 due to the pool by the end of the flash
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#flash call
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0;

/// @title Optimized overflow and underflow safe math operations
/// @notice Contains methods for doing math operations that revert on overflow or underflow for minimal gas cost
library LowGasSafeMath {
    /// @notice Returns x + y, reverts if sum overflows uint256
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /// @notice Returns x - y, reverts if underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /// @notice Returns x * y, reverts if overflows
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @return z The product of x and y
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /// @notice Returns x + y, reverts if overflows or underflows
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /// @notice Returns x - y, reverts if overflows or underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint160
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param y The int256 to be downcasted
    /// @return z The downcasted integer, now type int128
    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y);
    }

    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param y The uint256 to be casted
    /// @return z The casted integer, now type int256
    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255);
        z = int256(y);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Math library for liquidity
library LiquidityMath {
    /// @notice Add a signed liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Interface for permit
/// @notice Interface used by DAI/CHAI for permit
interface IERC20PermitAllowed {
    /// @notice Approve the spender to spend some tokens via the holder signature
    /// @dev This is the permit interface used by DAI and CHAI
    /// @param holder The address of the token holder, the token owner
    /// @param spender The address of the token spender
    /// @param nonce The holder's nonce, increases at each call to permit
    /// @param expiry The timestamp at which the permit is no longer valid
    /// @param allowed Boolean that sets approval amount, true for type(uint256).max and false for 0
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// @title Self Permit
/// @notice Functionality to call permit on any EIP-2612-compliant token for use in the route
interface ISelfPermit {
    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this).
    /// @param token The address of the token spent
    /// @param value The amount that can be spent of token
    /// @param deadline A timestamp, the current blocktime must be less than or equal to this timestamp
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this).
    /// Can be used instead of #selfPermit to prevent calls from failing due to a frontrun of a call to #selfPermit
    /// @param token The address of the token spent
    /// @param value The amount that can be spent of token
    /// @param deadline A timestamp, the current blocktime must be less than or equal to this timestamp
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Permits this contract to spend the sender's tokens for permit signatures that have the `allowed` parameter
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this)
    /// @param token The address of the token spent
    /// @param nonce The current nonce of the owner
    /// @param expiry The timestamp at which the permit is no longer valid
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Permits this contract to spend the sender's tokens for permit signatures that have the `allowed` parameter
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this)
    /// Can be used instead of #selfPermitAllowed to prevent calls from failing due to a frontrun of a call to #selfPermitAllowed.
    /// @param token The address of the token spent
    /// @param nonce The current nonce of the owner
    /// @param expiry The timestamp at which the permit is no longer valid
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Immutable state
/// @notice Functions that return immutable state of the router
interface IPeripheryImmutableState {
    /// @return Returns the address of the Uniswap V3 factory
    function factory() external view returns (address);

    /// @return Returns the address of WETH9
    function WETH9() external view returns (address);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// @title Periphery Payments
/// @notice Functions to ease deposits and withdrawals of ETH
interface IPeripheryPayments {
    /// @notice Unwraps the contract's WETH9 balance and sends it to recipient as ETH.
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing WETH9 from users.
    /// @param amountMinimum The minimum amount of WETH9 to unwrap
    /// @param recipient The address receiving ETH
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

    /// @notice Refunds any ETH balance held by this contract to the `msg.sender`
    /// @dev Useful for bundling with mint or increase liquidity that uses ether, or exact output swaps
    /// that use ether for the input amount
    function refundETH() external payable;

    /// @notice Transfers the full amount of a token held by this contract to recipient
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing the token from users
    /// @param token The contract address of the token which will be transferred to `recipient`
    /// @param amountMinimum The minimum amount of token required for a transfer
    /// @param recipient The destination address of the token
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import './IPeripheryPayments.sol';

/// @title Periphery Payments
/// @notice Functions to ease deposits and withdrawals of ETH
interface IPeripheryPaymentsWithFee is IPeripheryPayments {
    /// @notice Unwraps the contract's WETH9 balance and sends it to recipient as ETH, with a percentage between
    /// 0 (exclusive), and 1 (inclusive) going to feeRecipient
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing WETH9 from users.
    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    /// @notice Transfers the full amount of a token held by this contract to recipient, with a percentage between
    /// 0 (exclusive) and 1 (inclusive) going to feeRecipient
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing the token from users
    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0;
library PoolAddress {
     bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            keccak256(abi.encode(key.token0, key.token1, key.fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./PoolAddress.sol";

/// @notice Provides validation for callbacks from Uniswap V3 Pools
library CallbackValidation {
    /// @notice Returns the address of a valid Uniswap V3 Pool
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return pool The V3 pool contract address
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    /// @notice Returns the address of a valid Uniswap V3 Pool
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param poolKey The identifying key of the V3 pool
    /// @return pool The V3 pool contract address
    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (IUniswapV3Pool pool)
    {
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        require(msg.sender == address(pool));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "../utils/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../utils/libraries/UniswapMath.sol";

contract MockCurveSUSD {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public sUSD;
    IERC20Upgradeable public USDC;
    IERC20Upgradeable public USDT;
    IERC20Upgradeable public DAI;

    uint private constant ONE = 1e18;
    uint private constant ONE_PERCENT = 1e16;

    constructor(
        address _sUSD,
        address _USDC,
        address _USDT,
        address _DAI
    ) {
        sUSD = IERC20Upgradeable(_sUSD);
        USDC = IERC20Upgradeable(_USDC);
        USDT = IERC20Upgradeable(_USDT);
        DAI = IERC20Upgradeable(_DAI);
    }

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) external returns (uint256) {
        if (j == 1) {
            DAI.transfer(msg.sender, (_dx * (ONE + ONE_PERCENT)) / ONE);
            sUSD.transferFrom(msg.sender, address(this), _dx);
            return (_dx * (ONE + ONE_PERCENT)) / ONE;
        }
        if (j == 2) {
            USDC.transfer(msg.sender, ((_dx / 1e12) * (ONE + ONE_PERCENT)) / ONE);
            sUSD.transferFrom(msg.sender, address(this), _dx);
            return ((_dx / 1e12) * (ONE + ONE_PERCENT)) / ONE;
        }
        if (j == 3) {
            USDT.transfer(msg.sender, ((_dx / 1e12) * (ONE + ONE_PERCENT)) / ONE);
            sUSD.transferFrom(msg.sender, address(this), _dx);
            return ((_dx / 1e12) * (ONE + ONE_PERCENT)) / ONE;
        } else return 0;
    }

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 _dx
    ) external view returns (uint256) {
        if (j == 1) {
            return (_dx * (ONE + ONE_PERCENT)) / ONE;
        } else return ((_dx / 1e12) * (ONE + ONE_PERCENT)) / ONE;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "./MockUniswapV3PoolDeployer.sol";

import "./MockUniswapV3Pool.sol";


/// @title Canonical Uniswap V3 factory
/// @notice Deploys Uniswap V3 pools and manages ownership and control over pool protocol fees
contract MockUniswapV3Factory is IUniswapV3Factory, MockUniswapV3PoolDeployer, NoDelegateCall {
    /// @inheritdoc IUniswapV3Factory
    address public override owner;

    /// @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        feeAmountTickSpacing[500] = 10;
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }

    /// @inheritdoc IUniswapV3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0);
        require(getPool[token0][token1][fee] == address(0));
        pool = deploy(address(this), token0, token1, fee, tickSpacing);
        getPool[token0][token1][fee] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /// @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IUniswapV3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        require(msg.sender == owner);
        require(fee < 1000000);
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(feeAmountTickSpacing[fee] == 0);

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MockUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol";

contract MockUniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new MockUniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../utils/libraries/UniswapMath.sol";

contract SafeBoxBuyback is ProxyOwned, Initializable, ProxyReentrancyGuard {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public sUSD;
    IERC20Upgradeable public thalesToken;
    address public WETH9;

    ISwapRouter public swapRouter;
    IUniswapV3Factory public uniswapFactory;

    uint256 public sUSDperTick;
    uint256 public tickLength;
    uint256 public lastBuyback;

    bool public buybacksEnabled;

    uint256 public minAccepted;

    function initialize(address _owner, IERC20Upgradeable _sUSD) public initializer {
        setOwner(_owner);
        initNonReentrant();
        sUSD = _sUSD;
    }

    /// @notice executeBuyback buys THALES tokens for predefined amount of sUSD stored in sUSDperTick value
    /// @dev executeBuyback can be called if at least 1 tickLength has passed since last buyback,
    /// it then calculates how many ticks passes and executes buyback via Uniswap V3 integrated contract.
    function executeBuyback() external nonReentrant {
        require(buybacksEnabled, "Buybacks are not enabled");
        uint ticksFromLastBuyBack = lastBuyback != 0 ? (block.timestamp - lastBuyback) / tickLength : 1;
        require(ticksFromLastBuyBack > 0, "Not enough ticks have passed since last buyback");
        require(sUSD.balanceOf(address(this)) >= sUSDperTick * ticksFromLastBuyBack, "Not enough sUSD in contract.");

        // buy THALES via Uniswap
        uint256 amountThales =
            _swapExactInput(sUSDperTick * ticksFromLastBuyBack, address(sUSD), address(thalesToken), 3000);

        lastBuyback = block.timestamp;
        emit BuybackExecuted(sUSDperTick * ticksFromLastBuyBack, amountThales);
    }

    /// @notice _swapExactInput swaps a fixed amount of tokenIn for a maximum possible amount of tokenOut
    /// @param amountIn The exact amount of tokenIn that will be swapped for tokenOut.
    /// @param tokenIn Address of first token
    /// @param tokenOut Address of second token
    /// @param poolFee Fee value of tokenIn/tokenOut pool
    /// @return amountOut The amount of tokenOut received.
    function _swapExactInput(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        // Approve the router to spend tokenIn.
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        uint256 _minAccepted = minAccepted == 0 ? 95 : minAccepted;

        uint256 ratio = _getRatio(tokenIn, tokenOut, poolFee);

        // Multiple pool swaps are encoded through bytes called a `path`. A path is a sequence of token addresses and poolFees that define the pools used in the swaps.
        // The format for pool encoding is (tokenIn, fee, tokenOut/tokenIn, fee, tokenOut) where tokenIn/tokenOut parameter is the shared token across the pools.
        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(address(tokenIn), poolFee, WETH9, poolFee, address(tokenOut)),
                recipient: address(this),
                deadline: block.timestamp + 15,
                amountIn: amountIn,
                amountOutMinimum: (amountIn * ratio * _minAccepted) / (100 * 10**18)
            });

        // The call to `exactInput` executes the swap.
        amountOut = swapRouter.exactInput(params);
    }

    /// @notice _getRatio returns ratio between tokenA and tokenB based on prices fetched from
    /// UniswapV3Pool
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @param poolFee Fee value of tokenA/tokenB pool
    /// @return ratio tokenA/tokenB ratio
    function _getRatio(
        address tokenA,
        address tokenB,
        uint24 poolFee
    ) internal view returns (uint256 ratio) {
        uint256 ratioA = _getWETHPoolRatio(tokenA, poolFee);
        uint256 ratioB = _getWETHPoolRatio(tokenB, poolFee);

        ratio = (ratioA * 10**18) / ratioB;
    }

    /// @notice _getWETHPoolRatio returns ratio between tokenA and WETH based on prices fetched from
    /// UniswapV3Pool
    /// @dev Ratio is calculated differently if token0 in pool is WETH
    /// @param token Token address
    /// @param poolFee Fee value of token/WETH pool
    /// @return ratio token/WETH ratio
    function _getWETHPoolRatio(address token, uint24 poolFee) internal view returns (uint256 ratio) {
        address pool = IUniswapV3Factory(uniswapFactory).getPool(WETH9, token, poolFee);
        (uint160 sqrtPriceX96token, , , , , , ) = IUniswapV3Pool(pool).slot0();
        if (IUniswapV3Pool(pool).token0() == WETH9) {
            // ratio is 10^18/sqrtPrice - multiply again with 10^18 to convert to decimal
            ratio = UniswapMath.mulDiv(10**18, 10**18, _getPriceFromSqrtPrice(sqrtPriceX96token));
        } else {
            ratio = _getPriceFromSqrtPrice(sqrtPriceX96token);
        }
    }

    /// @notice _getPriceFromSqrtPrice calculate price from UniswapV3Pool via formula
    /// @param sqrtPriceX96 Price fetched from UniswapV3Pool
    /// @return Calculated price
    function _getPriceFromSqrtPrice(uint160 sqrtPriceX96) internal pure returns (uint256) {
        uint256 price = UniswapMath.mulDiv(sqrtPriceX96, sqrtPriceX96, UniswapMath.Q96);
        return UniswapMath.mulDiv(price, 10**18, UniswapMath.Q96);
    }

    function getTicksFromLastBuys() external view returns (uint) {
        uint ticksFromLastBuyBack = lastBuyback != 0 ? (block.timestamp - lastBuyback) / tickLength : 1;
        return ticksFromLastBuyBack;
    }

    /// @notice setTickRate sets sUSDperTick amount
    /// @param _sUSDperTick New sUSDperTick value
    function setTickRate(uint256 _sUSDperTick) external onlyOwner {
        sUSDperTick = _sUSDperTick;
        emit TickRateChanged(_sUSDperTick);
    }

    /// @notice setTickLength sets tickLength value needed to execute next buyback
    /// @param _tickLength New tickLength value measuered in seconds
    function setTickLength(uint256 _tickLength) external onlyOwner {
        tickLength = _tickLength;
        emit TickLengthChanged(_tickLength);
    }

    /// @notice setThalesToken sets address for THALES token
    /// @param _tokenAddress New address of the token
    function setThalesToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid address");
        thalesToken = IERC20Upgradeable(_tokenAddress);
        emit ThalesTokenAddressChanged(_tokenAddress);
    }

    /// @notice setWETHAddress sets address for WETH token
    /// @param _tokenAddress New address of the token
    function setWETHAddress(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid address");
        WETH9 = _tokenAddress;
        emit WETHTokenAddressChanged(_tokenAddress);
    }

    /// @notice setSwapRouter sets address for Uniswap V3 ISwapRouter
    /// @param _swapRouter New address of the router
    function setSwapRouter(address _swapRouter) external onlyOwner {
        require(_swapRouter != address(0), "Invalid address");
        swapRouter = ISwapRouter(_swapRouter);
        emit SwapRouterAddressChanged(_swapRouter);
    }

    /// @notice setUniswapV3Factory sets address for Uniswap V3 Factory
    /// @param _uniswapFactory New address of the factory
    function setUniswapV3Factory(address _uniswapFactory) external onlyOwner {
        require(_uniswapFactory != address(0), "Invalid address");
        uniswapFactory = IUniswapV3Factory(_uniswapFactory);
        emit UniswapV3FactoryAddressChanged(_uniswapFactory);
    }

    /// @notice setMinAccepted sets _minAccepted amount
    /// @param _minAccepted for buyback
    function setMinAccepted(uint256 _minAccepted) external onlyOwner {
        minAccepted = _minAccepted;
        emit MinAcceptedChanged(_minAccepted);
    }

    /// @notice setBuybacksEnabled enables/disables buybacks
    /// @param _buybacksEnabled enabled/disabled
    function setBuybacksEnabled(bool _buybacksEnabled) external onlyOwner {
        require(buybacksEnabled != _buybacksEnabled, "Already enabled/disabled");
        buybacksEnabled = _buybacksEnabled;
        emit SetBuybacksEnabled(_buybacksEnabled);
    }

    /// @notice retrieveSUSDAmount retrieves sUSD from this contract
    /// @param account where to send the tokens
    /// @param amount how much to retrieve
    function retrieveSUSDAmount(address payable account, uint amount) external onlyOwner {
        sUSD.transfer(account, amount);
    }

    /// @notice retrieveThalesAmount retrieves THALES from this contract
    /// @param account where to send the tokens
    /// @param amount how much to retrieve
    function retrieveThalesAmount(address payable account, uint amount) external onlyOwner {
        thalesToken.transfer(account, amount);
    }

    event TickRateChanged(uint256 _sUSDperTick);
    event MinAcceptedChanged(uint256 _minAccepted);
    event TickLengthChanged(uint256 _tickLength);
    event ThalesTokenAddressChanged(address _tokenAddress);
    event WETHTokenAddressChanged(address _tokenAddress);
    event SwapRouterAddressChanged(address _swapRouter);
    event UniswapV3FactoryAddressChanged(address _uniswapFactory);
    event SetBuybacksEnabled(bool _buybacksEnabled);
    event BuybackExecuted(uint256 _amountIn, uint256 _amountOut);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-4.4.1/utils/Counters.sol";
import "@openzeppelin/contracts-4.4.1/access/Ownable.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IThalesRoyale.sol";

contract ThalesRoyalePass is ERC721URIStorage, Ownable {
    /* ========== LIBRARIES ========== */

    using Counters for Counters.Counter;
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    Counters.Counter private _tokenIds;

    string public _name = "Thales Royale Pass";
    string public _symbol = "TRP";
    bool public paused = false;
    string public tokenURI;

    IThalesRoyale public thalesRoyale;

    IERC20 public sUSD;
    mapping(uint => uint) public pricePerPass;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _sUSD,
        string memory _initURI,
        address _thalesRoyaleAddress
    ) ERC721(_name, _symbol) {
        sUSD = IERC20(_sUSD);
        tokenURI = _initURI;
        thalesRoyale = IThalesRoyale(_thalesRoyaleAddress);
    }

    /* ========== TRV ========== */

    function mint(address recipient) external returns (uint) {
        require(!paused);
        // check sUSD
        require(sUSD.balanceOf(msg.sender) >= thalesRoyale.getBuyInAmount(), "No enough sUSD");
        require(sUSD.allowance(msg.sender, address(this)) >= thalesRoyale.getBuyInAmount(), "No allowance");

        _tokenIds.increment();

        uint newItemId = _tokenIds.current();
        pricePerPass[newItemId] = thalesRoyale.getBuyInAmount();

        // pay for pass
        _payForPass(msg.sender, thalesRoyale.getBuyInAmount());

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function burnWithTransfer(address player, uint tokenId) external {
        require(sUSD.balanceOf(address(this)) >= thalesRoyale.getBuyInAmount(), "Not enough sUSD");
        require(msg.sender == address(thalesRoyale), "Sender must be thales royale contract");
        require(thalesRoyale.getBuyInAmount() <= pricePerPass[tokenId], "Not enough sUSD allocated in the pass");

        if (thalesRoyale.getBuyInAmount() < pricePerPass[tokenId]) {

            uint diferenceInPrice = pricePerPass[tokenId].sub(thalesRoyale.getBuyInAmount());

            // send diference to player
            sUSD.safeTransfer(player, diferenceInPrice);

            // set new price per pass
            pricePerPass[tokenId] = thalesRoyale.getBuyInAmount();
        }

        // burn at the end and transfer to royale
        sUSD.safeTransfer(address(thalesRoyale), thalesRoyale.getBuyInAmount());
        super._burn(tokenId);
    }

    function topUp(uint tokenId, uint amount) external {
        require(sUSD.balanceOf(msg.sender) >= amount, "No enough sUSD");
        require(sUSD.allowance(msg.sender, address(this)) >= amount, "No allowance.");
        require(_exists(tokenId), "Not existing pass");
        sUSD.safeTransferFrom(msg.sender, address(this), amount);
        pricePerPass[tokenId] = pricePerPass[tokenId] + amount;
    }

    /* ========== VIEW ========== */

    function pricePaidForPass(uint tokenId) public view returns (uint) {
        return pricePerPass[tokenId];
    }

    /* ========== INTERNALS ========== */

    function _payForPass(address _sender, uint _amount) internal {
        sUSD.safeTransferFrom(_sender, address(this), _amount);
    }

    /* ========== CONTRACT MANAGEMENT ========== */

    function setTokenUri(string memory _tokenURI) public onlyOwner {
        tokenURI = _tokenURI;
        emit NewTokenUri(_tokenURI);
    }

    function setPause(bool _state) public onlyOwner {
        paused = _state;
        emit ThalesRoyalePassPaused(_state);
    }

    function setThalesRoyaleAddress(address _thalesRoyaleAddress) public onlyOwner {
        thalesRoyale = IThalesRoyale(_thalesRoyaleAddress);
        emit NewThalesRoyaleAddress(_thalesRoyaleAddress);
    }

    /* ========== EVENTS ========== */

    event NewTokenUri(string _tokenURI);
    event NewThalesRoyaleAddress(address _thalesRoyaleAddress);
    event ThalesRoyalePassPaused(bool _state);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStorage is ERC721 {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;
pragma experimental ABIEncoderV2;
import "../interfaces/IPassportPosition.sol";

interface IThalesRoyale {

    
    /* ========== VIEWS / VARIABLES ========== */
    function getBuyInAmount() external view returns (uint);
    function season() external view returns (uint);
    function tokenSeason(uint tokenId) external view returns (uint);
    function seasonFinished(uint _season) external view returns (bool);
    function roundInASeason(uint _round) external view returns (uint);
    function roundResultPerSeason(uint _season, uint round) external view returns (uint);
    function isTokenAliveInASpecificSeason(uint tokenId, uint _season) external view returns (bool);
    function hasParticipatedInCurrentOrLastRoyale(address _player) external view returns (bool);

    function getTokenPositions(uint tokenId) external view returns (IPassportPosition.Position[] memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../interfaces/IThalesRoyale.sol";
import "../interfaces/IPassportPosition.sol";
import "../utils/libraries/NFTSVG.sol";
import "../utils/libraries/NFTDescriptor.sol";

contract ThalesRoyalePassport is
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable
{
    /* ========== LIBRARIES ========== */

    using CountersUpgradeable for CountersUpgradeable.Counter;

    /* ========== STATE VARIABLES ========== */

    CountersUpgradeable.Counter private _tokenIdCounter;

    IThalesRoyale public thalesRoyale;
    mapping(uint => uint) public tokenTimestamps;
    string public baseUri;

    /* ========== CONSTRUCTOR ========== */

    function initialize(address _thalesRoyaleAddress, string memory _baseUri) public initializer {
        __Ownable_init();
        __ERC721_init("Thales Royale Passport", "TRS");
        thalesRoyale = IThalesRoyale(_thalesRoyaleAddress);
        baseUri = _baseUri;
    }

    function safeMint(address recipient) external whenNotPaused onlyRoyale returns (uint tokenId) {
        _tokenIdCounter.increment();

        tokenId = _tokenIdCounter.current();
        _safeMint(recipient, tokenId);

        tokenTimestamps[tokenId] = block.timestamp;

        emit ThalesRoyalePassportMinted(recipient, tokenId);
    }

    function burn(uint tokenId) public override canBeBurned(tokenId) {
        _burn(tokenId);

        emit ThalesRoyalePassportBurned(tokenId);
    }

    /* ========== VIEW ========== */
    function tokenURI(uint tokenId) public view override returns (string memory imageURI) {
        require(_exists(tokenId), "Passport doesn't exist");

        address player = ownerOf(tokenId);
        uint timestamp = tokenTimestamps[tokenId];

        uint season = thalesRoyale.tokenSeason(tokenId);
        uint currentRound = thalesRoyale.roundInASeason(season);
        bool alive = thalesRoyale.isTokenAliveInASpecificSeason(tokenId, season);
        IPassportPosition.Position[] memory positions = thalesRoyale.getTokenPositions(tokenId);
        bool seasonFinished = thalesRoyale.seasonFinished(season);

        imageURI = NFTDescriptor.constructTokenURI(
            NFTSVG.SVGParams(player, timestamp, tokenId, season, currentRound, positions, alive, seasonFinished)
        );
    }

    /* ========== CONTRACT MANAGEMENT ========== */

    function pause() external onlyOwner {
        _pause();
        emit ThalesRoyalePassportPaused(true);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ThalesRoyalePassportPaused(false);
    }

    function setThalesRoyale(address _thalesRoyaleAddress) external onlyOwner {
        require(_thalesRoyaleAddress != address(0), "Invalid address");
        thalesRoyale = IThalesRoyale(_thalesRoyaleAddress);
        emit ThalesRoyaleAddressChanged(_thalesRoyaleAddress);
    }

    function setBaseURI(string memory _baseUri) external onlyOwner {
        baseUri = _baseUri;

        emit BaseUriChanged(_baseUri);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721EnumerableUpgradeable, ERC721Upgradeable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721EnumerableUpgradeable, ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /* ========== MODIFIERS ========== */

    modifier canBeBurned(uint tokenId) {
        require(_exists(tokenId), "Passport doesn't exist");
        require(_isApprovedOrOwner(msg.sender, tokenId), "Must be owner or approver");
        _;
    }

    modifier onlyRoyale() {
        require(msg.sender == address(thalesRoyale), "Invalid address");
        _;
    }

    /* ========== EVENTS ========== */

    event ThalesRoyalePassportMinted(address _recipient, uint _tokenId);
    event ThalesRoyalePassportBurned(uint _tokenId);
    event ThalesRoyaleAddressChanged(address _thalesRoyaleAddress);
    event ThalesRoyalePassportPaused(bool _state);
    event BaseUriChanged(string _baseURI);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721Upgradeable.sol";
import "./IERC721EnumerableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721EnumerableUpgradeable is Initializable, ERC721Upgradeable, IERC721EnumerableUpgradeable {
    function __ERC721Enumerable_init() internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721Enumerable_init_unchained();
    }

    function __ERC721Enumerable_init_unchained() internal onlyInitializing {
    }
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165Upgradeable, ERC721Upgradeable) returns (bool) {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Upgradeable.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721EnumerableUpgradeable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721Upgradeable.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721Upgradeable.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
    uint256[46] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC721Upgradeable.sol";
import "../../../utils/ContextUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be irreversibly burned (destroyed).
 */
abstract contract ERC721BurnableUpgradeable is Initializable, ContextUpgradeable, ERC721Upgradeable {
    function __ERC721Burnable_init() internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721Burnable_init_unchained();
    }

    function __ERC721Burnable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library CountersUpgradeable {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/utils/Strings.sol";
import "base64-sol/base64.sol";
import "../../interfaces/IPassportPosition.sol";

/// @title NFTSVG
/// @notice Provides a function for generating an SVG associated with a ThalesRoyalePassport NFT
library NFTSVG {
    using Strings for uint;

    struct SVGParams {
        address player;
        uint timestamp;
        uint tokenId;
        uint season;
        uint round;
        IPassportPosition.Position[] positions;
        bool alive;
        bool seasonFinished;
    }

    function generateSVG(SVGParams memory params) internal pure returns (string memory svg) {
        if (!params.alive) {
            svg = string(abi.encodePacked(generateSVGEliminated(params.season, params.tokenId)));
        } else {
            svg = string(
                abi.encodePacked(
                    generateSVGBase(),
                    generateSVGData(params.player, params.tokenId, params.timestamp, params.season, params.seasonFinished),
                    generateSVGStamps(params.positions, params.round, params.seasonFinished),
                    generateSVGBackground()
                )
            );
        }
    }

    function generateSVGBase() private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<svg viewBox="0 0 350 550" fill="none" xmlns="http://www.w3.org/2000/svg">',
                '<g class="background">',
                '<path id="gornji" d="M350 0H0V275H350V0Z" fill="url(#paint0_linear_44_340)"/>',
                '<path id="donji" d="M350 275H0V550H350V275Z" fill="url(#paint1_linear_44_340)"/>',
                "</g>",
                '<g class="logoRoyale">',
                '<rect id="rectangle" x="123.113" y="33.2568" width="27" height="27" stroke="#7F6F6F" stroke-width="3.35159"/>',
                '<circle id="krug" cx="224.402" cy="47.0822" r="13.4064" stroke="#7F6F6F" stroke-width="3.35159"/>',
                '<path id="triangle" d="M168.589 59.5459L182.557 35.3516L196.526 59.5459H168.589Z" stroke="#7F6F6F" stroke-width="3.35159"/></g>',
                '<text x="36" y="85" font-family="Courier New" font-size="21" fill="#7F6F6F">Thales Royale Passport</text>'
            )
        );
    }

    function generateSVGEliminated(uint season, uint tokenId) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                generateSVGBase(),
                '<text x="120" y="115" font-family="Helvetica" font-size="24" fill="#7F6F6F">SEASON ',
                Strings.toString(season),
                '</text>',
                '<text x="60" y="240" font-family="Courier New" font-size="38" fill="#D10019" text-decoration="line-through">ELIMINATED</text>',
                '<text x="50" y="520" font-family="Courier New" font-size="20" fill="#7F6F6F">Passport No: #',
                Strings.toString(tokenId),
                '</text>',
                generateSVGBackground()
            )
        );
    }

    function generateSVGData(
        address player,
        uint tokenId,
        uint timestamp,
        uint season,
        bool seasonFinished
    ) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<text x="',
                seasonFinished ? '63' : '120',
                '" y="115" font-family="Helvetica" font-size="24" fill="#7F6F6F">',
                seasonFinished ? 'WINNER SEASON ' : 'SEASON ',
                Strings.toString(season),
                '</text>',
                '<text x="10" y="460" font-family="Courier New" font-size="13" fill="#7F6F6F">',
                addressToString(player), 
                '</text>',
                '<text x="30" y="490" font-family="Courier New" font-size="20" fill="#7F6F6F">Issued On: ',
                Strings.toString(timestamp),
                '</text>',
                '<text x="50" y="520" font-family="Courier New" font-size="20" fill="#7F6F6F">Passport No: #',
                Strings.toString(tokenId),
                '</text>'
            )
        );
    }

    function generateSVGStamps(IPassportPosition.Position[] memory positions, uint currentRound, bool seasonFinished)
        private
        pure
        returns (string memory stamps)
    {
        stamps = string(abi.encodePacked(""));
        uint rounds = seasonFinished ? currentRound - 1 : currentRound;
        for (uint i = 0; i < positions.length; i++) {
            uint position = positions[i].position;
            uint round = positions[i].round;
            if (rounds >= round) {
                string memory stamp = generateSVGStamp(round, position);
                stamps = string(abi.encodePacked(stamps, stamp));
            }
        }
    }

    function generateSVGStamp(
        uint round,
        uint position
    ) private pure returns (string memory stamp) {
        string memory item = "";
        if (round == 1) {
            item = position == 1
                ? '<circle cx="72.5005" cy="200.5" r="28" transform="rotate(-9.01508 72.5005 200.5)" stroke="#D10019"/><text x="63" y="215" font-family="Courier New" font-size="40" rotate="-9" fill="#D10019">1</text>'
                : '<path d="M41.7387 226.599L69.954 167.136L107.343 221.302L41.7387 226.599Z" stroke="#00957E"/><text x="63" y="215" font-family="Courier New" font-size="40" rotate="-9" fill="#00957E">1</text>';
        } else if (round == 2) {
            item = position == 1
                ? '<circle cx="72.9395" cy="288.94" r="28" transform="rotate(12.3593 72.9395 288.94)" stroke="#D10019"/><text x="59" y="299" font-family="Courier New" font-size="40" rotate="13" fill="#D10019">2</text>'
                : '<path d="M35.7644 295.445L80.2057 246.896L100.029 309.658L35.7644 295.445Z" stroke="#00957E"/><text x="59" y="293" font-family="Courier New" font-size="40" rotate="15" fill="#00957E">2</text>';
        } else if (round == 3) {
            item = position == 1
                ? '<circle cx="145.903" cy="304.902" r="28" transform="rotate(-14.9925 145.903 304.902)" stroke="#D10019"/><text x="139" y="322" font-family="Courier New" font-size="40" rotate="-18" fill="#D10019">3</text>'
                : '<path d="M128.895 330.635L145.93 267.059L192.47 313.6L128.895 330.635Z" stroke="#00957E"/><text x="147" y="319" font-family="Courier New" font-size="40" rotate="-18" fill="#00957E">3</text>';
        } else if (round == 4) {
            item = position == 1
                ? '<circle cx="175.979" cy="262.979" r="28" transform="rotate(3.05675 175.979 262.979)" stroke="#D10019"/><text x="162" y="276" font-family="Courier New" font-size="40" rotate="3" fill="#D10019">4</text>'
                : '<path d="M150.739 289.599L178.954 230.136L216.343 284.302L150.739 289.599Z" stroke="#00957E"/><text x="170" y="281" font-family="Courier New" font-size="40" rotate="-7" fill="#00957E">4</text>';
        } else if (round == 5) {
            item = position == 1
                ? '<circle cx="279.614" cy="230.614" r="28" transform="rotate(-9.01508 279.614 230.614)" stroke="#D10019"/><text x="271" y="246" font-family="Courier New" font-size="40" rotate="-9" fill="#D10019">5</text>'
                : '<path d="M233.007 266.845L266.205 210.013L298.824 267.18L233.007 266.845Z" stroke="#00957E"/><text x="255" y="260" font-family="Courier New" font-size="40" fill="#00957E">5</text>';
        } else {
            item = position == 1
                ? '<circle cx="273.833" cy="332.833" r="28" transform="rotate(14.7947 273.833 332.833)" stroke="#D10019"/><text x="258" y="343" font-family="Courier New" font-size="40" rotate="9" fill="#D10019">6</text>'
                : '<path d="M203.483 347.285L240.321 292.742L269.138 351.916L203.483 347.285Z" stroke="#00957E"/><text x="224" y="342" font-family="Courier New" font-size="40"  fill="#00957E">6</text>';
        }

        stamp = string(abi.encodePacked(item));
    }

    function generateSVGBackground() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<defs><linearGradient id="paint0_linear_44_340" x1="174.381" y1="274.968" x2="175.554" y2="36.6047" gradientUnits="userSpaceOnUse">',
                    '<stop stop-color="#E3D4C7"/><stop offset="0.0547" stop-color="#E6D9CE"/><stop offset="0.2045" stop-color="#ECE2D9"/><stop offset="0.4149" stop-color="#EFE7E0"/>',
                    '<stop offset="1" stop-color="#F0E8E2"/></linearGradient>',
                    '<linearGradient id="paint1_linear_44_340" x1="0.00270863" y1="412.497" x2="350.002" y2="412.497" gradientUnits="userSpaceOnUse">'
                    '<stop stop-color="#EEE4DC"/><stop offset="1" stop-color="#F7F3EF"/></linearGradient></defs></svg>'
                )
            );
    }

    function addressToString(address _addr) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(_addr)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
        }
        return string(abi.encodePacked("0x", string(s)));
    }

    function _char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/utils/Strings.sol";
import "./NFTSVG.sol";
import "base64-sol/base64.sol";

library NFTDescriptor {
    function constructTokenURI(NFTSVG.SVGParams memory params) internal pure returns (string memory) {
        string memory svg = generateSVGImage(params);
        string memory imageURI = generateImageURI(svg);
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                "Thales Royale Passport",
                                '", "description": "',
                                generateDescription(params.season),
                                '", "attributes":"", "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateDescription(uint season) private pure returns (string memory) {
        return string(abi.encodePacked("Thales Royale Passport - season ", Strings.toString(season)));
    }

    function generateSVGImage(NFTSVG.SVGParams memory params) private pure returns (string memory svg) {
        return
            NFTSVG.generateSVG(
                NFTSVG.SVGParams(
                    params.player,
                    params.timestamp,
                    params.tokenId,
                    params.season,
                    params.round,
                    params.positions,
                    params.alive,
                    params.seasonFinished
                )
            );
    }

    function generateImageURI(string memory svg) private pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./extensions/IERC721MetadataUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/StringsUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721EnumerableUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts-4.4.1/security/Pausable.sol";
import "@openzeppelin/contracts-4.4.1/access/Ownable.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/utils/SafeERC20.sol";

// internal
import "../../interfaces/ITherundownConsumer.sol";

/// @title Wrapper contract which calls CL sports data (Link to docs: https://market.link/nodes/TheRundown/integrations)
/// @author gruja
contract TherundownConsumerWrapper is ChainlinkClient, Ownable, Pausable {
    using Chainlink for Chainlink.Request;
    using SafeERC20 for IERC20;

    ITherundownConsumer public consumer;
    mapping(bytes32 => uint) public sportIdPerRequestId;
    mapping(bytes32 => uint) public datePerRequest;
    uint public paymentCreate;
    uint public paymentResolve;
    uint public paymentOdds;
    IERC20 public linkToken;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _link,
        address _oracle,
        address _consumer,
        uint _paymentCreate,
        uint _paymentResolve,
        uint _paymentOdds
    ) {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
        consumer = ITherundownConsumer(_consumer);
        paymentCreate = _paymentCreate;
        paymentResolve = _paymentResolve;
        paymentOdds = _paymentOdds;
        linkToken = IERC20(_link);
    }

    /* ========== CONSUMER REQUEST FUNCTIONS ========== */

    /// @notice request of create/resolve games on a specific date with specific sport with optional filters
    /// @param _specId specification id which is provided by CL
    /// @param _market string which can be "create" or "resolve"
    /// @param _sportId sports id which is provided from CL (Example: NBA = 4)
    /// @param _date date on which game/games are played
    /// @param _statusIds optional param, grap only for specific statusess
    /// @param _gameIds optional param, grap only for specific games
    function requestGamesResolveWithFilters(
        bytes32 _specId,
        string memory _market,
        uint256 _sportId,
        uint256 _date,
        string[] memory _statusIds,
        string[] memory _gameIds
    ) public whenNotPaused isValidRequest(_market, _sportId) {
        Chainlink.Request memory req;
        uint payment;

        if (keccak256(abi.encodePacked(_market)) == keccak256(abi.encodePacked("create"))) {
            req = buildChainlinkRequest(_specId, address(this), this.fulfillGamesCreated.selector);
            payment = paymentCreate;
        } else {
            req = buildChainlinkRequest(_specId, address(this), this.fulfillGamesResolved.selector);
            payment = paymentResolve;
        }

        req.addUint("date", _date);
        req.add("market", _market);
        req.addUint("sportId", _sportId);
        req.addStringArray("statusIds", _statusIds);
        req.addStringArray("gameIds", _gameIds);

        _putLink(msg.sender, payment);

        bytes32 requestId = sendChainlinkRequest(req, payment);
        sportIdPerRequestId[requestId] = _sportId;
        datePerRequest[requestId] = _date;
    }

    /// @notice request of create/resolve games on a specific date with specific sport without filters
    /// @param _specId specification id which is provided by CL
    /// @param _market string which can be "create" or "resolve"
    /// @param _sportId sports id which is provided from CL (Example: NBA = 4)
    /// @param _date date on which game/games are played
    function requestGames(
        bytes32 _specId,
        string memory _market,
        uint256 _sportId,
        uint256 _date
    ) public whenNotPaused isValidRequest(_market, _sportId) {
        Chainlink.Request memory req;
        uint payment;

        if (keccak256(abi.encodePacked(_market)) == keccak256(abi.encodePacked("create"))) {
            req = buildChainlinkRequest(_specId, address(this), this.fulfillGamesCreated.selector);
            payment = paymentCreate;
        } else {
            req = buildChainlinkRequest(_specId, address(this), this.fulfillGamesResolved.selector);
            payment = paymentResolve;
        }

        req.addUint("date", _date);
        req.add("market", _market);
        req.addUint("sportId", _sportId);

        _putLink(msg.sender, payment);

        bytes32 requestId = sendChainlinkRequest(req, payment);
        sportIdPerRequestId[requestId] = _sportId;
        datePerRequest[requestId] = _date;
    }

    /// @notice request for odds in games on a specific date with specific sport with filters
    /// @param _specId specification id which is provided by CL
    /// @param _sportId sports id which is provided from CL (Example: NBA = 4)
    /// @param _date date on which game/games are played
    /// @param _gameIds optional param, grap only for specific games
    function requestOddsWithFilters(
        bytes32 _specId,
        uint256 _sportId,
        uint256 _date,
        string[] memory _gameIds
    ) public whenNotPaused {
        require(consumer.isSupportedSport(_sportId), "SportId is not supported");

        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillGamesOdds.selector);

        req.addUint("date", _date);
        req.addUint("sportId", _sportId);

        // optional param.
        if (_gameIds.length > 0) {
            req.addStringArray("gameIds", _gameIds);
        }

        _putLink(msg.sender, paymentOdds);

        bytes32 requestId = sendChainlinkRequest(req, paymentOdds);
        sportIdPerRequestId[requestId] = _sportId;
        datePerRequest[requestId] = _date;
    }

    /* ========== CONSUMER FULFILL FUNCTIONS ========== */

    /// @notice proxy all retrieved data for created games from CL to consumer
    /// @param _requestId request id autogenerated from CL
    /// @param _games array of a games
    function fulfillGamesCreated(bytes32 _requestId, bytes[] memory _games) external recordChainlinkFulfillment(_requestId) {
        consumer.fulfillGamesCreated(_requestId, _games, sportIdPerRequestId[_requestId], datePerRequest[_requestId]);
    }

    /// @notice proxy all retrieved data for resolved games from CL to consumer
    /// @param _requestId request id autogenerated from CL
    /// @param _games array of a games
    function fulfillGamesResolved(bytes32 _requestId, bytes[] memory _games)
        external
        recordChainlinkFulfillment(_requestId)
    {
        consumer.fulfillGamesResolved(_requestId, _games, sportIdPerRequestId[_requestId]);
    }

    /// @notice proxy all retrieved data for odds in games from CL to consumer
    /// @param _requestId request id autogenerated from CL
    /// @param _games array of a games
    function fulfillGamesOdds(bytes32 _requestId, bytes[] memory _games) external recordChainlinkFulfillment(_requestId) {
        consumer.fulfillGamesOdds(_requestId, _games, datePerRequest[_requestId]);
    }

    /* ========== VIEWS ========== */

    /// @notice getting oracle address for CL data sport feed
    /// @return address of oracle
    function getOracleAddress() external view returns (address) {
        return chainlinkOracleAddress();
    }

    /// @notice getting LINK token address for payment for requests
    /// @return address of LINK token
    function getTokenAddress() external view returns (address) {
        return chainlinkTokenAddress();
    }

    /* ========== INTERNALS ========== */

    function _putLink(address _sender, uint _payment) internal {
        linkToken.safeTransferFrom(_sender, address(this), _payment);
    }

    /* ========== CONTRACT MANAGEMENT ========== */

    /// @notice setting payment for game creation request
    /// @param _paymentCreate amount of LINK per request for create games
    function setPaymentCreate(uint _paymentCreate) external onlyOwner {
        require(_paymentCreate > 0, "Can not be zero");
        paymentCreate = _paymentCreate;
        emit NewPaymentAmountCreate(_paymentCreate);
    }

    /// @notice setting payment for game resolve request
    /// @param _paymentResolve amount of LINK per request for resolve games
    function setPaymentResolve(uint _paymentResolve) external onlyOwner {
        require(_paymentResolve > 0, "Can not be zero");
        paymentResolve = _paymentResolve;
        emit NewPaymentAmountResolve(_paymentResolve);
    }

    /// @notice setting payment for odds request
    /// @param _paymentOdds amount of LINK per request for game odds
    function setPaymentOdds(uint _paymentOdds) external onlyOwner {
        require(_paymentOdds > 0, "Can not be zero");
        paymentOdds = _paymentOdds;
        emit NewPaymentAmountOdds(_paymentOdds);
    }

    /// @notice setting new oracle address
    /// @param _oracle address of oracle sports data feed
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid address");
        setChainlinkOracle(_oracle);
        emit NewOracleAddress(_oracle);
    }

    /// @notice setting consumer address
    /// @param _consumer address of a consumer which gets the data from CL requests
    function setConsumer(address _consumer) external onlyOwner {
        require(_consumer != address(0), "Invalid address");
        consumer = ITherundownConsumer(_consumer);
        emit NewConsumer(_consumer);
    }

    /// @notice setting link address
    /// @param _link address of a LINK which request will be paid
    function setLink(address _link) external onlyOwner {
        require(_link != address(0), "Invalid address");
        setChainlinkToken(_link);
        linkToken = IERC20(_link);
        emit NewLinkAddress(_link);
    }

    /* ========== MODIFIERS ========== */

    modifier isValidRequest(string memory _market, uint256 _sportId) {
        require(consumer.isSupportedMarketType(_market), "Market is not supported");
        require(consumer.isSupportedSport(_sportId), "SportId is not supported");
        _;
    }

    /* ========== EVENTS ========== */

    event NewOracleAddress(address _oracle);
    event NewPaymentAmountCreate(uint _paymentCreate);
    event NewPaymentAmountResolve(uint _paymentResolve);
    event NewPaymentAmountOdds(uint _paymentOdds);
    event NewConsumer(address _consumer);
    event NewLinkAddress(address _link);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Chainlink.sol";
import "./interfaces/ENSInterface.sol";
import "./interfaces/LinkTokenInterface.sol";
import "./interfaces/ChainlinkRequestInterface.sol";
import "./interfaces/OperatorInterface.sol";
import "./interfaces/PointerInterface.sol";
import {ENSResolver as ENSResolver_Chainlink} from "./vendor/ENSResolver.sol";

/**
 * @title The ChainlinkClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Chainlink network
 */
abstract contract ChainlinkClient {
  using Chainlink for Chainlink.Request;

  uint256 internal constant LINK_DIVISIBILITY = 10**18;
  uint256 private constant AMOUNT_OVERRIDE = 0;
  address private constant SENDER_OVERRIDE = address(0);
  uint256 private constant ORACLE_ARGS_VERSION = 1;
  uint256 private constant OPERATOR_ARGS_VERSION = 2;
  bytes32 private constant ENS_TOKEN_SUBNAME = keccak256("link");
  bytes32 private constant ENS_ORACLE_SUBNAME = keccak256("oracle");
  address private constant LINK_TOKEN_POINTER = 0xC89bD4E1632D3A43CB03AAAd5262cbe4038Bc571;

  ENSInterface private s_ens;
  bytes32 private s_ensNode;
  LinkTokenInterface private s_link;
  OperatorInterface private s_oracle;
  uint256 private s_requestCount = 1;
  mapping(bytes32 => address) private s_pendingRequests;

  event ChainlinkRequested(bytes32 indexed id);
  event ChainlinkFulfilled(bytes32 indexed id);
  event ChainlinkCancelled(bytes32 indexed id);

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackAddr address to operate the callback on
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Chainlink Request struct in memory
   */
  function buildChainlinkRequest(
    bytes32 specId,
    address callbackAddr,
    bytes4 callbackFunctionSignature
  ) internal pure returns (Chainlink.Request memory) {
    Chainlink.Request memory req;
    return req.initialize(specId, callbackAddr, callbackFunctionSignature);
  }

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Chainlink Request struct in memory
   */
  function buildOperatorRequest(bytes32 specId, bytes4 callbackFunctionSignature)
    internal
    view
    returns (Chainlink.Request memory)
  {
    Chainlink.Request memory req;
    return req.initialize(specId, address(this), callbackFunctionSignature);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev Calls `chainlinkRequestTo` with the stored oracle address
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendChainlinkRequest(Chainlink.Request memory req, uint256 payment) internal returns (bytes32) {
    return sendChainlinkRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendChainlinkRequestTo(
    address oracleAddress,
    Chainlink.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      ChainlinkRequestInterface.oracleRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      req.id,
      address(this),
      req.callbackFunctionId,
      nonce,
      ORACLE_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev This function supports multi-word response
   * @dev Calls `sendOperatorRequestTo` with the stored oracle address
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendOperatorRequest(Chainlink.Request memory req, uint256 payment) internal returns (bytes32) {
    return sendOperatorRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev This function supports multi-word response
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendOperatorRequestTo(
    address oracleAddress,
    Chainlink.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      OperatorInterface.operatorRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      req.id,
      req.callbackFunctionId,
      nonce,
      OPERATOR_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Make a request to an oracle
   * @param oracleAddress The address of the oracle for the request
   * @param nonce used to generate the request ID
   * @param payment The amount of LINK to send for the request
   * @param encodedRequest data encoded for request type specific format
   * @return requestId The request ID
   */
  function _rawRequest(
    address oracleAddress,
    uint256 nonce,
    uint256 payment,
    bytes memory encodedRequest
  ) private returns (bytes32 requestId) {
    requestId = keccak256(abi.encodePacked(this, nonce));
    s_pendingRequests[requestId] = oracleAddress;
    emit ChainlinkRequested(requestId);
    require(s_link.transferAndCall(oracleAddress, payment, encodedRequest), "unable to transferAndCall to oracle");
  }

  /**
   * @notice Allows a request to be cancelled if it has not been fulfilled
   * @dev Requires keeping track of the expiration value emitted from the oracle contract.
   * Deletes the request from the `pendingRequests` mapping.
   * Emits ChainlinkCancelled event.
   * @param requestId The request ID
   * @param payment The amount of LINK sent for the request
   * @param callbackFunc The callback function specified for the request
   * @param expiration The time of the expiration for the request
   */
  function cancelChainlinkRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunc,
    uint256 expiration
  ) internal {
    OperatorInterface requested = OperatorInterface(s_pendingRequests[requestId]);
    delete s_pendingRequests[requestId];
    emit ChainlinkCancelled(requestId);
    requested.cancelOracleRequest(requestId, payment, callbackFunc, expiration);
  }

  /**
   * @notice the next request count to be used in generating a nonce
   * @dev starts at 1 in order to ensure consistent gas cost
   * @return returns the next request count to be used in a nonce
   */
  function getNextRequestCount() internal view returns (uint256) {
    return s_requestCount;
  }

  /**
   * @notice Sets the stored oracle address
   * @param oracleAddress The address of the oracle contract
   */
  function setChainlinkOracle(address oracleAddress) internal {
    s_oracle = OperatorInterface(oracleAddress);
  }

  /**
   * @notice Sets the LINK token address
   * @param linkAddress The address of the LINK token contract
   */
  function setChainlinkToken(address linkAddress) internal {
    s_link = LinkTokenInterface(linkAddress);
  }

  /**
   * @notice Sets the Chainlink token address for the public
   * network as given by the Pointer contract
   */
  function setPublicChainlinkToken() internal {
    setChainlinkToken(PointerInterface(LINK_TOKEN_POINTER).getAddress());
  }

  /**
   * @notice Retrieves the stored address of the LINK token
   * @return The address of the LINK token
   */
  function chainlinkTokenAddress() internal view returns (address) {
    return address(s_link);
  }

  /**
   * @notice Retrieves the stored address of the oracle contract
   * @return The address of the oracle contract
   */
  function chainlinkOracleAddress() internal view returns (address) {
    return address(s_oracle);
  }

  /**
   * @notice Allows for a request which was created on another contract to be fulfilled
   * on this contract
   * @param oracleAddress The address of the oracle contract that will fulfill the request
   * @param requestId The request ID used for the response
   */
  function addChainlinkExternalRequest(address oracleAddress, bytes32 requestId) internal notPendingRequest(requestId) {
    s_pendingRequests[requestId] = oracleAddress;
  }

  /**
   * @notice Sets the stored oracle and LINK token contracts with the addresses resolved by ENS
   * @dev Accounts for subnodes having different resolvers
   * @param ensAddress The address of the ENS contract
   * @param node The ENS node hash
   */
  function useChainlinkWithENS(address ensAddress, bytes32 node) internal {
    s_ens = ENSInterface(ensAddress);
    s_ensNode = node;
    bytes32 linkSubnode = keccak256(abi.encodePacked(s_ensNode, ENS_TOKEN_SUBNAME));
    ENSResolver_Chainlink resolver = ENSResolver_Chainlink(s_ens.resolver(linkSubnode));
    setChainlinkToken(resolver.addr(linkSubnode));
    updateChainlinkOracleWithENS();
  }

  /**
   * @notice Sets the stored oracle contract with the address resolved by ENS
   * @dev This may be called on its own as long as `useChainlinkWithENS` has been called previously
   */
  function updateChainlinkOracleWithENS() internal {
    bytes32 oracleSubnode = keccak256(abi.encodePacked(s_ensNode, ENS_ORACLE_SUBNAME));
    ENSResolver_Chainlink resolver = ENSResolver_Chainlink(s_ens.resolver(oracleSubnode));
    setChainlinkOracle(resolver.addr(oracleSubnode));
  }

  /**
   * @notice Ensures that the fulfillment is valid for this contract
   * @dev Use if the contract developer prefers methods instead of modifiers for validation
   * @param requestId The request ID for fulfillment
   */
  function validateChainlinkCallback(bytes32 requestId)
    internal
    recordChainlinkFulfillment(requestId)
  // solhint-disable-next-line no-empty-blocks
  {

  }

  /**
   * @dev Reverts if the sender is not the oracle of the request.
   * Emits ChainlinkFulfilled event.
   * @param requestId The request ID for fulfillment
   */
  modifier recordChainlinkFulfillment(bytes32 requestId) {
    require(msg.sender == s_pendingRequests[requestId], "Source must be the oracle of the request");
    delete s_pendingRequests[requestId];
    emit ChainlinkFulfilled(requestId);
    _;
  }

  /**
   * @dev Reverts if the request is already pending
   * @param requestId The request ID for fulfillment
   */
  modifier notPendingRequest(bytes32 requestId) {
    require(s_pendingRequests[requestId] == address(0), "Request is already pending");
    _;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CBORChainlink} from "./vendor/CBORChainlink.sol";
import {BufferChainlink} from "./vendor/BufferChainlink.sol";

/**
 * @title Library for common Chainlink functions
 * @dev Uses imported CBOR library for encoding to buffer
 */
library Chainlink {
  uint256 internal constant defaultBufferSize = 256; // solhint-disable-line const-name-snakecase

  using CBORChainlink for BufferChainlink.buffer;

  struct Request {
    bytes32 id;
    address callbackAddress;
    bytes4 callbackFunctionId;
    uint256 nonce;
    BufferChainlink.buffer buf;
  }

  /**
   * @notice Initializes a Chainlink request
   * @dev Sets the ID, callback address, and callback function signature on the request
   * @param self The uninitialized request
   * @param jobId The Job Specification ID
   * @param callbackAddr The callback address
   * @param callbackFunc The callback function signature
   * @return The initialized request
   */
  function initialize(
    Request memory self,
    bytes32 jobId,
    address callbackAddr,
    bytes4 callbackFunc
  ) internal pure returns (Chainlink.Request memory) {
    BufferChainlink.init(self.buf, defaultBufferSize);
    self.id = jobId;
    self.callbackAddress = callbackAddr;
    self.callbackFunctionId = callbackFunc;
    return self;
  }

  /**
   * @notice Sets the data for the buffer without encoding CBOR on-chain
   * @dev CBOR can be closed with curly-brackets {} or they can be left off
   * @param self The initialized request
   * @param data The CBOR data
   */
  function setBuffer(Request memory self, bytes memory data) internal pure {
    BufferChainlink.init(self.buf, data.length);
    BufferChainlink.append(self.buf, data);
  }

  /**
   * @notice Adds a string value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The string value to add
   */
  function add(
    Request memory self,
    string memory key,
    string memory value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeString(value);
  }

  /**
   * @notice Adds a bytes value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The bytes value to add
   */
  function addBytes(
    Request memory self,
    string memory key,
    bytes memory value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeBytes(value);
  }

  /**
   * @notice Adds a int256 value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The int256 value to add
   */
  function addInt(
    Request memory self,
    string memory key,
    int256 value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeInt(value);
  }

  /**
   * @notice Adds a uint256 value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The uint256 value to add
   */
  function addUint(
    Request memory self,
    string memory key,
    uint256 value
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeUInt(value);
  }

  /**
   * @notice Adds an array of strings to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param values The array of string values to add
   */
  function addStringArray(
    Request memory self,
    string memory key,
    string[] memory values
  ) internal pure {
    self.buf.encodeString(key);
    self.buf.startArray();
    for (uint256 i = 0; i < values.length; i++) {
      self.buf.encodeString(values[i]);
    }
    self.buf.endSequence();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ENSInterface {
  // Logged when the owner of a node assigns a new owner to a subnode.
  event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

  // Logged when the owner of a node transfers ownership to a new account.
  event Transfer(bytes32 indexed node, address owner);

  // Logged when the resolver for a node changes.
  event NewResolver(bytes32 indexed node, address resolver);

  // Logged when the TTL of a node changes
  event NewTTL(bytes32 indexed node, uint64 ttl);

  function setSubnodeOwner(
    bytes32 node,
    bytes32 label,
    address owner
  ) external;

  function setResolver(bytes32 node, address resolver) external;

  function setOwner(bytes32 node, address owner) external;

  function setTTL(bytes32 node, uint64 ttl) external;

  function owner(bytes32 node) external view returns (address);

  function resolver(bytes32 node) external view returns (address);

  function ttl(bytes32 node) external view returns (uint64);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ChainlinkRequestInterface {
  function oracleRequest(
    address sender,
    uint256 requestPrice,
    bytes32 serviceAgreementID,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion,
    bytes calldata data
  ) external;

  function cancelOracleRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunctionId,
    uint256 expiration
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OracleInterface.sol";
import "./ChainlinkRequestInterface.sol";

interface OperatorInterface is OracleInterface, ChainlinkRequestInterface {
  function operatorRequest(
    address sender,
    uint256 payment,
    bytes32 specId,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion,
    bytes calldata data
  ) external;

  function fulfillOracleRequest2(
    bytes32 requestId,
    uint256 payment,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 expiration,
    bytes calldata data
  ) external returns (bool);

  function ownerTransferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function distributeFunds(address payable[] calldata receivers, uint256[] calldata amounts) external payable;

  function getAuthorizedSenders() external returns (address[] memory);

  function setAuthorizedSenders(address[] calldata senders) external;

  function getForwarder() external returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface PointerInterface {
  function getAddress() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ENSResolver {
  function addr(bytes32 node) public view virtual returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.19;

import {BufferChainlink} from "./BufferChainlink.sol";

library CBORChainlink {
  using BufferChainlink for BufferChainlink.buffer;

  uint8 private constant MAJOR_TYPE_INT = 0;
  uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
  uint8 private constant MAJOR_TYPE_BYTES = 2;
  uint8 private constant MAJOR_TYPE_STRING = 3;
  uint8 private constant MAJOR_TYPE_ARRAY = 4;
  uint8 private constant MAJOR_TYPE_MAP = 5;
  uint8 private constant MAJOR_TYPE_TAG = 6;
  uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

  uint8 private constant TAG_TYPE_BIGNUM = 2;
  uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

  function encodeFixedNumeric(BufferChainlink.buffer memory buf, uint8 major, uint64 value) private pure {
    if(value <= 23) {
      buf.appendUint8(uint8((major << 5) | value));
    } else if (value <= 0xFF) {
      buf.appendUint8(uint8((major << 5) | 24));
      buf.appendInt(value, 1);
    } else if (value <= 0xFFFF) {
      buf.appendUint8(uint8((major << 5) | 25));
      buf.appendInt(value, 2);
    } else if (value <= 0xFFFFFFFF) {
      buf.appendUint8(uint8((major << 5) | 26));
      buf.appendInt(value, 4);
    } else {
      buf.appendUint8(uint8((major << 5) | 27));
      buf.appendInt(value, 8);
    }
  }

  function encodeIndefiniteLengthType(BufferChainlink.buffer memory buf, uint8 major) private pure {
    buf.appendUint8(uint8((major << 5) | 31));
  }

  function encodeUInt(BufferChainlink.buffer memory buf, uint value) internal pure {
    if(value > 0xFFFFFFFFFFFFFFFF) {
      encodeBigNum(buf, value);
    } else {
      encodeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(value));
    }
  }

  function encodeInt(BufferChainlink.buffer memory buf, int value) internal pure {
    if(value < -0x10000000000000000) {
      encodeSignedBigNum(buf, value);
    } else if(value > 0xFFFFFFFFFFFFFFFF) {
      encodeBigNum(buf, uint(value));
    } else if(value >= 0) {
      encodeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(uint256(value)));
    } else {
      encodeFixedNumeric(buf, MAJOR_TYPE_NEGATIVE_INT, uint64(uint256(-1 - value)));
    }
  }

  function encodeBytes(BufferChainlink.buffer memory buf, bytes memory value) internal pure {
    encodeFixedNumeric(buf, MAJOR_TYPE_BYTES, uint64(value.length));
    buf.append(value);
  }

  function encodeBigNum(BufferChainlink.buffer memory buf, uint value) internal pure {
    buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
    encodeBytes(buf, abi.encode(value));
  }

  function encodeSignedBigNum(BufferChainlink.buffer memory buf, int input) internal pure {
    buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM));
    encodeBytes(buf, abi.encode(uint256(-1 - input)));
  }

  function encodeString(BufferChainlink.buffer memory buf, string memory value) internal pure {
    encodeFixedNumeric(buf, MAJOR_TYPE_STRING, uint64(bytes(value).length));
    buf.append(bytes(value));
  }

  function startArray(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
  }

  function startMap(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
  }

  function endSequence(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for writing to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
library BufferChainlink {
  /**
   * @dev Represents a mutable buffer. Buffers have a current value (buf) and
   *      a capacity. The capacity may be longer than the current value, in
   *      which case it can be extended without the need to allocate more memory.
   */
  struct buffer {
    bytes buf;
    uint256 capacity;
  }

  /**
   * @dev Initializes a buffer with an initial capacity.
   * @param buf The buffer to initialize.
   * @param capacity The number of bytes of space to allocate the buffer.
   * @return The buffer, for chaining.
   */
  function init(buffer memory buf, uint256 capacity) internal pure returns (buffer memory) {
    if (capacity % 32 != 0) {
      capacity += 32 - (capacity % 32);
    }
    // Allocate space for the buffer data
    buf.capacity = capacity;
    assembly {
      let ptr := mload(0x40)
      mstore(buf, ptr)
      mstore(ptr, 0)
      mstore(0x40, add(32, add(ptr, capacity)))
    }
    return buf;
  }

  /**
   * @dev Initializes a new buffer from an existing bytes object.
   *      Changes to the buffer may mutate the original value.
   * @param b The bytes object to initialize the buffer with.
   * @return A new buffer.
   */
  function fromBytes(bytes memory b) internal pure returns (buffer memory) {
    buffer memory buf;
    buf.buf = b;
    buf.capacity = b.length;
    return buf;
  }

  function resize(buffer memory buf, uint256 capacity) private pure {
    bytes memory oldbuf = buf.buf;
    init(buf, capacity);
    append(buf, oldbuf);
  }

  function max(uint256 a, uint256 b) private pure returns (uint256) {
    if (a > b) {
      return a;
    }
    return b;
  }

  /**
   * @dev Sets buffer length to 0.
   * @param buf The buffer to truncate.
   * @return The original buffer, for chaining..
   */
  function truncate(buffer memory buf) internal pure returns (buffer memory) {
    assembly {
      let bufptr := mload(buf)
      mstore(bufptr, 0)
    }
    return buf;
  }

  /**
   * @dev Writes a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The start offset to write to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    require(len <= data.length);

    if (off + len > buf.capacity) {
      resize(buf, max(buf.capacity, len + off) * 2);
    }

    uint256 dest;
    uint256 src;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Start address = buffer address + offset + sizeof(buffer length)
      dest := add(add(bufptr, 32), off)
      // Update buffer length if we're extending it
      if gt(add(len, off), buflen) {
        mstore(bufptr, add(len, off))
      }
      src := add(data, 32)
    }

    // Copy word-length chunks while possible
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }

    // Copy remaining bytes
    unchecked {
      uint256 mask = (256**(32 - len)) - 1;
      assembly {
        let srcpart := and(mload(src), not(mask))
        let destpart := and(mload(dest), mask)
        mstore(dest, or(destpart, srcpart))
      }
    }

    return buf;
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function append(
    buffer memory buf,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, len);
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, data.length);
  }

  /**
   * @dev Writes a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write the byte at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeUint8(
    buffer memory buf,
    uint256 off,
    uint8 data
  ) internal pure returns (buffer memory) {
    if (off >= buf.capacity) {
      resize(buf, buf.capacity * 2);
    }

    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Address = buffer address + sizeof(buffer length) + off
      let dest := add(add(bufptr, off), 32)
      mstore8(dest, data)
      // Update buffer length if we extended it
      if eq(off, buflen) {
        mstore(bufptr, add(buflen, 1))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory) {
    return writeUint8(buf, buf.buf.length, data);
  }

  /**
   * @dev Writes up to 32 bytes to the buffer. Resizes if doing so would
   *      exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (left-aligned).
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes32 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    unchecked {
      uint256 mask = (256**len) - 1;
      // Right-align data
      data = data >> (8 * (32 - len));
      assembly {
        // Memory address of the buffer data
        let bufptr := mload(buf)
        // Address = buffer address + sizeof(buffer length) + off + len
        let dest := add(add(bufptr, off), len)
        mstore(dest, or(and(mload(dest), not(mask)), data))
        // Update buffer length if we extended it
        if gt(add(off, len), mload(bufptr)) {
          mstore(bufptr, add(off, len))
        }
      }
    }
    return buf;
  }

  /**
   * @dev Writes a bytes20 to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeBytes20(
    buffer memory buf,
    uint256 off,
    bytes20 data
  ) internal pure returns (buffer memory) {
    return write(buf, off, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chhaining.
   */
  function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, 32);
  }

  /**
   * @dev Writes an integer to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (right-aligned).
   * @return The original buffer, for chaining.
   */
  function writeInt(
    buffer memory buf,
    uint256 off,
    uint256 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    uint256 mask = (256**len) - 1;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Address = buffer address + off + sizeof(buffer length) + len
      let dest := add(add(bufptr, off), len)
      mstore(dest, or(and(mload(dest), not(mask)), data))
      // Update buffer length if we extended it
      if gt(add(off, len), mload(bufptr)) {
        mstore(bufptr, add(off, len))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the end of the buffer. Resizes if doing so would
   * exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer.
   */
  function appendInt(
    buffer memory buf,
    uint256 data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return writeInt(buf, buf.buf.length, data, len);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface OracleInterface {
  function fulfillOracleRequest(
    bytes32 requestId,
    uint256 payment,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 expiration,
    bytes32 data
  ) external returns (bool);

  function isAuthorizedSender(address node) external view returns (bool);

  function withdraw(address recipient, uint256 amount) external;

  function withdrawable() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "./SportPositionalMarket.sol";

contract SportPositionalMarketMastercopy is SportPositionalMarket {
    constructor() OwnedWithInit() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "../../interfaces/ISportsAMM.sol";
import "../../interfaces/ISportPositionalMarket.sol";
import "../../interfaces/ISportPositionalMarketManager.sol";
import "../../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SportPositionalMarketData is Initializable, ProxyOwned, ProxyPausable {
    struct ActiveMarketsOdds {
        bytes32 market;
        uint[] odds;
    }

    address public manager;
    address public sportsAMM;

    function initialize(address _owner) external initializer {
        setOwner(_owner);
    }

    function getOddsForAllActiveMarkets() external view returns (ActiveMarketsOdds[] memory) {
        address[] memory activeMarkets =
            ISportPositionalMarketManager(manager).activeMarkets(
                0,
                ISportPositionalMarketManager(manager).numActiveMarkets()
            );
        ActiveMarketsOdds[] memory marketOdds = new ActiveMarketsOdds[](activeMarkets.length);
        for (uint i = 0; i < activeMarkets.length; i++) {
            marketOdds[i].market = ISportPositionalMarket(activeMarkets[i]).getGameId();
            marketOdds[i].odds = ISportsAMM(sportsAMM).getMarketDefaultOdds(activeMarkets[i], false);
        }
        return marketOdds;
    }

    function setSportPositionalMarketManager(address _manager) external onlyOwner {
        manager = _manager;
        emit SportPositionalMarketManagerChanged(_manager);
    }

    function setSportsAMM(address _sportsAMM) external onlyOwner {
        sportsAMM = _sportsAMM;
        emit SetSportsAMM(_sportsAMM);
    }

    event SportPositionalMarketManagerChanged(address _manager);
    event SetSportsAMM(address _sportsAMM);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISportsAMM {
    /* ========== VIEWS / VARIABLES ========== */

    function getMarketDefaultOdds(address _market, bool isSell) external view returns (uint[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// internal
import "../../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "./GamesQueue.sol";

// interface
import "../../interfaces/ISportPositionalMarketManager.sol";

/// @title Consumer contract which stores all data from CL data feed (Link to docs: https://market.link/nodes/TheRundown/integrations), also creates all sports markets based on that data
/// @author gruja
contract TherundownConsumer is Initializable, ProxyOwned, ProxyPausable {
    /* ========== CONSTANTS =========== */

    uint public constant CANCELLED = 0;
    uint public constant HOME_WIN = 1;
    uint public constant AWAY_WIN = 2;
    uint public constant RESULT_DRAW = 3;
    uint public constant MIN_TAG_NUMBER = 9000;

    /* ========== CONSUMER STATE VARIABLES ========== */

    struct GameCreate {
        bytes32 gameId;
        uint256 startTime;
        int24 homeOdds;
        int24 awayOdds;
        int24 drawOdds;
        string homeTeam;
        string awayTeam;
    }

    struct GameResolve {
        bytes32 gameId;
        uint8 homeScore;
        uint8 awayScore;
        uint8 statusId;
    }

    struct GameOdds {
        bytes32 gameId;
        int24 homeOdds;
        int24 awayOdds;
        int24 drawOdds;
    }

    /* ========== STATE VARIABLES ========== */

    // global params
    address public wrapperAddress;
    mapping(address => bool) public whitelistedAddresses;

    // Maps <RequestId, Result>
    mapping(bytes32 => bytes[]) public requestIdGamesCreated;
    mapping(bytes32 => bytes[]) public requestIdGamesResolved;
    mapping(bytes32 => bytes[]) public requestIdGamesOdds;

    // Maps <GameId, Game>
    mapping(bytes32 => GameCreate) public gameCreated;
    mapping(bytes32 => GameResolve) public gameResolved;
    mapping(bytes32 => GameOdds) public gameOdds;
    mapping(bytes32 => uint) public sportsIdPerGame;
    mapping(bytes32 => bool) public gameFulfilledCreated;
    mapping(bytes32 => bool) public gameFulfilledResolved;

    // sports props
    mapping(uint => bool) public supportedSport;
    mapping(uint => bool) public twoPositionSport;
    mapping(uint => bool) public supportResolveGameStatuses;
    mapping(uint => bool) public cancelGameStatuses;

    // market props
    ISportPositionalMarketManager public sportsManager;
    mapping(bytes32 => address) public marketPerGameId;
    mapping(address => bytes32) public gameIdPerMarket;
    mapping(address => bool) public marketResolved;
    mapping(address => bool) public marketCanceled;

    // game
    GamesQueue public queues;
    mapping(bytes32 => uint) public oddsLastPulledForGame;
    mapping(uint => bytes32[]) public gamesPerDate;
    mapping(uint => mapping(uint => bool)) public isSportOnADate;
    mapping(address => bool) public invalidOdds;
    mapping(address => bool) public marketCreated;
    mapping(uint => mapping(uint => bytes32[])) public gamesPerDatePerSport;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _owner,
        uint[] memory _supportedSportIds,
        address _sportsManager,
        uint[] memory _twoPositionSports,
        GamesQueue _queues,
        uint[] memory _resolvedStatuses,
        uint[] memory _cancelGameStatuses
    ) external initializer {
        setOwner(_owner);
        _populateOnInit(_supportedSportIds, _twoPositionSports, _resolvedStatuses, _cancelGameStatuses);
        sportsManager = ISportPositionalMarketManager(_sportsManager);
        queues = _queues;
        whitelistedAddresses[_owner] = true;
    }

    /* ========== CONSUMER FULFILL FUNCTIONS ========== */

    /// @notice fulfill all data necessary to create sport markets
    /// @param _requestId unique request id form CL
    /// @param _games array of a games that needed to be stored and transfered to markets
    /// @param _sportId sports id which is provided from CL (Example: NBA = 4)
    /// @param _date date on which game/games are played
    function fulfillGamesCreated(
        bytes32 _requestId,
        bytes[] memory _games,
        uint _sportId,
        uint _date
    ) external onlyWrapper {
        requestIdGamesCreated[_requestId] = _games;

        if (_games.length > 0) {
            isSportOnADate[_date][_sportId] = true;
        }

        for (uint i = 0; i < _games.length; i++) {
            GameCreate memory game = abi.decode(_games[i], (GameCreate));
            if (
                !queues.existingGamesInCreatedQueue(game.gameId) &&
                !isSameTeamOrTBD(game.homeTeam, game.awayTeam) &&
                game.startTime > block.timestamp
            ) {
                gamesPerDate[_date].push(game.gameId);
                gamesPerDatePerSport[_sportId][_date].push(game.gameId);
                _createGameFulfill(_requestId, game, _sportId);
            }
        }
    }

    /// @notice fulfill all data necessary to resolve sport markets
    /// @param _requestId unique request id form CL
    /// @param _games array of a games that needed to be resolved
    /// @param _sportId sports id which is provided from CL (Example: NBA = 4)
    function fulfillGamesResolved(
        bytes32 _requestId,
        bytes[] memory _games,
        uint _sportId
    ) external onlyWrapper {
        requestIdGamesResolved[_requestId] = _games;
        for (uint i = 0; i < _games.length; i++) {
            GameResolve memory game = abi.decode(_games[i], (GameResolve));
            // if game is not resolved already and there is market for that game
            if (!queues.existingGamesInResolvedQueue(game.gameId) && marketPerGameId[game.gameId] != address(0)) {
                _resolveGameFulfill(_requestId, game, _sportId);
            }
        }
    }

    /// @notice fulfill all data necessary to populate odds of a game
    /// @param _requestId unique request id form CL
    /// @param _games array of a games that needed to update the odds
    /// @param _date date on which game/games are played
    function fulfillGamesOdds(
        bytes32 _requestId,
        bytes[] memory _games,
        uint _date
    ) external onlyWrapper {
        requestIdGamesOdds[_requestId] = _games;
        for (uint i = 0; i < _games.length; i++) {
            GameOdds memory game = abi.decode(_games[i], (GameOdds));
            // game needs to be fulfilled and market needed to be created
            if (gameFulfilledCreated[game.gameId] && marketPerGameId[game.gameId] != address(0)) {
                _oddsGameFulfill(_requestId, game);
            }
        }
    }

    /// @notice creates market for a given game id
    /// @param _gameId game id
    function createMarketForGame(bytes32 _gameId) public {
        require(marketPerGameId[_gameId] == address(0), "Market for game already exists");
        require(gameFulfilledCreated[_gameId], "No such game fulfilled, created");
        require(queues.gamesCreateQueue(queues.firstCreated()) == _gameId, "Must be first in a queue");
        _createMarket(_gameId);
    }

    /// @notice creates markets for a given game ids
    /// @param _gameIds game ids as array
    function createAllMarketsForGames(bytes32[] memory _gameIds) external {
        for (uint i; i < _gameIds.length; i++) {
            createMarketForGame(_gameIds[i]);
        }
    }

    /// @notice resolve market for a given game id
    /// @param _gameId game id
    function resolveMarketForGame(bytes32 _gameId) public {
        require(!isGameResolvedOrCanceled(_gameId), "Market resoved or canceled");
        require(gameFulfilledResolved[_gameId], "No such game Fulfilled, resolved");
        _resolveMarket(_gameId);
    }

    /// @notice resolve all markets for a given game ids
    /// @param _gameIds game ids as array
    function resolveAllMarketsForGames(bytes32[] memory _gameIds) external {
        for (uint i; i < _gameIds.length; i++) {
            resolveMarketForGame(_gameIds[i]);
        }
    }

    /// @notice resolve market for a given game id
    /// @param _gameId game id
    /// @param _outcome outcome of a game (1: home win, 2: away win, 3: draw, 0: cancel market)
    /// @param _homeScore score of home team
    /// @param _awayScore score of away team
    function resolveGameManually(
        bytes32 _gameId,
        uint _outcome,
        uint8 _homeScore,
        uint8 _awayScore
    ) external isAddressWhitelisted canGameBeResolved(_gameId, _outcome, _homeScore, _awayScore) {
        _resolveMarketManually(marketPerGameId[_gameId], _outcome, _homeScore, _awayScore);
    }

    /// @notice resolve market for a given market address
    /// @param _market market address
    /// @param _outcome outcome of a game (1: home win, 2: away win, 3: draw, 0: cancel market)
    /// @param _homeScore score of home team
    /// @param _awayScore score of away team
    function resolveMarketManually(
        address _market,
        uint _outcome,
        uint8 _homeScore,
        uint8 _awayScore
    ) external isAddressWhitelisted canGameBeResolved(gameIdPerMarket[_market], _outcome, _homeScore, _awayScore) {
        _resolveMarketManually(_market, _outcome, _homeScore, _awayScore);
    }

    /// @notice cancel market for a given market address
    /// @param _market market address
    function cancelMarketManually(address _market)
        external
        isAddressWhitelisted
        canGameBeCanceled(gameIdPerMarket[_market])
    {
        _cancelMarketManually(_market);
    }

    /// @notice pause/unpause market for a given market address
    /// @param _market market address
    /// @param _pause pause = true, unpause = false
    function pauseOrUnpauseMarketManually(address _market, bool _pause)
        external
        isAddressWhitelisted
        canGameBePaused(_market, _pause)
    {
        _pauseOrUnpauseMarket(_market, _pause);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice returns game created based on CL request id and index of a game in a array
    /// @param _requestId request id from CL
    /// @param _idx index in array
    /// @return game GameCreate game create object
    function getGameCreatedByRequestId(bytes32 _requestId, uint256 _idx) public view returns (GameCreate memory game) {
        game = abi.decode(requestIdGamesCreated[_requestId][_idx], (GameCreate));
    }

    /// @notice view function which returns game created object based on id of a game
    /// @param _gameId game id
    /// @return GameCreate game create object
    function getGameCreatedById(bytes32 _gameId) public view returns (GameCreate memory) {
        return gameCreated[_gameId];
    }

    /// @notice view function which returns odds for home team based on id of a game
    /// @param _gameId game id
    /// @return homeOdds moneyline odd in a two decimal places
    function getOddsHomeTeam(bytes32 _gameId) public view returns (int24) {
        return gameOdds[_gameId].homeOdds;
    }

    /// @notice view function which returns odds for awway team based on id of a game
    /// @param _gameId game id
    /// @return awayOdds moneyline odd in a two decimal places
    function getOddsAwayTeam(bytes32 _gameId) public view returns (int24) {
        return gameOdds[_gameId].awayOdds;
    }

    /// @notice view function which returns odds for draw based on id of a game (if game can have draw result if not return is 0)
    /// @param _gameId game id
    /// @return drawOdds moneyline odd in a two decimal places
    function getOddsDraw(bytes32 _gameId) public view returns (int24) {
        return gameOdds[_gameId].drawOdds;
    }

    /// @notice view function which returns games on certan date
    /// @param _date date
    /// @return bytes32[] list of games
    function getGamesPerdate(uint _date) public view returns (bytes32[] memory) {
        return gamesPerDate[_date];
    }

    /// @notice view function which returns games on certan date and sportid
    /// @param _sportId date
    /// @param _date date
    /// @return bytes32[] list of games
    function getGamesPerDatePerSport(uint _sportId, uint _date) public view returns (bytes32[] memory) {
        return gamesPerDatePerSport[_sportId][_date];
    }

    /// @notice view function which returns game resolved object based on id of a game
    /// @param _gameId game id
    /// @return GameResolve game resolve object
    function getGameResolvedById(bytes32 _gameId) public view returns (GameResolve memory) {
        return gameResolved[_gameId];
    }

    /// @notice view function which returns if market type is supported, checks are done in a wrapper contract
    /// @param _market type of market (create or resolve)
    /// @return bool supported or not
    function isSupportedMarketType(string memory _market) external view returns (bool) {
        return
            keccak256(abi.encodePacked(_market)) == keccak256(abi.encodePacked("create")) ||
            keccak256(abi.encodePacked(_market)) == keccak256(abi.encodePacked("resolve"));
    }

    /// @notice view function which returns if game is ready to be created and teams are defined or not
    /// @param _teamA team A in string (Example: Liverpool Liverpool)
    /// @param _teamB team B in string (Example: Arsenal Arsenal)
    /// @return bool is it ready for creation true/false
    function isSameTeamOrTBD(string memory _teamA, string memory _teamB) public view returns (bool) {
        return
            keccak256(abi.encodePacked(_teamA)) == keccak256(abi.encodePacked(_teamB)) ||
            keccak256(abi.encodePacked(_teamA)) == keccak256(abi.encodePacked("TBD TBD")) ||
            keccak256(abi.encodePacked(_teamB)) == keccak256(abi.encodePacked("TBD TBD"));
    }

    /// @notice view function which returns if game is resolved or canceled and ready for market to be resolved or canceled
    /// @param _gameId game id for which game is looking
    /// @return bool is it ready for resolve or cancel true/false
    function isGameResolvedOrCanceled(bytes32 _gameId) public view returns (bool) {
        return marketResolved[marketPerGameId[_gameId]] || marketCanceled[marketPerGameId[_gameId]];
    }

    /// @notice view function which returns if sport is supported or not
    /// @param _sportId sport id for which is looking
    /// @return bool is sport supported true/false
    function isSupportedSport(uint _sportId) external view returns (bool) {
        return supportedSport[_sportId];
    }

    /// @notice view function which returns if sport is two positional (no draw, example: NBA)
    /// @param _sportsId sport id for which is looking
    /// @return bool is sport two positional true/false
    function isSportTwoPositionsSport(uint _sportsId) public view returns (bool) {
        return twoPositionSport[_sportsId];
    }

    /// @notice view function which returns if game is resolved
    /// @param _gameId game id for which game is looking
    /// @return bool is game resolved true/false
    function isGameInResolvedStatus(bytes32 _gameId) public view returns (bool) {
        return _isGameStatusResolved(getGameResolvedById(_gameId));
    }

    /// @notice view function which returns normalized odds up to 100 (Example: 50-40-10)
    /// @param _gameId game id for which game is looking
    /// @return uint[] odds array normalized
    function getNormalizedOdds(bytes32 _gameId) public view returns (uint[] memory) {
        int[] memory odds = new int[](3);
        odds[0] = gameOdds[_gameId].homeOdds;
        odds[1] = gameOdds[_gameId].awayOdds;
        odds[2] = gameOdds[_gameId].drawOdds;
        return _calculateAndNormalizeOdds(odds);
    }

    /// @notice view function which returns normalized odd based on moneyline odd (Example: -15000)
    /// @param _americanOdd moneyline odd (Example of a param: -15000, +35000, etc.), this param is with two decimal places (-15000 is -150 in moneyline world)
    /// @return odd normalized to a 100
    function calculateNormalizedOddFromAmerican(int _americanOdd) external pure returns (uint odd) {
        if (_americanOdd > 0) {
            odd = uint(_americanOdd);
            odd = ((10000 * 1e18) / (odd + 10000)) * 100;
        } else if (_americanOdd < 0) {
            odd = uint(-_americanOdd);
            odd = ((odd * 1e18) / (odd + 10000)) * 100;
        }
    }

    /// @notice view function which returns outcome of a game based on ID
    /// @param _gameId game id for which result is looking
    /// @return _result returns 1: home win, 2: away win, 3: draw
    function getResult(bytes32 _gameId) external view returns (uint _result) {
        if (isGameInResolvedStatus(_gameId)) {
            return _calculateOutcome(getGameResolvedById(_gameId));
        }
    }

    /* ========== INTERNALS ========== */

    function _createGameFulfill(
        bytes32 requestId,
        GameCreate memory _game,
        uint _sportId
    ) internal {
        gameCreated[_game.gameId] = _game;
        sportsIdPerGame[_game.gameId] = _sportId;
        queues.enqueueGamesCreated(_game.gameId, _game.startTime, _sportId);
        gameFulfilledCreated[_game.gameId] = true;
        gameOdds[_game.gameId] = GameOdds(_game.gameId, _game.homeOdds, _game.awayOdds, _game.drawOdds);
        oddsLastPulledForGame[_game.gameId] = block.timestamp;

        emit GameCreated(requestId, _sportId, _game.gameId, _game, queues.lastCreated(), getNormalizedOdds(_game.gameId));
    }

    function _resolveGameFulfill(
        bytes32 requestId,
        GameResolve memory _game,
        uint _sportId
    ) internal {
        if (_isGameReadyToBeResolved(_game)) {
            gameResolved[_game.gameId] = _game;
            queues.enqueueGamesResolved(_game.gameId);
            gameFulfilledResolved[_game.gameId] = true;

            emit GameResolved(requestId, _sportId, _game.gameId, _game, queues.lastResolved());
        }
    }

    function _oddsGameFulfill(bytes32 requestId, GameOdds memory _game) internal {
        // if odds are valid store them if not pause market
        if (_areOddsValid(_game)) {
            gameOdds[_game.gameId] = _game;
            oddsLastPulledForGame[_game.gameId] = block.timestamp;

            // if was paused and paused by invalid odds unpause
            if (sportsManager.isMarketPaused(marketPerGameId[_game.gameId])) {
                if(invalidOdds[marketPerGameId[_game.gameId]]){
                    invalidOdds[marketPerGameId[_game.gameId]] = false;
                    _pauseOrUnpauseMarket(marketPerGameId[_game.gameId], false);
                }
            }

            emit GameOddsAdded(requestId, _game.gameId, _game, getNormalizedOdds(_game.gameId));
        } else {
            if (!sportsManager.isMarketPaused(marketPerGameId[_game.gameId])) {
                invalidOdds[marketPerGameId[_game.gameId]] = true;
                _pauseOrUnpauseMarket(marketPerGameId[_game.gameId], true);
            }

            emit InvalidOddsForMarket(requestId, marketPerGameId[_game.gameId], _game.gameId, _game);
        }
    }

    function _populateOnInit(
        uint[] memory _supportedSportIds, 
        uint[] memory _twoPositionSports, 
        uint[] memory _supportedStatuses, 
        uint[] memory _cancelStatuses ) internal 
        {
        for (uint i; i < _supportedSportIds.length; i++) {
            supportedSport[_supportedSportIds[i]] = true;
        }
        for (uint i; i < _twoPositionSports.length; i++) {
            twoPositionSport[_twoPositionSports[i]] = true;
        }
        for (uint i; i < _supportedStatuses.length; i++) {
            supportResolveGameStatuses[_supportedStatuses[i]] = true;
        }
        for (uint i; i < _cancelStatuses.length; i++) {
            cancelGameStatuses[_cancelStatuses[i]] = true;
        }
    }

    function _createMarket(bytes32 _gameId) internal {
        GameCreate memory game = getGameCreatedById(_gameId);
        uint sportId = sportsIdPerGame[_gameId];
        uint numberOfPositions = _calculateNumberOfPositionsBasedOnSport(sportId);
        uint[] memory tags = _calculateTags(sportId);

        // create
        sportsManager.createMarket(
            _gameId,
            _append(game.homeTeam, game.awayTeam), // gameLabel
            game.startTime, //maturity
            0, //initialMint
            numberOfPositions,
            tags //tags
        );

        address marketAddress = sportsManager.getActiveMarketAddress(sportsManager.numActiveMarkets() - 1);
        marketPerGameId[game.gameId] = marketAddress;
        gameIdPerMarket[marketAddress] = game.gameId;
        marketCreated[marketAddress] = true;

        queues.dequeueGamesCreated();

        emit CreateSportsMarket(marketAddress, game.gameId, game, tags, getNormalizedOdds(game.gameId));
    }

    function _resolveMarket(bytes32 _gameId) internal {
        GameResolve memory game = getGameResolvedById(_gameId);
        uint index = queues.unproccessedGamesIndex(_gameId);

        // it can return ZERO index, needs checking
        require(_gameId == queues.unproccessedGames(index), "Invalid Game ID");

        if (_isGameStatusResolved(game)) {
            if(invalidOdds[marketPerGameId[game.gameId]]){
                _pauseOrUnpauseMarket(marketPerGameId[game.gameId], false);
            }

            uint _outcome = _calculateOutcome(game);

            sportsManager.resolveMarket(marketPerGameId[game.gameId], _outcome);
            marketResolved[marketPerGameId[game.gameId]] = true;

            _cleanStorageQueue(index);

            emit ResolveSportsMarket(marketPerGameId[game.gameId], game.gameId, _outcome);
        } else if (cancelGameStatuses[game.statusId]) {
            sportsManager.resolveMarket(marketPerGameId[game.gameId], 0);
            marketCanceled[marketPerGameId[game.gameId]] = true;

            _cleanStorageQueue(index);

            emit CancelSportsMarket(marketPerGameId[game.gameId], game.gameId);
        }
    }

    function _resolveMarketManually(
        address _market,
        uint _outcome,
        uint8 _homeScore,
        uint8 _awayScore
    ) internal {
        uint index = queues.unproccessedGamesIndex(gameIdPerMarket[_market]);

        // it can return ZERO index, needs checking
        require(gameIdPerMarket[_market] == queues.unproccessedGames(index), "Invalid Game ID");

        sportsManager.resolveMarket(_market, _outcome);
        marketResolved[_market] = true;
        queues.removeItemUnproccessedGames(index);
        gameResolved[gameIdPerMarket[_market]] = GameResolve(
            gameIdPerMarket[_market],
            _homeScore,
            _awayScore,
            isSportTwoPositionsSport(sportsIdPerGame[gameIdPerMarket[_market]]) ? 8 : 11
        );

        emit GameResolved(
            gameIdPerMarket[_market],
            sportsIdPerGame[gameIdPerMarket[_market]],
            gameIdPerMarket[_market],
            gameResolved[gameIdPerMarket[_market]],
            0
        );
        emit ResolveSportsMarket(_market, gameIdPerMarket[_market], _outcome);
    }

    function _cancelMarketManually(address _market) internal {
        uint index = queues.unproccessedGamesIndex(gameIdPerMarket[_market]);

        // it can return ZERO index, needs checking
        require(gameIdPerMarket[_market] == queues.unproccessedGames(index), "Invalid Game ID");

        sportsManager.resolveMarket(_market, 0);
        marketCanceled[_market] = true;
        queues.removeItemUnproccessedGames(index);

        emit CancelSportsMarket(_market, gameIdPerMarket[_market]);
    }

    function _pauseOrUnpauseMarket(address _market, bool _pause) internal {
        sportsManager.setMarketPaused(_market, _pause);
        emit PauseSportsMarket(_market, _pause);
    }

    function _cleanStorageQueue(uint index) internal {
        queues.dequeueGamesResolved();
        queues.removeItemUnproccessedGames(index);
    }

    function _append(string memory teamA, string memory teamB) internal pure returns (string memory) {
        return string(abi.encodePacked(teamA, " vs ", teamB));
    }

    function _calculateNumberOfPositionsBasedOnSport(uint _sportsId) internal returns (uint) {
        return isSportTwoPositionsSport(_sportsId) ? 2 : 3;
    }

    function _calculateTags(uint _sportsId) internal returns (uint[] memory) {
        uint[] memory result = new uint[](1);
        result[0] = MIN_TAG_NUMBER + _sportsId;
        return result;
    }

    function _isGameReadyToBeResolved(GameResolve memory _game) internal view returns (bool) {
        return _isGameStatusResolved(_game) || cancelGameStatuses[_game.statusId];
    }

    function _isGameStatusResolved(GameResolve memory _game) internal view returns (bool) {
        return supportResolveGameStatuses[_game.statusId];
    }

    function _calculateOutcome(GameResolve memory _game) internal pure returns (uint) {
        if (_game.homeScore == _game.awayScore) {
            return RESULT_DRAW;
        }
        return _game.homeScore > _game.awayScore ? HOME_WIN : AWAY_WIN;
    }

    function _areOddsValid(GameOdds memory _game) internal view returns (bool) {
        if (isSportTwoPositionsSport(sportsIdPerGame[_game.gameId])) {
            return _game.awayOdds != 0 && _game.homeOdds != 0;
        } else {
            return _game.awayOdds != 0 && _game.homeOdds != 0 && _game.drawOdds != 0;
        }
    }

    function _isValidOutcomeForGame(bytes32 _gameId, uint _outcome) internal view returns (bool) {
        if (isSportTwoPositionsSport(sportsIdPerGame[_gameId])) {
            return _outcome == HOME_WIN || _outcome == AWAY_WIN || _outcome == CANCELLED;
        }
        return _outcome == HOME_WIN || _outcome == AWAY_WIN || _outcome == RESULT_DRAW || _outcome == CANCELLED;
    }

    function _isValidOutcomeWithResult(
        uint _outcome,
        uint _homeScore,
        uint _awayScore
    ) internal view returns (bool) {
        if (_outcome == CANCELLED) {
            return _awayScore == CANCELLED && _homeScore == CANCELLED;
        } else if (_outcome == HOME_WIN) {
            return _homeScore > _awayScore;
        } else if (_outcome == AWAY_WIN) {
            return _homeScore < _awayScore;
        } else {
            return _homeScore == _awayScore;
        }
    }

    function _calculateAndNormalizeOdds(int[] memory _americanOdds) internal pure returns (uint[] memory) {
        uint[] memory normalizedOdds = new uint[](_americanOdds.length);
        uint totalOdds;
        for (uint i = 0; i < _americanOdds.length; i++) {
            uint odd;
            if (_americanOdds[i] == 0) {
                normalizedOdds[i] = 0;
            } else if (_americanOdds[i] > 0) {
                odd = uint(_americanOdds[i]);
                normalizedOdds[i] = ((10000 * 1e18) / (odd + 10000)) * 100;
            } else if (_americanOdds[i] < 0) {
                odd = uint(-_americanOdds[i]);
                normalizedOdds[i] = ((odd * 1e18) / (odd + 10000)) * 100;
            }
            totalOdds += normalizedOdds[i];
        }
        for (uint i = 0; i < normalizedOdds.length; i++) {
            if (totalOdds == 0) {
                normalizedOdds[i] = 0;
            } else {
                normalizedOdds[i] = (1e18 * normalizedOdds[i]) / totalOdds;
            }
        }
        return normalizedOdds;
    }

    /* ========== GAMES MANAGEMENT ========== */

    /// @notice remove first game in a created queue if needed
    function removeFromCreatedQueue() external isAddressWhitelisted {
        queues.dequeueGamesCreated();
    }

    /// @notice remove first game in a resolved queue if needed
    function removeFromResolvedQueue() external isAddressWhitelisted {
        queues.dequeueGamesResolved();
    }

    /// @notice remove from unprocessed games array based on index
    /// @param _index index which needed to be removed
    function removeFromUnprocessedGamesArray(uint _index) external isAddressWhitelisted {
        queues.removeItemUnproccessedGames(_index);
    }

    /* ========== CONTRACT MANAGEMENT ========== */

    /// @notice sets if sport is suported or not (delete from supported sport)
    /// @param _sportId sport id which needs to be supported or not
    /// @param _isSupported true/false (supported or not)
    function setSupportedSport(uint _sportId, bool _isSupported) external onlyOwner {
        require(supportedSport[_sportId] != _isSupported, "Already set to that value");
        supportedSport[_sportId] = _isSupported;
        emit SupportedSportsChanged(_sportId, _isSupported);
    }

    /// @notice sets resolved status which is supported or not
    /// @param _status status ID which needs to be supported or not
    /// @param _isSupported true/false (supported or not)
    function setSupportedResolvedStatuses(uint _status, bool _isSupported) external onlyOwner {
        require(supportResolveGameStatuses[_status] != _isSupported, "Already set to that value");
        supportResolveGameStatuses[_status] = _isSupported;
        emit SupportedResolvedStatusChanged(_status, _isSupported);
    }

    /// @notice sets cancel status which is supported or not
    /// @param _status ststus ID which needs to be supported or not
    /// @param _isSupported true/false (supported or not)
    function setSupportedCancelStatuses(uint _status, bool _isSupported) external onlyOwner {
        require(cancelGameStatuses[_status] != _isSupported, "Already set to that value");
        cancelGameStatuses[_status] = _isSupported;
        emit SupportedCancelStatusChanged(_status, _isSupported);
    }

    /// @notice sets if sport is two positional (Example: NBA)
    /// @param _sportId sport ID which is two positional
    /// @param _isTwoPosition true/false (two positional sport or not)
    function setTwoPositionSport(uint _sportId, bool _isTwoPosition) external onlyOwner {
        require(supportedSport[_sportId], "Sport must be supported");
        require(twoPositionSport[_sportId] != _isTwoPosition, "Already set to that value");
        twoPositionSport[_sportId] = _isTwoPosition;
        emit TwoPositionSportChanged(_sportId, _isTwoPosition);
    }

    /// @notice sets manager for market creation
    /// @param _sportsManager sport manager address
    function setSportsManager(address _sportsManager) external onlyOwner {
        require(_sportsManager != address(0), "Invalid address");
        sportsManager = ISportPositionalMarketManager(_sportsManager);
        emit NewSportsMarketManager(_sportsManager);
    }

    /// @notice sets wrapper address
    /// @param _wrapperAddress wrapper address
    function setWrapperAddress(address _wrapperAddress) external onlyOwner {
        require(_wrapperAddress != address(0), "Invalid address");
        wrapperAddress = _wrapperAddress;
        emit NewWrapperAddress(_wrapperAddress);
    }

    /// @notice sets queue address
    /// @param _queues queue address
    function setQueueAddress(GamesQueue _queues) external onlyOwner {
        require(address(_queues) != address(0), "Invalid address");
        queues = _queues;
        emit NewQueueAddress(_queues);
    }

    /// @notice adding/removing whitelist address depending on a flag
    /// @param _whitelistAddress address that needed to be whitelisted/ ore removed from WL
    /// @param _flag adding or removing from whitelist (true: add, false: remove)
    function addToWhitelist(address _whitelistAddress, bool _flag) external onlyOwner {
        require(_whitelistAddress != address(0), "Invalid address");
        require(whitelistedAddresses[_whitelistAddress] != _flag, "Already set to that flag");
        whitelistedAddresses[_whitelistAddress] = _flag;
        emit AddedIntoWhitelist(_whitelistAddress, _flag);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyWrapper() {
        require(msg.sender == wrapperAddress, "Only wrapper can call this function");
        _;
    }

    modifier isAddressWhitelisted() {
        require(whitelistedAddresses[msg.sender], "Address not supported");
        _;
    }

    modifier canGameBeCanceled(bytes32 _gameId) {
        require(!isGameResolvedOrCanceled(_gameId), "Market resoved or canceled");
        require(marketPerGameId[_gameId] != address(0), "No market created for game");
        _;
    }

    modifier canGameBeResolved(
        bytes32 _gameId,
        uint _outcome,
        uint8 _homeScore,
        uint8 _awayScore
    ) {
        require(!isGameResolvedOrCanceled(_gameId), "Market resoved or canceled");
        require(marketPerGameId[_gameId] != address(0), "No market created for game");
        require(_isValidOutcomeForGame(_gameId, _outcome) && _isValidOutcomeWithResult(_outcome, _homeScore, _awayScore), "Bad result or outcome");
        _;
    }

    modifier canGameBePaused(address _market, bool _pause) {
        require(_market != address(0), "No market address");
        require(gameFulfilledCreated[gameIdPerMarket[_market]], "Game not existing");
        require(gameIdPerMarket[_market] != 0, "Market not existing");
        require(!isGameResolvedOrCanceled(gameIdPerMarket[_market]), "Market resoved or canceled");
        require(sportsManager.isMarketPaused(_market) != _pause, "Already paused/unpaused");
        _;
    }
    /* ========== EVENTS ========== */

    event GameCreated(
        bytes32 _requestId,
        uint _sportId,
        bytes32 _id,
        GameCreate _game,
        uint _queueIndex,
        uint[] _normalizedOdds
    );
    event GameResolved(bytes32 _requestId, uint _sportId, bytes32 _id, GameResolve _game, uint _queueIndex);
    event GameOddsAdded(bytes32 _requestId, bytes32 _id, GameOdds _game, uint[] _normalizedOdds);
    event CreateSportsMarket(address _marketAddress, bytes32 _id, GameCreate _game, uint[] _tags, uint[] _normalizedOdds);
    event ResolveSportsMarket(address _marketAddress, bytes32 _id, uint _outcome);
    event PauseSportsMarket(address _marketAddress, bool _pause);
    event CancelSportsMarket(address _marketAddress, bytes32 _id);
    event InvalidOddsForMarket(bytes32 _requestId, address _marketAddress, bytes32 _id, GameOdds _game);
    event SupportedSportsChanged(uint _sportId, bool _isSupported);
    event SupportedResolvedStatusChanged(uint _status, bool _isSupported);
    event SupportedCancelStatusChanged(uint _status, bool _isSupported);
    event TwoPositionSportChanged(uint _sportId, bool _isTwoPosition);
    event NewSportsMarketManager(address _sportsManager);
    event NewWrapperAddress(address _wrapperAddress);
    event NewQueueAddress(GamesQueue _queues);
    event AddedIntoWhitelist(address _whitelistAddress, bool _flag);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// internal
import "../../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../../utils/proxy/solidity-0.8.0/ProxyPausable.sol";

/// @title Storage for games (created or resolved), calculation for order-making bot processing
/// @author gruja
contract GamesQueue is Initializable, ProxyOwned, ProxyPausable {
    // create games queue
    mapping(uint => bytes32) public gamesCreateQueue;
    mapping(bytes32 => bool) public existingGamesInCreatedQueue;
    uint public firstCreated;
    uint public lastCreated;
    mapping(bytes32 => uint) public gameStartPerGameId;

    // resolve games queue
    bytes32[] public unproccessedGames;
    mapping(bytes32 => uint) public unproccessedGamesIndex;
    mapping(uint => bytes32) public gamesResolvedQueue;
    mapping(bytes32 => bool) public existingGamesInResolvedQueue;
    uint public firstResolved;
    uint public lastResolved;

    address public consumer;

    /// @notice public initialize proxy method
    /// @param _owner future owner of a contract
    function initialize(address _owner) public initializer {
        setOwner(_owner);
        firstCreated = 1;
        lastCreated = 0;
        firstResolved = 1;
        lastResolved = 0;
    }

    /// @notice putting game in a crated queue and fill up unprocessed games array
    /// @param data id of a game in byte32
    /// @param startTime game start time
    /// @param sportsId id of a sport (Example: NBA = 4 etc.)
    function enqueueGamesCreated(
        bytes32 data,
        uint startTime,
        uint sportsId
    ) public onlyConsumer {
        lastCreated += 1;
        gamesCreateQueue[lastCreated] = data;

        existingGamesInCreatedQueue[data] = true;
        unproccessedGames.push(data);
        unproccessedGamesIndex[data] = unproccessedGames.length - 1;
        gameStartPerGameId[data] = startTime;

        emit EnqueueGamesCreated(data, sportsId, lastCreated);
    }

    /// @notice removing first game in a queue from created queue
    /// @return data returns id of a game which is removed
    function dequeueGamesCreated() public onlyConsumer returns (bytes32 data) {
        require(lastCreated >= firstCreated, "No more elements in a queue");

        data = gamesCreateQueue[firstCreated];

        delete gamesCreateQueue[firstCreated];
        firstCreated += 1;

        emit DequeueGamesCreated(data, firstResolved - 1);
    }

    /// @notice putting game in a resolved queue
    /// @param data id of a game in byte32
    function enqueueGamesResolved(bytes32 data) public onlyConsumer {
        lastResolved += 1;
        gamesResolvedQueue[lastResolved] = data;
        existingGamesInResolvedQueue[data] = true;

        emit EnqueueGamesResolved(data, lastCreated);
    }

    /// @notice removing first game in a queue from resolved queue
    /// @return data returns id of a game which is removed
    function dequeueGamesResolved() public onlyConsumer returns (bytes32 data) {
        require(lastResolved >= firstResolved, "No more elements in a queue");

        data = gamesResolvedQueue[firstResolved];

        delete gamesResolvedQueue[firstResolved];
        firstResolved += 1;

        emit DequeueGamesResolved(data, firstResolved - 1);
    }

    /// @notice removing game from array of unprocessed games
    /// @param index index in array
    function removeItemUnproccessedGames(uint index) public onlyConsumer {
        require(index < unproccessedGames.length, "No such index in array");

        bytes32 dataProccessed = unproccessedGames[index];

        unproccessedGames[index] = unproccessedGames[unproccessedGames.length - 1];
        unproccessedGamesIndex[unproccessedGames[index]] = index;
        unproccessedGames.pop();

        emit GameProcessed(dataProccessed, index);
    }

    /// @notice public function which will return length of unprocessed array
    /// @return index index in array
    function getLengthUnproccessedGames() public view returns (uint) {
        return unproccessedGames.length;
    }

    /// @notice sets the consumer contract address, which only owner can execute
    /// @param _consumer address of a consumer contract
    function setConsumerAddress(address _consumer) external onlyOwner {
        require(_consumer != address(0), "Invalid address");
        consumer = _consumer;
        emit NewConsumerAddress(_consumer);
    }

    modifier onlyConsumer() {
        require(msg.sender == consumer, "Only consumer can call this function");
        _;
    }

    event EnqueueGamesCreated(bytes32 _gameId, uint _sportId, uint _index);
    event EnqueueGamesResolved(bytes32 _gameId, uint _index);
    event DequeueGamesCreated(bytes32 _gameId, uint _index);
    event DequeueGamesResolved(bytes32 _gameId, uint _index);
    event GameProcessed(bytes32 _gameId, uint _index);
    event NewConsumerAddress(address _consumer);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../interfaces/IExoticPositionalMarket.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";
import "../interfaces/IThalesBonds.sol";

contract ThalesOracleCouncil is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMath for uint;
    uint private constant COUNCIL_MAX_MEMBERS = 5;
    uint private constant VOTING_OPTIONS = 7;

    uint private constant ACCEPT_SLASH = 1;
    uint private constant ACCEPT_NO_SLASH = 2;
    uint private constant REFUSE_ON_POSITIONING = 3;
    uint private constant ACCEPT_RESULT = 4;
    uint private constant ACCEPT_RESET = 5;
    uint private constant REFUSE_MATURE = 6;

    uint private constant CREATOR_BOND = 101;
    uint private constant RESOLVER_BOND = 102;
    uint private constant DISPUTOR_BOND = 103;
    uint private constant CREATOR_AND_DISPUTOR = 104;
    uint private constant RESOLVER_AND_DISPUTOR = 105;

    uint private constant TEN_SUSD = 10 * 1e18;

    struct Dispute {
        address disputorAddress;
        string disputeString;
        uint disputeCode;
        uint disputeTimestamp;
        bool disputeInPositioningPhase;
    }

    IExoticPositionalMarketManager public marketManager;
    uint public councilMemberCount;
    mapping(uint => address) public councilMemberAddress;
    mapping(address => uint) public councilMemberIndex;
    mapping(address => uint) public marketTotalDisputes;
    mapping(address => uint) public marketLastClosedDispute;
    mapping(address => uint) public allOpenDisputesCancelledToIndexForMarket;
    mapping(address => uint) public marketOpenDisputesCount;
    mapping(address => bool) public marketClosedForDisputes;
    mapping(address => address) public firstMemberThatChoseWinningPosition;

    mapping(address => mapping(uint => Dispute)) public dispute;
    mapping(address => mapping(uint => uint[])) public disputeVote;
    mapping(address => mapping(uint => uint[VOTING_OPTIONS])) public disputeVotesCount;
    mapping(address => mapping(uint => uint)) public disputeWinningPositionChoosen;
    mapping(address => mapping(uint => mapping(address => uint))) public disputeWinningPositionChoosenByMember;
    mapping(address => mapping(uint => mapping(uint => uint))) public disputeWinningPositionVotes;

    function initialize(address _owner, address _marketManager) public initializer {
        setOwner(_owner);
        initNonReentrant();
        marketManager = IExoticPositionalMarketManager(_marketManager);
    }

    /* ========== VIEWS ========== */

    function canMarketBeDisputed(address _market) public view returns (bool) {
        return !marketClosedForDisputes[_market] && IExoticPositionalMarket(_market).isMarketCreated();
    }

    function getMarketOpenDisputes(address _market) external view returns (uint) {
        return marketOpenDisputesCount[_market];
    }

    function getMarketLastClosedDispute(address _market) external view returns (uint) {
        return marketLastClosedDispute[_market];
    }

    function getNumberOfCouncilMembersForMarketDispute(address _market, uint _index) external view returns (uint) {
        return disputeVote[_market][_index].length.sub(1);
    }

    function getVotesCountForMarketDispute(address _market, uint _index) public view returns (uint) {
        uint count = 0;
        for (uint i = 1; i < disputeVote[_market][_index].length; i++) {
            count += disputeVote[_market][_index][i] > 0 ? 1 : 0;
        }
        return count;
    }

    function getVotesMissingForMarketDispute(address _market, uint _index) external view returns (uint) {
        return disputeVote[_market][_index].length.sub(1).sub(getVotesCountForMarketDispute(_market, _index));
    }

    function getDispute(address _market, uint _index) external view returns (Dispute memory) {
        return dispute[_market][_index];
    }

    function getDisputeTimestamp(address _market, uint _index) external view returns (uint) {
        return dispute[_market][_index].disputeTimestamp;
    }

    function getDisputeAddressOfDisputor(address _market, uint _index) external view returns (address) {
        return dispute[_market][_index].disputorAddress;
    }

    function getDisputeString(address _market, uint _index) external view returns (string memory) {
        return dispute[_market][_index].disputeString;
    }

    function getDisputeCode(address _market, uint _index) external view returns (uint) {
        return dispute[_market][_index].disputeCode;
    }

    function getDisputeVotes(address _market, uint _index) external view returns (uint[] memory) {
        return disputeVote[_market][_index];
    }

    function getDisputeVoteOfCouncilMember(
        address _market,
        uint _index,
        address _councilMember
    ) external view returns (uint) {
        if (isOracleCouncilMember(_councilMember)) {
            return disputeVote[_market][_index][councilMemberIndex[_councilMember]];
        } else {
            require(isOracleCouncilMember(_councilMember), "Not OC");
            return 1e18;
        }
    }

    function isDisputeOpen(address _market, uint _index) external view returns (bool) {
        return dispute[_market][_index].disputeCode == 0;
    }

    function isDisputeCancelled(address _market, uint _index) external view returns (bool) {
        return
            dispute[_market][_index].disputeCode == REFUSE_ON_POSITIONING ||
            dispute[_market][_index].disputeCode == REFUSE_MATURE;
    }

    function isOpenDisputeCancelled(address _market, uint _disputeIndex) external view returns (bool) {
        return
            (marketClosedForDisputes[_market] || _disputeIndex <= allOpenDisputesCancelledToIndexForMarket[_market]) &&
            dispute[_market][_disputeIndex].disputeCode == 0 &&
            marketLastClosedDispute[_market] != _disputeIndex;
    }

    function canDisputorClaimbackBondFromUnclosedDispute(
        address _market,
        uint _disputeIndex,
        address _disputorAddress
    ) public view returns (bool) {
        if (
            marketManager.isActiveMarket(_market) &&
            _disputeIndex <= marketTotalDisputes[_market] &&
            (marketClosedForDisputes[_market] ||
                _disputeIndex <= allOpenDisputesCancelledToIndexForMarket[_market] ||
                marketManager.cancelledByCreator(_market)) &&
            dispute[_market][_disputeIndex].disputorAddress == _disputorAddress &&
            dispute[_market][_disputeIndex].disputeCode == 0 &&
            marketLastClosedDispute[_market] != _disputeIndex &&
            IThalesBonds(marketManager.thalesBonds()).getDisputorBondForMarket(_market, _disputorAddress) > 0
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isOracleCouncilMember(address _councilMember) public view returns (bool) {
        return (councilMemberIndex[_councilMember] > 0);
    }

    function isMarketClosedForDisputes(address _market) public view returns (bool) {
        return marketClosedForDisputes[_market] || IExoticPositionalMarket(_market).canUsersClaim();
    }

    function setMarketManager(address _marketManager) external onlyOwner {
        require(_marketManager != address(0), "Invalid address");
        marketManager = IExoticPositionalMarketManager(_marketManager);
        emit NewMarketManager(_marketManager);
    }

    function addOracleCouncilMember(address _councilMember) external onlyOwner {
        require(_councilMember != address(0), "Invalid address.");
        require(councilMemberCount <= marketManager.maxOracleCouncilMembers(), "OC members exceeded");
        require(!isOracleCouncilMember(_councilMember), "Already OC");
        councilMemberCount = councilMemberCount.add(1);
        councilMemberAddress[councilMemberCount] = _councilMember;
        councilMemberIndex[_councilMember] = councilMemberCount;
        marketManager.addPauserAddress(_councilMember);
        emit NewOracleCouncilMember(_councilMember, councilMemberCount);
    }

    function removeOracleCouncilMember(address _councilMember) external onlyOwner {
        require(isOracleCouncilMember(_councilMember), "Not OC");
        councilMemberAddress[councilMemberIndex[_councilMember]] = councilMemberAddress[councilMemberCount];
        councilMemberIndex[councilMemberAddress[councilMemberCount]] = councilMemberIndex[_councilMember];
        councilMemberCount = councilMemberCount.sub(1);
        councilMemberIndex[_councilMember] = 0;
        marketManager.removePauserAddress(_councilMember);
        emit OracleCouncilMemberRemoved(_councilMember, councilMemberCount);
    }

    function openDispute(address _market, string memory _disputeString) external whenNotPaused {
        require(marketManager.isActiveMarket(_market), "Not Active");
        require(!isMarketClosedForDisputes(_market), "Closed for disputes");
        require(marketManager.creatorAddress(_market) != msg.sender, "Creator can not dispute");
        require(!isOracleCouncilMember(msg.sender), "OC can not dispute.");
        require(
            IERC20(marketManager.paymentToken()).balanceOf(msg.sender) >= IExoticPositionalMarket(_market).disputePrice(),
            "Low amount for dispute"
        );
        require(
            IERC20(marketManager.paymentToken()).allowance(msg.sender, marketManager.thalesBonds()) >=
                IExoticPositionalMarket(_market).disputePrice(),
            "No allowance."
        );
        require(keccak256(abi.encode(_disputeString)) != keccak256(abi.encode("")), "Invalid dispute string");
        require(
            bytes(_disputeString).length < marketManager.disputeStringLengthLimit() || bytes(_disputeString).length < 110,
            "String exceeds length"
        );

        marketTotalDisputes[_market] = marketTotalDisputes[_market].add(1);
        marketOpenDisputesCount[_market] = marketOpenDisputesCount[_market].add(1);
        dispute[_market][marketTotalDisputes[_market]].disputorAddress = msg.sender;
        dispute[_market][marketTotalDisputes[_market]].disputeString = _disputeString;
        dispute[_market][marketTotalDisputes[_market]].disputeTimestamp = block.timestamp;
        disputeVote[_market][marketTotalDisputes[_market]] = new uint[](councilMemberCount + 1);
        if (!IExoticPositionalMarket(_market).resolved()) {
            dispute[_market][marketTotalDisputes[_market]].disputeInPositioningPhase = true;
        }
        marketManager.disputeMarket(_market, msg.sender);
        emit NewDispute(
            _market,
            _disputeString,
            dispute[_market][marketTotalDisputes[_market]].disputeInPositioningPhase,
            msg.sender
        );
    }

    function voteForDispute(
        address _market,
        uint _disputeIndex,
        uint _disputeCodeVote,
        uint _winningPosition
    ) external onlyCouncilMembers {
        require(marketManager.isActiveMarket(_market), "Not active market.");
        require(!isMarketClosedForDisputes(_market), "Closed for disputes.");
        require(_disputeIndex > 0, "Dispute non existent");
        require(dispute[_market][_disputeIndex].disputeCode == 0, "Dispute closed.");
        require(_disputeCodeVote <= VOTING_OPTIONS && _disputeCodeVote > 0, "Invalid dispute code.");
        if (dispute[_market][_disputeIndex].disputeInPositioningPhase) {
            require(_disputeCodeVote < ACCEPT_RESULT, "Invalid code.");
        } else {
            require(_disputeCodeVote >= ACCEPT_RESULT, "Invalid code in maturity");
            require(_disputeIndex > allOpenDisputesCancelledToIndexForMarket[_market], "Already cancelled");
        }
        if (_winningPosition > 0 && _disputeCodeVote == ACCEPT_RESULT) {
            require(
                _winningPosition != IExoticPositionalMarket(_market).winningPosition(),
                "OC can not vote for the resolved position"
            );
            require(
                disputeWinningPositionChoosenByMember[_market][_disputeIndex][msg.sender] != _winningPosition,
                "Same winning position"
            );
            if (disputeWinningPositionChoosenByMember[_market][_disputeIndex][msg.sender] == 0) {
                disputeWinningPositionChoosenByMember[_market][_disputeIndex][msg.sender] = _winningPosition;
                disputeWinningPositionVotes[_market][_disputeIndex][_winningPosition] = disputeWinningPositionVotes[_market][
                    _disputeIndex
                ][_winningPosition]
                    .add(1);
            } else {
                disputeWinningPositionVotes[_market][_disputeIndex][
                    disputeWinningPositionChoosenByMember[_market][_disputeIndex][msg.sender]
                ] = disputeWinningPositionVotes[_market][_disputeIndex][
                    disputeWinningPositionChoosenByMember[_market][_disputeIndex][msg.sender]
                ]
                    .sub(1);
                disputeWinningPositionChoosenByMember[_market][_disputeIndex][msg.sender] = _winningPosition;
                disputeWinningPositionVotes[_market][_disputeIndex][_winningPosition] = disputeWinningPositionVotes[_market][
                    _disputeIndex
                ][_winningPosition]
                    .add(1);
            }
        }

        // check if already has voted for another option, and revert the vote
        if (disputeVote[_market][_disputeIndex][councilMemberIndex[msg.sender]] > 0) {
            disputeVotesCount[_market][_disputeIndex][
                disputeVote[_market][_disputeIndex][councilMemberIndex[msg.sender]]
            ] = disputeVotesCount[_market][_disputeIndex][
                disputeVote[_market][_disputeIndex][councilMemberIndex[msg.sender]]
            ]
                .sub(1);
        }

        // record the voting option
        disputeVote[_market][_disputeIndex][councilMemberIndex[msg.sender]] = _disputeCodeVote;
        disputeVotesCount[_market][_disputeIndex][_disputeCodeVote] = disputeVotesCount[_market][_disputeIndex][
            _disputeCodeVote
        ]
            .add(1);

        emit VotedAddedForDispute(_market, _disputeIndex, _disputeCodeVote, _winningPosition, msg.sender);

        if (disputeVotesCount[_market][_disputeIndex][_disputeCodeVote] > (councilMemberCount.div(2))) {
            if (_disputeCodeVote == ACCEPT_RESULT) {
                (uint maxVotesForPosition, uint chosenPosition) =
                    calculateWinningPositionBasedOnVotes(_market, _disputeIndex);
                if (maxVotesForPosition > (councilMemberCount.div(2))) {
                    disputeWinningPositionChoosen[_market][_disputeIndex] = chosenPosition;
                    closeDispute(_market, _disputeIndex, _disputeCodeVote);
                }
            } else {
                closeDispute(_market, _disputeIndex, _disputeCodeVote);
            }
        }
    }

    function closeDispute(
        address _market,
        uint _disputeIndex,
        uint _decidedOption
    ) internal nonReentrant {
        require(dispute[_market][_disputeIndex].disputeCode == 0, "Already closed");
        require(_decidedOption > 0, "Invalid option");
        dispute[_market][_disputeIndex].disputeCode = _decidedOption;
        marketOpenDisputesCount[_market] = marketOpenDisputesCount[_market] > 0
            ? marketOpenDisputesCount[_market].sub(1)
            : 0;
        if (_decidedOption == REFUSE_ON_POSITIONING || _decidedOption == REFUSE_MATURE) {
            // set dispute to false
            // send disputor BOND to SafeBox
            // marketManager.getMarketBondAmount(_market);
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                marketManager.safeBoxAddress(),
                IExoticPositionalMarket(_market).disputePrice(),
                DISPUTOR_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );
            marketLastClosedDispute[_market] = _disputeIndex;
            //if it is the last dispute
            if (_decidedOption == REFUSE_MATURE) {
                marketManager.setBackstopTimeout(_market);
            }
            if (marketOpenDisputesCount[_market] == 0) {
                marketManager.closeDispute(_market);
            }
            emit DisputeClosed(_market, _disputeIndex, _decidedOption);
        } else if (_decidedOption == ACCEPT_SLASH) {
            // 4 hours
            marketManager.setBackstopTimeout(_market);
            // close dispute flag
            marketManager.closeDispute(_market);
            // cancel market
            marketManager.cancelMarket(_market);
            marketClosedForDisputes[_market] = true;
            // send bond to disputor and safeBox
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                marketManager.safeBoxAddress(),
                IExoticPositionalMarket(_market).safeBoxLowAmount(),
                CREATOR_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                dispute[_market][_disputeIndex].disputorAddress,
                (IExoticPositionalMarket(_market).fixedBondAmount().add(IExoticPositionalMarket(_market).disputePrice()))
                    .sub(IExoticPositionalMarket(_market).safeBoxLowAmount()),
                CREATOR_AND_DISPUTOR,
                dispute[_market][_disputeIndex].disputorAddress
            );

            marketLastClosedDispute[_market] = _disputeIndex;
            emit MarketClosedForDisputes(_market, _decidedOption);
            emit DisputeClosed(_market, _disputeIndex, _decidedOption);
        } else if (_decidedOption == ACCEPT_NO_SLASH) {
            marketManager.setBackstopTimeout(_market);
            marketManager.closeDispute(_market);
            marketManager.cancelMarket(_market);
            marketClosedForDisputes[_market] = true;
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                marketManager.creatorAddress(_market),
                IExoticPositionalMarket(_market).fixedBondAmount(),
                CREATOR_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                dispute[_market][_disputeIndex].disputorAddress,
                IExoticPositionalMarket(_market).disputePrice(),
                DISPUTOR_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );
            marketManager.sendRewardToDisputor(
                _market,
                dispute[_market][_disputeIndex].disputorAddress,
                IExoticPositionalMarket(_market).arbitraryRewardForDisputor()
            );

            marketLastClosedDispute[_market] = _disputeIndex;
            emit MarketClosedForDisputes(_market, _decidedOption);
            emit DisputeClosed(_market, _disputeIndex, _decidedOption);
        } else if (_decidedOption == ACCEPT_RESULT) {
            marketManager.setBackstopTimeout(_market);
            marketManager.closeDispute(_market);
            marketManager.resolveMarket(_market, disputeWinningPositionChoosen[_market][_disputeIndex]);
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                marketManager.safeBoxAddress(),
                IExoticPositionalMarket(_market).fixedBondAmount(),
                RESOLVER_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                dispute[_market][_disputeIndex].disputorAddress,
                IExoticPositionalMarket(_market).disputePrice(),
                DISPUTOR_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );

            marketClosedForDisputes[_market] = true;
            marketLastClosedDispute[_market] = _disputeIndex;
            emit MarketClosedForDisputes(_market, _decidedOption);
            emit DisputeClosed(_market, _disputeIndex, _decidedOption);
        } else if (_decidedOption == ACCEPT_RESET) {
            marketManager.closeDispute(_market);
            marketManager.resetMarket(_market);
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                marketManager.safeBoxAddress(),
                IExoticPositionalMarket(_market).safeBoxLowAmount(),
                RESOLVER_BOND,
                dispute[_market][_disputeIndex].disputorAddress
            );
            IThalesBonds(marketManager.thalesBonds()).sendBondFromMarketToUser(
                _market,
                dispute[_market][_disputeIndex].disputorAddress,
                IExoticPositionalMarket(_market).fixedBondAmount().add(IExoticPositionalMarket(_market).disputePrice()).sub(
                    IExoticPositionalMarket(_market).safeBoxLowAmount()
                ),
                RESOLVER_AND_DISPUTOR,
                dispute[_market][_disputeIndex].disputorAddress
            );
            allOpenDisputesCancelledToIndexForMarket[_market] = marketTotalDisputes[_market];
            marketOpenDisputesCount[_market] = 0;
            marketLastClosedDispute[_market] = _disputeIndex;
            emit DisputeClosed(_market, _disputeIndex, _decidedOption);
        } else {
            // (CANCEL)
        }
    }

    function claimUnclosedDisputeBonds(address _market, uint _disputeIndex) external whenNotPaused {
        require(canDisputorClaimbackBondFromUnclosedDispute(_market, _disputeIndex, msg.sender), "Unable to claim.");

        if (marketManager.cancelledByCreator(_market)) {
            marketOpenDisputesCount[_market] = 0;
            marketLastClosedDispute[_market] = _disputeIndex;
            emit DisputeClosed(_market, _disputeIndex, REFUSE_MATURE);
        }
        IThalesBonds(marketManager.thalesBonds()).sendOpenDisputeBondFromMarketToDisputor(
            _market,
            msg.sender,
            IThalesBonds(marketManager.thalesBonds()).getDisputorBondForMarket(_market, msg.sender)
        );
    }

    function calculateWinningPositionBasedOnVotes(address _market, uint _disputeIndex) internal view returns (uint, uint) {
        uint maxVotes;
        uint position;
        for (uint i = 0; i <= IExoticPositionalMarket(_market).positionCount(); i++) {
            if (disputeWinningPositionVotes[_market][_disputeIndex][i] > maxVotes) {
                maxVotes = disputeWinningPositionVotes[_market][_disputeIndex][i];
                position = i;
            }
        }

        return (maxVotes, position);
    }

    function closeMarketForDisputes(address _market) external {
        require(msg.sender == owner || msg.sender == address(marketManager), "Only manager/owner");
        require(!marketClosedForDisputes[_market], "Closed already");
        marketClosedForDisputes[_market] = true;
        emit MarketClosedForDisputes(_market, 0);
    }

    function reopenMarketForDisputes(address _market) external onlyOwner {
        require(marketClosedForDisputes[_market], "Open already");
        marketClosedForDisputes[_market] = false;
        emit MarketReopenedForDisputes(_market);
    }

    modifier onlyCouncilMembers() {
        require(isOracleCouncilMember(msg.sender), "Not OC");
        _;
    }
    event NewOracleCouncilMember(address councilMember, uint councilMemberCount);
    event OracleCouncilMemberRemoved(address councilMember, uint councilMemberCount);
    event NewMarketManager(address marketManager);
    event NewDispute(address market, string disputeString, bool disputeInPositioningPhase, address disputorAccount);
    event VotedAddedForDispute(address market, uint disputeIndex, uint disputeCodeVote, uint winningPosition, address voter);
    event MarketClosedForDisputes(address market, uint disputeFinalCode);
    event MarketReopenedForDisputes(address market);
    event DisputeClosed(address market, uint disputeIndex, uint decidedOption);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IExoticPositionalMarket {
    /* ========== VIEWS / VARIABLES ========== */
    function isMarketCreated() external view returns (bool);
    function creatorAddress() external view returns (address);
    function resolverAddress() external view returns (address);
    function totalBondAmount() external view returns(uint);

    function marketQuestion() external view returns(string memory);
    function marketSource() external view returns(string memory);
    function positionPhrase(uint index) external view returns(string memory);

    function getTicketType() external view returns(uint);
    function positionCount() external view returns(uint);
    function endOfPositioning() external view returns(uint);
    function resolvedTime() external view returns(uint);
    function fixedTicketPrice() external view returns(uint);
    function creationTime() external view returns(uint);
    function winningPosition() external view returns(uint);
    function getTags() external view returns(uint[] memory);
    function getTotalPlacedAmount() external view returns(uint);
    function getTotalClaimableAmount() external view returns(uint);
    function getPlacedAmountPerPosition(uint index) external view returns(uint);
    function fixedBondAmount() external view returns(uint);
    function disputePrice() external view returns(uint);
    function safeBoxLowAmount() external view returns(uint);
    function arbitraryRewardForDisputor() external view returns(uint);
    function backstopTimeout() external view returns(uint);
    function disputeClosedTime() external view returns(uint);
    function totalUsersTakenPositions() external view returns(uint);
    
    function withdrawalAllowed() external view returns(bool);
    function disputed() external view returns(bool);
    function resolved() external view returns(bool);
    function canUsersPlacePosition() external view returns (bool);
    function canMarketBeResolvedByPDAO() external view returns(bool);
    function canMarketBeResolved() external view returns (bool);
    function canUsersClaim() external view returns (bool);
    function isMarketCancelled() external view returns (bool);
    function paused() external view returns (bool);
    function canCreatorCancelMarket() external view returns (bool);
    function getAllFees() external view returns (uint, uint, uint, uint);
    function canIssueFees() external view returns (bool);
    function noWinners() external view returns (bool);


    function transferBondToMarket(address _sender, uint _amount) external;
    function resolveMarket(uint _outcomePosition, address _resolverAddress) external;
    function cancelMarket() external;
    function resetMarket() external;
    function claimWinningTicketOnBehalf(address _user) external;
    function openDispute() external;
    function closeDispute() external;
    function setBackstopTimeout(uint _timeoutPeriod) external;


}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IExoticPositionalMarketManager {
    /* ========== VIEWS / VARIABLES ========== */
    function paused() external view returns (bool);
    function getActiveMarketAddress(uint _index) external view returns(address);
    function getActiveMarketIndex(address _marketAddress) external view returns(uint);
    function isActiveMarket(address _marketAddress) external view returns(bool);
    function numberOfActiveMarkets() external view returns(uint);
    function getMarketBondAmount(address _market) external view returns (uint);
    function maximumPositionsAllowed() external view returns(uint);
    function paymentToken() external view returns(address);
    function owner() external view returns(address);
    function thalesBonds() external view returns(address);
    function oracleCouncilAddress() external view returns(address);
    function safeBoxAddress() external view returns(address);
    function creatorAddress(address _market) external view returns(address);
    function resolverAddress(address _market) external view returns(address);
    function isPauserAddress(address _pauserAddress) external view returns(bool);
    function safeBoxPercentage() external view returns(uint);
    function creatorPercentage() external view returns(uint);
    function resolverPercentage() external view returns(uint);
    function withdrawalPercentage() external view returns(uint);
    function pDAOResolveTimePeriod() external view returns(uint);
    function claimTimeoutDefaultPeriod() external view returns(uint);
    function maxOracleCouncilMembers() external view returns(uint);
    function fixedBondAmount() external view returns(uint);
    function disputePrice() external view returns(uint);
    function safeBoxLowAmount() external view returns(uint);
    function arbitraryRewardForDisputor() external view returns(uint);
    function disputeStringLengthLimit() external view returns(uint);
    function cancelledByCreator(address _market) external view returns(bool);
    function withdrawalTimePeriod() external view returns(uint);    
    function maxAmountForOpenBidPosition() external view returns(uint);    
    function maxFinalWithdrawPercentage() external view returns(uint);    
    function minFixedTicketPrice() external view returns(uint);    

    function createExoticMarket(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        uint _positionCount,
        string[] memory _positionPhrases
    ) external;
    
    function createCLMarket(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        uint _positionCount,
        uint[] memory _positionsOfCreator,
        string[] memory _positionPhrases
    ) external;
    
    function disputeMarket(address _marketAddress, address disputor) external;
    function resolveMarket(address _marketAddress, uint _outcomePosition) external;
    function resetMarket(address _marketAddress) external;
    function cancelMarket(address _market) external ;
    function closeDispute(address _market) external ;
    function setBackstopTimeout(address _market) external; 
    function sendMarketBondAmountTo(address _market, address _recepient, uint _amount) external;
    function addPauserAddress(address _pauserAddress) external;
    function removePauserAddress(address _pauserAddress) external;
    function sendRewardToDisputor(address _market, address _disputorAddress, uint amount) external;
    function issueBondsBackToCreatorAndResolver(address _marketAddress) external ;


}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IThalesBonds {
    /* ========== VIEWS / VARIABLES ========== */
    function getTotalDepositedBondAmountForMarket(address _market) external view returns(uint);
    function getClaimedBondAmountForMarket(address _market) external view returns(uint);
    function getClaimableBondAmountForMarket(address _market) external view returns(uint);
    function getDisputorBondForMarket(address _market, address _disputorAddress) external view returns (uint);
    function getCreatorBondForMarket(address _market) external view returns (uint);
    function getResolverBondForMarket(address _market) external view returns (uint);

    function sendCreatorBondToMarket(address _market, address _creatorAddress, uint _amount) external;
    function sendResolverBondToMarket(address _market, address _resolverAddress, uint _amount) external;
    function sendDisputorBondToMarket(address _market, address _disputorAddress, uint _amount) external;
    function sendBondFromMarketToUser(address _market, address _account, uint _amount, uint _bondToReduce, address _disputorAddress) external;
    function sendOpenDisputeBondFromMarketToDisputor(address _market, address _account, uint _amount) external;
    function setOracleCouncilAddress(address _oracleCouncilAddress) external;
    function setManagerAddress(address _managerAddress) external;
    function issueBondsBackToCreatorAndResolver(address _market) external;
    function transferToMarket(address _account, uint _amount) external;    
    function transferFromMarket(address _account, uint _amount) external;
    function transferCreatorToResolverBonds(address _market) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "./OraclePausable.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/utils/SafeERC20.sol";
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";
import "../interfaces/IThalesBonds.sol";

contract ExoticPositionalOpenBidMarket is Initializable, ProxyOwned, OraclePausable, ProxyReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    enum TicketType {FIXED_TICKET_PRICE, FLEXIBLE_BID}
    uint private constant HUNDRED = 100;
    uint private constant ONE_PERCENT = 1e16;
    uint private constant HUNDRED_PERCENT = 1e18;
    uint private constant CANCELED = 0;

    uint public creationTime;
    uint public resolvedTime;
    uint public lastDisputeTime;
    uint public positionCount;
    uint public endOfPositioning;
    uint public marketMaturity;
    uint public fixedTicketPrice;
    uint public backstopTimeout;
    uint public totalUsersTakenPositions;
    uint public totalOpenBidAmount;
    uint public claimableOpenBidAmount;
    uint public winningPosition;
    uint public disputeClosedTime;
    uint public fixedBondAmount;
    uint public disputePrice;
    uint public safeBoxLowAmount;
    uint public arbitraryRewardForDisputor;
    uint public withdrawalPeriod;
    uint public maxAmountForOpenBidPosition;
    uint public maxWithdrawPercentage;
    uint public minPosAmount;

    bool public noWinners;
    bool public disputed;
    bool public resolved;
    bool public disputedInPositioningPhase;
    bool public feesAndBondsClaimed;
    bool public withdrawalAllowed;

    address public resolverAddress;
    TicketType public ticketType;
    IExoticPositionalMarketManager public marketManager;
    IThalesBonds public thalesBonds;

    mapping(address => uint) public totalUserPlacedAmount;
    mapping(address => mapping(uint => uint)) public userOpenBidPosition;
    mapping(address => uint) public userAlreadyClaimed;
    mapping(uint => uint) public totalOpenBidAmountPerPosition;
    mapping(uint => string) public positionPhrase;
    mapping(address => bool) public withrawalRestrictedForUser;
    uint[] public tags;
    string public marketQuestion;
    string public marketSource;

    function initialize(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        uint _positionCount,
        string[] memory _positionPhrases
    ) external initializer {
        require(
            _positionCount >= 2 && _positionCount <= IExoticPositionalMarketManager(msg.sender).maximumPositionsAllowed(),
            "Invalid num pos"
        );
        require(_tags.length > 0);
        setOwner(msg.sender);
        marketManager = IExoticPositionalMarketManager(msg.sender);
        thalesBonds = IThalesBonds(marketManager.thalesBonds());
        _initializeWithTwoParameters(
            _marketQuestion,
            _marketSource,
            _endOfPositioning,
            _fixedTicketPrice,
            _withdrawalAllowed,
            _tags,
            _positionPhrases[0],
            _positionPhrases[1]
        );
        if (_positionCount > 2) {
            for (uint i = 2; i < _positionCount; i++) {
                _addPosition(_positionPhrases[i]);
            }
        }
        maxAmountForOpenBidPosition = marketManager.maxAmountForOpenBidPosition();
        maxWithdrawPercentage = marketManager.maxFinalWithdrawPercentage();
        fixedBondAmount = marketManager.fixedBondAmount();
        disputePrice = marketManager.disputePrice();
        safeBoxLowAmount = marketManager.safeBoxLowAmount();
        arbitraryRewardForDisputor = marketManager.arbitraryRewardForDisputor();
        withdrawalPeriod = _endOfPositioning.sub(marketManager.withdrawalTimePeriod());
        minPosAmount = marketManager.minFixedTicketPrice();
    }

    function takeCreatorInitialOpenBidPositions(uint[] memory _positions, uint[] memory _amounts) external onlyOwner {
        require(_positions.length > 0 && _positions.length <= positionCount, "Invalid posNum");
        require(ticketType == TicketType.FLEXIBLE_BID, "Not OpenBid");
        uint totalDepositedAmount = 0;
        address creatorAddress = marketManager.creatorAddress(address(this));
        for (uint i = 0; i < _positions.length; i++) {
            require(_positions[i] > 0, "Non-zero expected");
            require(_positions[i] <= positionCount, "Value invalid");
            require(
                _amounts[i] == 0 || (_amounts[i] >= minPosAmount && _amounts[i] <= maxAmountForOpenBidPosition),
                "Amounts exceed"
            );
            totalOpenBidAmountPerPosition[_positions[i]] = totalOpenBidAmountPerPosition[_positions[i]].add(_amounts[i]);
            userOpenBidPosition[creatorAddress][_positions[i]] = userOpenBidPosition[creatorAddress][_positions[i]].add(
                _amounts[i]
            );
            totalDepositedAmount = totalDepositedAmount.add(_amounts[i]);
        }
        require(
            totalUserPlacedAmount[creatorAddress].add(totalDepositedAmount) >= minPosAmount &&
                totalUserPlacedAmount[creatorAddress].add(totalDepositedAmount) <= maxAmountForOpenBidPosition,
            "Amounts exceed"
        );
        totalOpenBidAmount = totalOpenBidAmount.add(totalDepositedAmount);
        totalUserPlacedAmount[creatorAddress] = totalUserPlacedAmount[creatorAddress].add(totalDepositedAmount);
        totalUsersTakenPositions = totalUsersTakenPositions.add(1);
        transferToMarket(creatorAddress, totalDepositedAmount);
        emit NewOpenBidsForPositions(creatorAddress, _positions, _amounts);
    }

    function takeOpenBidPositions(uint[] memory _positions, uint[] memory _amounts) external notPaused nonReentrant {
        require(_positions.length > 0, "Invalid posNum");
        require(_positions.length <= positionCount, "Exceeds count");
        require(canUsersPlacePosition(), "Market resolved");
        require(ticketType == TicketType.FLEXIBLE_BID, "Not OpenBid");
        if (block.timestamp.add(1 days) > endOfPositioning) {
            if (totalUserPlacedAmount[msg.sender] > 0) {
                require(
                    totalUserPlacedAmount[msg.sender] <=
                        totalOpenBidAmount.mul(maxWithdrawPercentage.mul(ONE_PERCENT)).div(HUNDRED_PERCENT),
                    "Exceeds reposition"
                );
            }
        }
        uint totalDepositedAmount = 0;
        bool firstTime = true;
        for (uint i = 0; i < _positions.length; i++) {
            require(_positions[i] > 0, "Non-zero expected");
            require(_positions[i] <= positionCount, "Value invalid");
            require(
                _amounts[i] == 0 || (_amounts[i] >= minPosAmount && _amounts[i] <= maxAmountForOpenBidPosition),
                "Amounts exceed"
            );
            if (userOpenBidPosition[msg.sender][_positions[i]] > 0) {
                totalOpenBidAmountPerPosition[_positions[i]] = totalOpenBidAmountPerPosition[_positions[i]].sub(
                    userOpenBidPosition[msg.sender][_positions[i]]
                );
                firstTime = false;
            }
            totalOpenBidAmountPerPosition[_positions[i]] = totalOpenBidAmountPerPosition[_positions[i]].add(_amounts[i]);
            userOpenBidPosition[msg.sender][_positions[i]] = _amounts[i];
            totalDepositedAmount = totalDepositedAmount.add(_amounts[i]);
        }
        require(
            totalDepositedAmount >= minPosAmount && totalDepositedAmount >= totalUserPlacedAmount[msg.sender],
            "Bellow init amounts"
        );
        uint amountToBeAdded = totalDepositedAmount.sub(totalUserPlacedAmount[msg.sender]);
        require(amountToBeAdded <= maxAmountForOpenBidPosition, "Amounts exceed");
        if (amountToBeAdded > 0) {
            totalOpenBidAmount = totalOpenBidAmount.add(amountToBeAdded);
            totalUserPlacedAmount[msg.sender] = totalUserPlacedAmount[msg.sender].add(amountToBeAdded);
            totalUsersTakenPositions = firstTime ? totalUsersTakenPositions.add(1) : totalUsersTakenPositions;
            transferToMarket(msg.sender, amountToBeAdded);
        }
        emit NewOpenBidsForPositions(msg.sender, _positions, _amounts);
    }

    function withdraw(uint _openBidPosition) external notPaused nonReentrant {
        require(withdrawalAllowed, "Not allowed");
        require(canUsersPlacePosition(), "Market resolved");
        require(block.timestamp <= withdrawalPeriod, "Withdrawal expired");
        require(msg.sender != marketManager.creatorAddress(address(this)), "Creator forbidden");
        uint totalToWithdraw;
        if (_openBidPosition == 0) {
            for (uint i = 1; i <= positionCount; i++) {
                if (userOpenBidPosition[msg.sender][i] > 0) {
                    totalToWithdraw = totalToWithdraw.add(userOpenBidPosition[msg.sender][i]);
                    totalOpenBidAmountPerPosition[i] = totalOpenBidAmountPerPosition[i].sub(
                        userOpenBidPosition[msg.sender][i]
                    );
                    userOpenBidPosition[msg.sender][i] = 0;
                }
            }
        } else {
            require(userOpenBidPosition[msg.sender][_openBidPosition] > 0, "No amount for position");
            totalOpenBidAmountPerPosition[_openBidPosition] = totalOpenBidAmountPerPosition[_openBidPosition].sub(
                userOpenBidPosition[msg.sender][_openBidPosition]
            );
            totalToWithdraw = userOpenBidPosition[msg.sender][_openBidPosition];
            userOpenBidPosition[msg.sender][_openBidPosition] = 0;
        }
        if (block.timestamp.add(1 days) > endOfPositioning && block.timestamp <= endOfPositioning) {
            require(!withrawalRestrictedForUser[msg.sender], "Already withdrawn");
            require(
                totalToWithdraw <= totalOpenBidAmount.mul(maxWithdrawPercentage.mul(ONE_PERCENT)).div(HUNDRED_PERCENT),
                "Exceeds withdraw limit"
            );
            withrawalRestrictedForUser[msg.sender] = true;
        }
        if (getUserOpenBidTotalPlacedAmount(msg.sender) == 0) {
            totalUsersTakenPositions = totalUsersTakenPositions.sub(1);
        }
        totalOpenBidAmount = totalOpenBidAmount.sub(totalToWithdraw);
        totalUserPlacedAmount[msg.sender] = totalUserPlacedAmount[msg.sender].sub(totalToWithdraw);
        uint withdrawalFee = totalToWithdraw.mul(marketManager.withdrawalPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
        thalesBonds.transferFromMarket(marketManager.safeBoxAddress(), withdrawalFee.div(2));
        thalesBonds.transferFromMarket(marketManager.creatorAddress(address(this)), withdrawalFee.div(2));
        thalesBonds.transferFromMarket(msg.sender, totalToWithdraw.sub(withdrawalFee));
        emit OpenBidUserWithdrawn(msg.sender, _openBidPosition, totalToWithdraw.sub(withdrawalFee), totalOpenBidAmount);
    }

    function resolveMarket(uint _outcomePosition, address _resolverAddress) external onlyOwner {
        require(canMarketBeResolvedByOwner(), "Disputed/not matured");
        require(_outcomePosition <= positionCount, "Outcome exeeds positionNum");
        winningPosition = _outcomePosition;
        if (_outcomePosition == CANCELED) {
            claimableOpenBidAmount = totalOpenBidAmount;
            totalOpenBidAmountPerPosition[_outcomePosition] = totalOpenBidAmount;
        } else {
            claimableOpenBidAmount = getTotalClaimableAmount();
            if (totalOpenBidAmountPerPosition[_outcomePosition] == 0) {
                noWinners = true;
            } else {
                noWinners = false;
            }
        }
        resolved = true;
        resolvedTime = block.timestamp;
        resolverAddress = _resolverAddress;
        emit MarketResolved(_outcomePosition, _resolverAddress, noWinners);
    }

    function resetMarket() external onlyOwner {
        require(resolved, "Market is not resolved");
        if (winningPosition == CANCELED) {
            totalOpenBidAmountPerPosition[winningPosition] = 0;
        }
        winningPosition = 0;
        claimableOpenBidAmount = 0;
        resolved = false;
        noWinners = false;
        resolvedTime = 0;
        resolverAddress = marketManager.safeBoxAddress();
        emit MarketReset();
    }

    function cancelMarket() external onlyOwner {
        winningPosition = CANCELED;
        claimableOpenBidAmount = totalOpenBidAmount;
        totalOpenBidAmountPerPosition[winningPosition] = totalOpenBidAmount;
        resolved = true;
        resolvedTime = block.timestamp;
        resolverAddress = marketManager.safeBoxAddress();
        emit MarketResolved(CANCELED, msg.sender, noWinners);
    }

    function claimWinningTicket() external notPaused nonReentrant {
        require(canUsersClaim(), "Market not finalized");
        uint amount = getUserClaimableAmount(msg.sender);
        require(amount > 0, "Claimable amount is zero.");
        claimableOpenBidAmount = claimableOpenBidAmount.sub(amount);
        resetForUserAllPositionsToZero(msg.sender);
        thalesBonds.transferFromMarket(msg.sender, amount);
        if (!feesAndBondsClaimed) {
            _issueFees();
        }
        userAlreadyClaimed[msg.sender] = userAlreadyClaimed[msg.sender].add(amount);
        emit WinningOpenBidAmountClaimed(msg.sender, amount);
    }

    function claimWinningTicketOnBehalf(address _user) external onlyOwner {
        require(canUsersClaim() || marketManager.cancelledByCreator(address(this)), "Market not finalized");
        uint amount = getUserClaimableAmount(_user);
        require(amount > 0, "Claimable amount is zero.");
        claimableOpenBidAmount = claimableOpenBidAmount.sub(amount);
        resetForUserAllPositionsToZero(_user);
        thalesBonds.transferFromMarket(_user, amount);
        if (!feesAndBondsClaimed) {
            _issueFees();
        }
        userAlreadyClaimed[msg.sender] = userAlreadyClaimed[msg.sender].add(amount);
        emit WinningOpenBidAmountClaimed(_user, amount);
    }

    function issueFees() external notPaused nonReentrant {
        _issueFees();
    }

    function _issueFees() internal {
        require(canUsersClaim() || marketManager.cancelledByCreator(address(this)), "Not finalized");
        require(!feesAndBondsClaimed, "Fees claimed");
        if (winningPosition != CANCELED) {
            thalesBonds.transferFromMarket(marketManager.creatorAddress(address(this)), getAdditionalCreatorAmount());
            thalesBonds.transferFromMarket(resolverAddress, getAdditionalResolverAmount());
            thalesBonds.transferFromMarket(marketManager.safeBoxAddress(), getSafeBoxAmount());
        }
        marketManager.issueBondsBackToCreatorAndResolver(address(this));
        feesAndBondsClaimed = true;
        emit FeesIssued(getTotalFeesAmount());
    }

    function openDispute() external onlyOwner {
        require(isMarketCreated(), "Market not created");
        require(!disputed, "Market already disputed");
        disputed = true;
        disputedInPositioningPhase = canUsersPlacePosition();
        lastDisputeTime = block.timestamp;
        emit MarketDisputed(true);
    }

    function closeDispute() external onlyOwner {
        require(disputed, "Market not disputed");
        disputeClosedTime = block.timestamp;
        if (disputedInPositioningPhase) {
            disputed = false;
            disputedInPositioningPhase = false;
        } else {
            disputed = false;
        }
        emit MarketDisputed(false);
    }

    function transferToMarket(address _sender, uint _amount) internal notPaused {
        require(_sender != address(0), "Invalid sender address");
        require(IERC20(marketManager.paymentToken()).balanceOf(_sender) >= _amount, "Sender balance low");
        require(
            IERC20(marketManager.paymentToken()).allowance(_sender, marketManager.thalesBonds()) >= _amount,
            "No allowance."
        );
        IThalesBonds(marketManager.thalesBonds()).transferToMarket(_sender, _amount);
    }

    // SETTERS ///////////////////////////////////////////////////////

    function setBackstopTimeout(uint _timeoutPeriod) external onlyOwner {
        backstopTimeout = _timeoutPeriod;
        emit BackstopTimeoutPeriodChanged(_timeoutPeriod);
    }

    // VIEWS /////////////////////////////////////////////////////////

    function isMarketCreated() public view returns (bool) {
        return creationTime > 0;
    }

    function isMarketCancelled() public view returns (bool) {
        return resolved && winningPosition == CANCELED;
    }

    function canUsersPlacePosition() public view returns (bool) {
        return block.timestamp <= endOfPositioning && creationTime > 0 && !resolved;
    }

    function canMarketBeResolved() public view returns (bool) {
        return block.timestamp >= endOfPositioning && creationTime > 0 && (!disputed) && !resolved;
    }

    function canMarketBeResolvedByOwner() public view returns (bool) {
        return block.timestamp >= endOfPositioning && creationTime > 0 && (!disputed);
    }

    function canMarketBeResolvedByPDAO() public view returns (bool) {
        return
            canMarketBeResolvedByOwner() && block.timestamp >= endOfPositioning.add(marketManager.pDAOResolveTimePeriod());
    }

    function canCreatorCancelMarket() external view returns (bool) {
        if (disputed) {
            return false;
        } else if (totalUsersTakenPositions == 1) {
            return true;
        } else {
            return false;
            // return totalOpenBidAmount == getUserOpenBidTotalPlacedAmount(marketManager.creatorAddress(address(this)))
            //         ? true
            //         : false;
        }
    }

    function canUsersClaim() public view returns (bool) {
        return
            resolved &&
            (!disputed) &&
            ((resolvedTime > 0 && block.timestamp > resolvedTime.add(marketManager.claimTimeoutDefaultPeriod())) ||
                (backstopTimeout > 0 &&
                    resolvedTime > 0 &&
                    disputeClosedTime > 0 &&
                    block.timestamp > disputeClosedTime.add(backstopTimeout)));
    }

    function canUserClaim(address _user) external view returns (bool) {
        return canUsersClaim() && getUserClaimableAmount(_user) > 0;
    }

    function canUserWithdraw(address _account) public view returns (bool) {
        if (_account == marketManager.creatorAddress(address(this))) {
            return false;
        }
        return
            withdrawalAllowed &&
            canUsersPlacePosition() &&
            getUserOpenBidTotalPlacedAmount(_account) > 0 &&
            !withrawalRestrictedForUser[_account] &&
            block.timestamp <= withdrawalPeriod;
    }

    function canIssueFees() external view returns (bool) {
        return
            !feesAndBondsClaimed &&
            (thalesBonds.getCreatorBondForMarket(address(this)) > 0 ||
                thalesBonds.getResolverBondForMarket(address(this)) > 0);
    }

    function getPositionPhrase(uint index) public view returns (string memory) {
        return (index <= positionCount && index > 0) ? positionPhrase[index] : string("");
    }

    function getTotalPlacedAmount() public view returns (uint) {
        return totalOpenBidAmount;
    }

    function getTotalClaimableAmount() public view returns (uint) {
        if (totalUsersTakenPositions == 0) {
            return 0;
        } else {
            return winningPosition == CANCELED ? getTotalPlacedAmount() : applyDeduction(getTotalPlacedAmount());
        }
    }

    function getTotalFeesAmount() public view returns (uint) {
        return getTotalPlacedAmount().sub(getTotalClaimableAmount());
    }

    function getPlacedAmountPerPosition(uint _position) public view returns (uint) {
        return totalOpenBidAmountPerPosition[_position];
    }

    function getUserClaimableAmount(address _account) public view returns (uint) {
        return getUserOpenBidTotalClaimableAmount(_account);
    }

    /// FLEXIBLE BID FUNCTIONS

    function getUserOpenBidTotalPlacedAmount(address _account) public view returns (uint) {
        uint amount = 0;
        for (uint i = 1; i <= positionCount; i++) {
            amount = amount.add(userOpenBidPosition[_account][i]);
        }
        return amount;
    }

    function getUserOpenBidPositionPlacedAmount(address _account, uint _position) external view returns (uint) {
        return userOpenBidPosition[_account][_position];
    }

    function getAllUserPositions(address _account) external view returns (uint[] memory) {
        uint[] memory userAllPositions = new uint[](positionCount);
        if (positionCount == 0) {
            return userAllPositions;
        }
        for (uint i = 1; i <= positionCount; i++) {
            userAllPositions[i - 1] = userOpenBidPosition[_account][i];
        }
        return userAllPositions;
    }

    function getPotentialOpenBidWinningForAllPositions() external view returns (uint[] memory) {
        uint[] memory potentialWinning = new uint[](positionCount);
        if (totalUsersTakenPositions == 0 || totalOpenBidAmount == 0) {
            return potentialWinning;
        }
        for (uint i = 1; i <= positionCount; i++) {
            if (totalOpenBidAmountPerPosition[i] > 0) {
                potentialWinning[i - 1] = applyDeduction(totalOpenBidAmount).mul(HUNDRED_PERCENT).div(
                    totalOpenBidAmountPerPosition[i]
                );
            }
        }
        return potentialWinning;
    }

    function getUserOpenBidPotentialWinningForPosition(address _account, uint _position) public view returns (uint) {
        if (_position == CANCELED) {
            return getUserOpenBidTotalPlacedAmount(_account);
        }
        return
            totalOpenBidAmountPerPosition[_position] > 0
                ? userOpenBidPosition[_account][_position].mul(getTotalClaimableAmount()).div(
                    totalOpenBidAmountPerPosition[_position]
                )
                : 0;
    }

    function getUserOpenBidTotalClaimableAmount(address _account) public view returns (uint) {
        if (noWinners) {
            return applyDeduction(getUserOpenBidTotalPlacedAmount(_account));
        }
        return getUserOpenBidPotentialWinningForPosition(_account, winningPosition);
    }

    function getUserPotentialWinningAmountForAllPosition(address _account) external view returns (uint[] memory) {
        uint[] memory potentialWinning = new uint[](positionCount);
        for (uint i = 1; i <= positionCount; i++) {
            potentialWinning[i - 1] = getUserOpenBidPotentialWinningForPosition(_account, i);
        }
        return potentialWinning;
    }

    function applyDeduction(uint value) internal view returns (uint) {
        return
            (value)
                .mul(
                HUNDRED.sub(
                    marketManager.safeBoxPercentage().add(marketManager.creatorPercentage()).add(
                        marketManager.resolverPercentage()
                    )
                )
            )
                .mul(ONE_PERCENT)
                .div(HUNDRED_PERCENT);
    }

    function getTagsCount() external view returns (uint) {
        return tags.length;
    }

    function getTags() external view returns (uint[] memory) {
        return tags;
    }

    function getTicketType() external view returns (uint) {
        return uint(ticketType);
    }

    function getAllAmounts()
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint
        )
    {
        return (fixedBondAmount, disputePrice, safeBoxLowAmount, arbitraryRewardForDisputor);
    }

    function getAllFees()
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint
        )
    {
        return (getAdditionalCreatorAmount(), getAdditionalResolverAmount(), getSafeBoxAmount(), getTotalFeesAmount());
    }

    function resetForUserAllPositionsToZero(address _account) internal {
        if (positionCount > 0) {
            for (uint i = 1; i <= positionCount; i++) {
                userOpenBidPosition[_account][i] = 0;
            }
        }
    }

    function getAdditionalCreatorAmount() internal view returns (uint) {
        return getTotalPlacedAmount().mul(marketManager.creatorPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
    }

    function getAdditionalResolverAmount() internal view returns (uint) {
        return getTotalPlacedAmount().mul(marketManager.resolverPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
    }

    function getSafeBoxAmount() internal view returns (uint) {
        return getTotalPlacedAmount().mul(marketManager.safeBoxPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
    }

    function _initializeWithTwoParameters(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        string memory _positionPhrase1,
        string memory _positionPhrase2
    ) internal {
        creationTime = block.timestamp;
        marketQuestion = _marketQuestion;
        marketSource = _marketSource;
        endOfPositioning = _endOfPositioning;
        ticketType = _fixedTicketPrice > 0 ? TicketType.FIXED_TICKET_PRICE : TicketType.FLEXIBLE_BID;
        withdrawalAllowed = _withdrawalAllowed;
        tags = _tags;
        _addPosition(_positionPhrase1);
        _addPosition(_positionPhrase2);
    }

    function _addPosition(string memory _position) internal {
        require(keccak256(abi.encode(_position)) != keccak256(abi.encode("")), "Invalid position label (empty string)");
        positionCount = positionCount.add(1);
        positionPhrase[positionCount] = _position;
    }

    event MarketDisputed(bool disputed);
    event MarketCreated(uint creationTime, uint positionCount, bytes32 phrase);
    event MarketResolved(uint winningPosition, address resolverAddress, bool noWinner);
    event MarketReset();
    event WinningOpenBidAmountClaimed(address account, uint amount);
    event BackstopTimeoutPeriodChanged(uint timeoutPeriod);
    event TicketWithdrawn(address account, uint amount);
    event BondIncreased(uint amount, uint totalAmount);
    event BondDecreased(uint amount, uint totalAmount);
    event NewOpenBidsForPositions(address account, uint[] openBidPositions, uint[] openBidAmounts);
    event OpenBidUserWithdrawn(address account, uint position, uint withdrawnAmount, uint totalOpenBidAmount);
    event FeesIssued(uint totalFees);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";

// Clone of syntetix contract without constructor

contract OraclePausable is ProxyOwned {
    uint public lastPauseTime;
    bool public paused;

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external pauserOnly {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }
        if (paused) {
            require(msg.sender == IExoticPositionalMarketManager(owner).owner(), "Only Protocol DAO can unpause");
        }
        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(!IExoticPositionalMarketManager(owner).paused(), "Manager paused.");
        require(!paused, "Contract is paused");
        _;
    }

    modifier pauserOnly {
        require(
            IExoticPositionalMarketManager(owner).isPauserAddress(msg.sender) ||
                IExoticPositionalMarketManager(owner).owner() == msg.sender ||
                owner == msg.sender,
            "Non-pauser address"
        );
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";
import "../interfaces/IExoticPositionalMarket.sol";
import "../interfaces/IStakingThales.sol";

contract ThalesBonds is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IExoticPositionalMarketManager public marketManager;
    struct MarketBond {
        uint totalDepositedMarketBond;
        uint totalMarketBond;
        uint creatorBond;
        uint resolverBond;
        uint disputorsTotalBond;
        uint disputorsCount;
        mapping(address => uint) disputorBond;
    }

    mapping(address => MarketBond) public marketBond;
    mapping(address => uint) public marketFunds;

    uint private constant CREATOR_BOND = 101;
    uint private constant RESOLVER_BOND = 102;
    uint private constant DISPUTOR_BOND = 103;
    uint private constant CREATOR_AND_DISPUTOR = 104;
    uint private constant RESOLVER_AND_DISPUTOR = 105;

    IStakingThales public stakingThales;

    function initialize(address _owner) public initializer {
        setOwner(_owner);
        initNonReentrant();
    }

    function getTotalDepositedBondAmountForMarket(address _market) external view returns (uint) {
        return marketBond[_market].totalDepositedMarketBond;
    }

    function getClaimedBondAmountForMarket(address _market) external view returns (uint) {
        return marketBond[_market].totalDepositedMarketBond.sub(marketBond[_market].totalMarketBond);
    }

    function getClaimableBondAmountForMarket(address _market) external view returns (uint) {
        return marketBond[_market].totalMarketBond;
    }

    function getDisputorBondForMarket(address _market, address _disputorAddress) external view returns (uint) {
        return marketBond[_market].disputorBond[_disputorAddress];
    }

    function getCreatorBondForMarket(address _market) external view returns (uint) {
        return marketBond[_market].creatorBond;
    }

    function getResolverBondForMarket(address _market) external view returns (uint) {
        return marketBond[_market].resolverBond;
    }

    // different deposit functions to flag the bond amount : creator
    function sendCreatorBondToMarket(
        address _market,
        address _creatorAddress,
        uint _amount
    ) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(_amount > 0, "Bond zero");
        // no checks for active market, market creation not finalized
        marketBond[_market].creatorBond = _amount;
        marketBond[_market].totalMarketBond = marketBond[_market].totalMarketBond.add(_amount);
        marketBond[_market].totalDepositedMarketBond = marketBond[_market].totalDepositedMarketBond.add(_amount);
        transferToMarketBond(_creatorAddress, _amount);
        emit CreatorBondSent(_market, _creatorAddress, _amount);
    }

    // different deposit functions to flag the bond amount : resolver
    function sendResolverBondToMarket(
        address _market,
        address _resolverAddress,
        uint _amount
    ) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(_amount > 0, "Bond zero");
        require(marketManager.isActiveMarket(_market), "Invalid address");
        // in case the creator is the resolver, move the bond to the resolver
        marketBond[_market].resolverBond = _amount;
        marketBond[_market].totalMarketBond = marketBond[_market].totalMarketBond.add(_amount);
        marketBond[_market].totalDepositedMarketBond = marketBond[_market].totalDepositedMarketBond.add(_amount);
        transferToMarketBond(_resolverAddress, _amount);
        emit ResolverBondSent(_market, _resolverAddress, _amount);
    }

    // different deposit functions to flag the bond amount : disputor
    function sendDisputorBondToMarket(
        address _market,
        address _disputorAddress,
        uint _amount
    ) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(_amount > 0, "Bond zero");
        require(marketManager.isActiveMarket(_market), "Invalid address");

        // if it is first dispute for the disputor, the counter is increased
        if (marketBond[_market].disputorBond[_disputorAddress] == 0) {
            marketBond[_market].disputorsCount = marketBond[_market].disputorsCount.add(1);
        }
        marketBond[_market].disputorBond[_disputorAddress] = marketBond[_market].disputorBond[_disputorAddress].add(_amount);
        marketBond[_market].disputorsTotalBond = marketBond[_market].disputorsTotalBond.add(_amount);
        marketBond[_market].totalMarketBond = marketBond[_market].totalMarketBond.add(_amount);
        marketBond[_market].totalDepositedMarketBond = marketBond[_market].totalDepositedMarketBond.add(_amount);
        transferToMarketBond(_disputorAddress, _amount);
        emit DisputorBondSent(_market, _disputorAddress, _amount);
    }

    // universal claiming amount function to adapt for different scenarios, e.g. SafeBox
    function sendBondFromMarketToUser(
        address _market,
        address _account,
        uint _amount,
        uint _bondToReduce,
        address _disputorAddress
    ) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(marketManager.isActiveMarket(_market), "Invalid address");
        require(_amount <= marketBond[_market].totalMarketBond, "Exceeds bond");
        require(_bondToReduce >= CREATOR_BOND && _bondToReduce <= RESOLVER_AND_DISPUTOR, "Invalid bondToReduce");
        if (_bondToReduce == CREATOR_BOND && _amount <= marketBond[_market].creatorBond) {
            marketBond[_market].creatorBond = marketBond[_market].creatorBond.sub(_amount);
        } else if (_bondToReduce == RESOLVER_BOND && _amount <= marketBond[_market].resolverBond) {
            marketBond[_market].resolverBond = marketBond[_market].resolverBond.sub(_amount);
        } else if (
            _bondToReduce == DISPUTOR_BOND &&
            marketBond[_market].disputorBond[_disputorAddress] >= 0 &&
            _amount <= IExoticPositionalMarket(_market).disputePrice()
        ) {
            marketBond[_market].disputorBond[_disputorAddress] = marketBond[_market].disputorBond[_disputorAddress].sub(
                _amount
            );
            marketBond[_market].disputorsTotalBond = marketBond[_market].disputorsTotalBond.sub(_amount);
            marketBond[_market].disputorsCount = marketBond[_market].disputorBond[_disputorAddress] > 0
                ? marketBond[_market].disputorsCount
                : marketBond[_market].disputorsCount.sub(1);
        } else if (
            _bondToReduce == CREATOR_AND_DISPUTOR &&
            _amount <= marketBond[_market].creatorBond.add(IExoticPositionalMarket(_market).disputePrice()) &&
            _amount > marketBond[_market].creatorBond
        ) {
            marketBond[_market].disputorBond[_disputorAddress] = marketBond[_market].disputorBond[_disputorAddress].sub(
                _amount.sub(marketBond[_market].creatorBond)
            );
            marketBond[_market].disputorsTotalBond = marketBond[_market].disputorsTotalBond.sub(
                _amount.sub(marketBond[_market].creatorBond)
            );
            marketBond[_market].creatorBond = 0;
            marketBond[_market].disputorsCount = marketBond[_market].disputorBond[_disputorAddress] > 0
                ? marketBond[_market].disputorsCount
                : marketBond[_market].disputorsCount.sub(1);
        } else if (
            _bondToReduce == RESOLVER_AND_DISPUTOR &&
            _amount <= marketBond[_market].resolverBond.add(IExoticPositionalMarket(_market).disputePrice()) &&
            _amount > marketBond[_market].resolverBond
        ) {
            marketBond[_market].disputorBond[_disputorAddress] = marketBond[_market].disputorBond[_disputorAddress].sub(
                _amount.sub(marketBond[_market].resolverBond)
            );
            marketBond[_market].disputorsTotalBond = marketBond[_market].disputorsTotalBond.sub(
                _amount.sub(marketBond[_market].resolverBond)
            );
            marketBond[_market].resolverBond = 0;
            marketBond[_market].disputorsCount = marketBond[_market].disputorBond[_disputorAddress] > 0
                ? marketBond[_market].disputorsCount
                : marketBond[_market].disputorsCount.sub(1);
        }
        marketBond[_market].totalMarketBond = marketBond[_market].totalMarketBond.sub(_amount);
        transferBondFromMarket(_account, _amount);
        emit BondTransferredFromMarketBondToUser(_market, _account, _amount);
    }

    function sendOpenDisputeBondFromMarketToDisputor(
        address _market,
        address _account,
        uint _amount
    ) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(marketManager.isActiveMarket(_market), "Invalid address");
        require(
            _amount <= marketBond[_market].totalMarketBond && _amount <= marketBond[_market].disputorsTotalBond,
            "Exceeds bond"
        );
        require(
            marketBond[_market].disputorsCount > 0 && marketBond[_market].disputorBond[_account] >= _amount,
            "Already claimed"
        );
        marketBond[_market].totalMarketBond = marketBond[_market].totalMarketBond.sub(_amount);
        marketBond[_market].disputorBond[_account] = marketBond[_market].disputorBond[_account].sub(_amount);
        marketBond[_market].disputorsTotalBond = marketBond[_market].disputorsTotalBond.sub(_amount);
        marketBond[_market].disputorsCount = marketBond[_market].disputorBond[_account] > 0
            ? marketBond[_market].disputorsCount
            : marketBond[_market].disputorsCount.sub(1);
        transferBondFromMarket(_account, _amount);
        emit BondTransferredFromMarketBondToUser(_market, _account, _amount);
    }

    function issueBondsBackToCreatorAndResolver(address _market) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(marketManager.isActiveMarket(_market), "Invalid address");
        uint totalIssuedBack;
        if (marketBond[_market].totalMarketBond >= marketBond[_market].creatorBond.add(marketBond[_market].resolverBond)) {
            marketBond[_market].totalMarketBond = marketBond[_market].totalMarketBond.sub(
                marketBond[_market].creatorBond.add(marketBond[_market].resolverBond)
            );
            if (
                marketManager.creatorAddress(_market) != marketManager.resolverAddress(_market) &&
                marketBond[_market].creatorBond > 0
            ) {
                totalIssuedBack = marketBond[_market].creatorBond;
                marketBond[_market].creatorBond = 0;
                transferBondFromMarket(marketManager.creatorAddress(_market), totalIssuedBack);
                emit BondTransferredFromMarketBondToUser(_market, marketManager.creatorAddress(_market), totalIssuedBack);
            }
            if (marketBond[_market].resolverBond > 0) {
                totalIssuedBack = marketBond[_market].resolverBond;
                marketBond[_market].resolverBond = 0;
                transferBondFromMarket(marketManager.resolverAddress(_market), totalIssuedBack);
                emit BondTransferredFromMarketBondToUser(_market, marketManager.resolverAddress(_market), totalIssuedBack);
            }
        }
    }

    function transferCreatorToResolverBonds(address _market) external onlyOracleCouncilManagerAndOwner nonReentrant {
        require(marketManager.isActiveMarket(_market), "Invalid address");
        require(marketBond[_market].creatorBond > 0, "Creator bond 0");
        marketBond[_market].resolverBond = marketBond[_market].creatorBond;
        marketBond[_market].creatorBond = 0;
        emit BondTransferredFromCreatorToResolver(_market, marketBond[_market].resolverBond);
    }

    function transferToMarket(address _account, uint _amount) external whenNotPaused {
        require(marketManager.isActiveMarket(msg.sender), "Not active market.");
        marketFunds[msg.sender] = marketFunds[msg.sender].add(_amount);
        if (address(stakingThales) != address(0)) {
            stakingThales.updateVolume(_account, _amount);
        }
        transferToMarketBond(_account, _amount);
    }

    function transferFromMarket(address _account, uint _amount) external whenNotPaused {
        require(marketManager.isActiveMarket(msg.sender), "Not active market.");
        require(marketFunds[msg.sender] >= _amount, "Low funds.");
        marketFunds[msg.sender] = marketFunds[msg.sender].sub(_amount);
        transferBondFromMarket(_account, _amount);
    }

    function transferToMarketBond(address _account, uint _amount) internal whenNotPaused {
        IERC20Upgradeable(marketManager.paymentToken()).safeTransferFrom(_account, address(this), _amount);
    }

    function transferBondFromMarket(address _account, uint _amount) internal whenNotPaused {
        IERC20Upgradeable(marketManager.paymentToken()).safeTransfer(_account, _amount);
    }

    function setMarketManager(address _managerAddress) external onlyOwner {
        require(_managerAddress != address(0), "Invalid OC");
        marketManager = IExoticPositionalMarketManager(_managerAddress);
        emit NewManagerAddress(_managerAddress);
    }

    function setStakingThalesContract(address _stakingThales) external onlyOwner {
        require(_stakingThales != address(0), "Invalid address");
        stakingThales = IStakingThales(_stakingThales);
        emit NewStakingThalesAddress(_stakingThales);
    }

    modifier onlyOracleCouncilManagerAndOwner() {
        require(
            msg.sender == marketManager.oracleCouncilAddress() ||
                msg.sender == address(marketManager) ||
                msg.sender == owner,
            "Not OC/Manager/Owner"
        );
        require(address(marketManager) != address(0), "Invalid Manager");
        require(marketManager.oracleCouncilAddress() != address(0), "Invalid OC");
        _;
    }

    event CreatorBondSent(address market, address creator, uint amount);
    event ResolverBondSent(address market, address resolver, uint amount);
    event DisputorBondSent(address market, address disputor, uint amount);
    event BondTransferredFromMarketBondToUser(address market, address account, uint amount);
    event NewOracleCouncilAddress(address oracleCouncil);
    event NewManagerAddress(address managerAddress);
    event BondTransferredFromCreatorToResolver(address market, uint amount);
    event NewStakingThalesAddress(address stakingThales);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";
import "../interfaces/IExoticPositionalMarket.sol";

contract ExoticRewards is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IExoticPositionalMarketManager public marketManager;
    IERC20Upgradeable public paymentToken;
    mapping(address => uint) public marketIssuedReward;

    function initialize(address _owner, address _managerAddress) public initializer {
        setOwner(_owner);
        initNonReentrant();
        marketManager = IExoticPositionalMarketManager(_managerAddress);
    }

    function sendRewardToDisputoraddress(
        address _market,
        address _disputorAddress,
        uint _amount
    ) external onlyOracleCouncilManagerAndOwner {
        require(marketManager.isActiveMarket(_market), "Not active market.");
        require(
            _amount <= IERC20Upgradeable(marketManager.paymentToken()).balanceOf(address(this)),
            "Amount exceeds balance"
        );
        require(
            _amount > 0 && _amount <= IExoticPositionalMarket(_market).arbitraryRewardForDisputor(),
            "Zero or high amount"
        );
        require(_disputorAddress != address(0), "Invalid disputor");
        marketIssuedReward[_market] = marketIssuedReward[_market].add(_amount);
        IERC20Upgradeable(marketManager.paymentToken()).transfer(_disputorAddress, _amount);
        emit RewardIssued(_market, _disputorAddress, _amount);
    }

    function setMarketManager(address _managerAddress) external onlyOwner {
        require(_managerAddress != address(0), "Invalid Manager");
        marketManager = IExoticPositionalMarketManager(_managerAddress);
        emit NewManagerAddress(_managerAddress);
    }

    // function setPaymentToken(address _paymentToken) external onlyOwner {
    //     require(_paymentToken != address(0), "Invalid address");
    //     paymentToken = IERC20Upgradeable(_paymentToken);
    //     emit NewPaymentToken(_paymentToken);
    // }

    modifier onlyOracleCouncilManagerAndOwner() {
        require(
            msg.sender == marketManager.oracleCouncilAddress() ||
                msg.sender == address(marketManager) ||
                msg.sender == owner,
            "Not OC/Manager/Owner"
        );
        require(address(marketManager) != address(0), "Invalid Manager");
        require(marketManager.oracleCouncilAddress() != address(0), "Invalid OC");
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    event NewPaymentToken(address paymentTokenAddress);
    event NewManagerAddress(address managerAddress);
    event RewardIssued(address market, address disputorAddress, uint amount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";

contract VestingEscrowCC is Initializable, ProxyReentrancyGuard, ProxyOwned, ProxyPausable {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct LockedEntry {
        uint timestamp;
        uint amount;
    }

    address public token;
    mapping(address => uint) public startTime;
    mapping(address => uint) public endTime;
    mapping(address => uint) public initialLocked;
    mapping(address => uint) public totalClaimed;
    mapping(address => bool) public disabled;
    mapping(address => uint) public pausedAt;

    uint public initialLockedSupply;
    uint public vestingPeriod;
    address[] public recipients;

    function initialize(
        address _owner,
        address _token,
        uint _vestingPeriod
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        token = _token;
        vestingPeriod = _vestingPeriod;
    }

    function fund(
        address _recipient,
        uint _amount,
        uint _startTime
    ) external onlyOwner {
        require(_recipient != address(0), "Invalid address");

        if (initialLocked[_recipient] == 0) {
            recipients.push(_recipient);
            startTime[_recipient] = _startTime;
            endTime[_recipient] = _startTime + vestingPeriod;
        }
        initialLocked[_recipient] = initialLocked[_recipient] + _amount;

        initialLockedSupply = initialLockedSupply + _amount;

        emit Fund(_recipient, _amount);
    }

    function increaseAllocation(address _recipient, uint _amount) external onlyOwner {
        require(initialLocked[_recipient] > 0, "Invalid recipient");
        initialLocked[_recipient] = initialLocked[_recipient] + _amount;

        initialLockedSupply = initialLockedSupply + _amount;

        emit AllocationIncreased(_recipient, _amount);
    }

    function decreaseAllocation(address _recipient, uint _amount) external onlyOwner {
        require(initialLocked[_recipient] > 0, "Invalid recipient");
        require(initialLocked[_recipient] - balanceOf(_recipient) > _amount, "Invalid amount");
        initialLocked[_recipient] = initialLocked[_recipient] - _amount;

        initialLockedSupply = initialLockedSupply - _amount;

        emit AllocationDecreased(_recipient, _amount);
    }

    function _totalVestedOf(address _recipient, uint _time) internal view returns (uint) {
        uint start = startTime[_recipient];
        uint end = endTime[_recipient];
        uint locked = initialLocked[_recipient];

        if (_time < start) return 0;
        return MathUpgradeable.min(locked * (_time - start) / (end - start), locked);
    }

    function _totalVested() internal view returns (uint totalVested) {
        for (uint i = 0; i < recipients.length; i++) {
            totalVested += _totalVestedOf(recipients[i], block.timestamp);
        }
    }

    function vestedSupply() public view returns (uint) {
        return _totalVested();
    }

    function vestedOf(address _recipient) public view returns (uint) {
        return _totalVestedOf(_recipient, block.timestamp);
    }

    function lockedSupply() public view returns (uint) {
        return initialLockedSupply.sub(_totalVested());
    }

    function balanceOf(address _recipient) public view returns (uint) {
        return _totalVestedOf(_recipient, block.timestamp) - totalClaimed[_recipient];
    }

    function lockedOf(address _recipient) public view returns (uint) {
        return initialLocked[_recipient] - _totalVestedOf(_recipient, block.timestamp);
    }

    function claim() external nonReentrant notPaused {
        require(disabled[msg.sender] == false, "Account disabled");

        uint timestamp = pausedAt[msg.sender];
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        uint claimable = _totalVestedOf(msg.sender, timestamp) - totalClaimed[msg.sender];
        require(claimable > 0, "Nothing to claim");

        IERC20Upgradeable(token).safeTransfer(msg.sender, claimable);

        totalClaimed[msg.sender] = totalClaimed[msg.sender] + claimable;
        emit Claim(msg.sender, claimable);
    }

    function pauseClaim(address _recipient) external onlyOwner {
        pausedAt[_recipient] = block.timestamp;
        emit ClaimPaused(_recipient);
    }

    function unpauseClaim(address _recipient) external onlyOwner {
        pausedAt[_recipient] = 0;
        emit ClaimUnpaused(_recipient);
    }

    function disableClaim(address _recipient) external onlyOwner {
        disabled[_recipient] = true;
        emit ClaimDisabled(_recipient);
    }

    function enableClaim(address _recipient) external onlyOwner {
        disabled[_recipient] = false;
        emit ClaimEnabled(_recipient);
    }

    function changeWallet(address _oldAddress, address _newAddress) external onlyOwner {
        require(initialLocked[_oldAddress] > 0, "Invalid recipient");
        require(initialLocked[_newAddress] == 0, "Address is already a recipient");

        startTime[_newAddress] = startTime[_oldAddress];
        startTime[_oldAddress] = 0;

        endTime[_newAddress] = endTime[_oldAddress];
        endTime[_oldAddress] = 0;

        initialLocked[_newAddress] = initialLocked[_oldAddress];
        initialLocked[_oldAddress] = 0;

        totalClaimed[_newAddress] = totalClaimed[_oldAddress];
        totalClaimed[_oldAddress] = 0;

        emit WalletChanged(_oldAddress, _newAddress);
    }

    function setStartTime(address _recipient, uint _startTime) external onlyOwner {
        require(_startTime < endTime[_recipient], "End time must be greater than start time");
        startTime[_recipient] = _startTime;
        emit StartTimeChanged(_recipient, _startTime);
    }

    function setEndTime(address _recipient, uint _endTime) external onlyOwner {
        require(_endTime >= block.timestamp, "End time must be in future");
        endTime[_recipient] = _endTime;
        emit EndTimeChanged(_recipient, _endTime);
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid address");
        token = _token;
        emit TokenChanged(_token);
    }

    function setVestingPeriod(uint _vestingPeriod) external onlyOwner {
       vestingPeriod = _vestingPeriod;
       emit VestingPeriodChanged(_vestingPeriod);
    }

    event Fund(address _recipient, uint _amount);
    event AllocationIncreased(address _recipient, uint _amount);
    event AllocationDecreased(address _recipient, uint _amount);
    event Claim(address _address, uint _amount);
    event StartTimeChanged(address _recipient, uint _startTime);
    event EndTimeChanged(address _recipient, uint _endTime);
    event TokenChanged(address _token);
    event ClaimDisabled(address _recipient);
    event ClaimEnabled(address _recipient);
    event ClaimPaused(address _recipient);
    event ClaimUnpaused(address _recipient);
    event WalletChanged(address _oldAddress, address _newAddress);
    event VestingPeriodChanged(uint _vestingPeriod);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

contract ExoticPositionalTags is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;

    mapping(bytes32 => uint) public tagNumber;
    mapping(uint => string) public tagLabel;
    mapping(uint => uint) public tagNumberIndex;
    mapping(uint => uint) public tagIndexNumber;
    uint public tagsCount;

    function initialize(address _owner) public initializer {
        setOwner(_owner);
        initNonReentrant();
    }

    function isValidTagNumber(uint _number) public view returns (bool) {
        return _number > 0 && tagNumberIndex[_number] > 0;
    }

    function isValidTagLabel(string memory _label) public view returns (bool) {
        return
            keccak256(abi.encode(_label)) != keccak256(abi.encode("")) &&
            tagNumberIndex[tagNumber[keccak256(abi.encode(_label))]] > 0;
    }

    function isValidTag(string memory _label, uint _number) external view returns (bool) {
        return isValidTagNumber(_number) && isValidTagLabel(_label);
    }

    function getTagLabel(uint _number) external view returns (string memory) {
        return tagLabel[_number];
    }

    function getTagNumber(string memory _label) external view returns (uint) {
        return tagNumber[keccak256(abi.encode(_label))];
    }

    function getTagNumberIndex(uint _number) external view returns (uint) {
        return tagNumberIndex[_number];
    }

    function getTagIndexNumber(uint _index) external view returns (uint) {
        return tagIndexNumber[_index];
    }

    function getTagByIndex(uint _index) external view returns (string memory, uint) {
        return (tagLabel[tagIndexNumber[_index]], tagIndexNumber[_index]);
    }

    function getAllTags() external view returns (string[] memory, uint[] memory) {
        uint[] memory tagsNumber = new uint[](tagsCount);
        string[] memory tagsLabel = new string[](tagsCount);
        for (uint i = 1; i <= tagsCount; i++) {
            tagsNumber[i - 1] = tagIndexNumber[i];
            tagsLabel[i - 1] = tagLabel[tagIndexNumber[i]];
        }
        return (tagsLabel, tagsNumber);
    }

    function getAllTagsNumbers() external view returns (uint[] memory) {
        uint[] memory tagsNumber = new uint[](tagsCount);
        for (uint i = 1; i <= tagsCount; i++) {
            tagsNumber[i - 1] = tagIndexNumber[i];
        }
        return tagsNumber;
    }

    function getAllTagsLabels() external view returns (string[] memory) {
        string[] memory tagsLabel = new string[](tagsCount);
        for (uint i = 1; i <= tagsCount; i++) {
            tagsLabel[i - 1] = tagLabel[tagIndexNumber[i]];
        }
        return tagsLabel;
    }

    function getTagsCount() external view returns (uint) {
        return tagsCount;
    }

    function addTag(string memory _label, uint _number) external onlyOwner {
        require(_number > 0, "Number must not be zero");
        require(tagNumberIndex[_number] == 0, "Tag already exists");
        require(keccak256(abi.encode(_label)) != keccak256(abi.encode("")), "Invalid label (empty string)");
        require(bytes(_label).length < 50, "Tag label exceeds length");

        tagsCount = tagsCount.add(1);
        tagNumberIndex[_number] = tagsCount;
        tagIndexNumber[tagsCount] = _number;
        tagNumber[keccak256(abi.encode(_label))] = _number;
        tagLabel[_number] = _label;
        emit NewTagAdded(_label, _number);
    }

    function editTagNumber(string memory _label, uint _number) external onlyOwner {
        require(_number > 0, "Number must not be zero");
        require(keccak256(abi.encode(_label)) != keccak256(abi.encode("")), "Invalid label (empty string)");
        require(tagNumberIndex[_number] == 0, "New tag number already exists");
        require(tagNumberIndex[tagNumber[keccak256(abi.encode(_label))]] > 0, "Edited tag does not exist");
        if (tagNumber[keccak256(abi.encode(_label))] != _number) {
            uint old_number = tagNumber[keccak256(abi.encode(_label))];
            tagLabel[old_number] = "";
            tagNumberIndex[_number] = tagNumberIndex[old_number];
            tagIndexNumber[tagNumberIndex[_number]] = _number;
            tagNumberIndex[old_number] = 0;
            tagNumber[keccak256(abi.encode(_label))] = _number;
            tagLabel[_number] = _label;
            emit TagNumberChanged(_label, old_number, _number);
        }
    }

    function editTagLabel(string memory _label, uint _number) external onlyOwner {
        require(_number > 0, "Number must not be zero");
        require(keccak256(abi.encode(_label)) != keccak256(abi.encode("")), "Invalid label (empty string)");
        require(tagNumberIndex[_number] != 0, "Tag with number does not exists");
        if (keccak256(abi.encode(tagLabel[_number])) != keccak256(abi.encode(_label))) {
            string memory old_label = tagLabel[_number];
            tagNumber[keccak256(abi.encode(old_label))] = 0;
            tagNumber[keccak256(abi.encode(_label))] = _number;
            tagLabel[_number] = _label;
            emit TagLabelChanged(_number, old_label, _label);
        }
    }

    function removeTag(uint _number) external onlyOwner {
        require(_number > 0, "Number must not be zero");
        require(tagNumberIndex[_number] != 0, "Tag does not exists");
        if (tagNumberIndex[_number] > 0) {
            tagNumberIndex[tagIndexNumber[tagsCount]] = tagNumberIndex[_number];
            tagIndexNumber[tagNumberIndex[_number]] = tagIndexNumber[tagsCount];
            tagNumberIndex[_number] = 0;
            tagsCount = tagsCount.sub(1);
            emit TagRemoved(tagLabel[_number], _number);
            tagLabel[_number] = "";
        }
    }

    event NewTagAdded(string label, uint number);
    event TagNumberChanged(string label, uint old_number, uint number);
    event TagLabelChanged(uint number, string old_label, string label);
    event TagRemoved(string _label, uint _number);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-4.4.1/proxy/Clones.sol";
import "./ExoticPositionalFixedMarket.sol";
import "./ExoticPositionalOpenBidMarket.sol";
import "../interfaces/IThalesBonds.sol";
import "../interfaces/IExoticPositionalTags.sol";
import "../interfaces/IThalesOracleCouncil.sol";
import "../interfaces/IExoticPositionalMarket.sol";
import "../interfaces/IExoticRewards.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/libraries/AddressSetLib.sol";

contract ExoticPositionalMarketManager is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;
    using AddressSetLib for AddressSetLib.AddressSet;

    AddressSetLib.AddressSet private _activeMarkets;

    uint public fixedBondAmount;
    uint public backstopTimeout;
    uint public minimumPositioningDuration;
    uint public claimTimeoutDefaultPeriod;
    uint public pDAOResolveTimePeriod;
    uint public safeBoxPercentage;
    uint public creatorPercentage;
    uint public resolverPercentage;
    uint public withdrawalPercentage;
    uint public maximumPositionsAllowed;
    uint public disputePrice;
    uint public maxOracleCouncilMembers;
    uint public pausersCount;
    uint public maxNumberOfTags;
    uint public backstopTimeoutGeneral;
    uint public safeBoxLowAmount;
    uint public arbitraryRewardForDisputor;
    uint public minFixedTicketPrice;
    uint public disputeStringLengthLimit;
    uint public marketQuestionStringLimit;
    uint public marketSourceStringLimit;
    uint public marketPositionStringLimit;
    uint public withdrawalTimePeriod;
    bool public creationRestrictedToOwner;
    bool public openBidAllowed;

    address public exoticMarketMastercopy;
    address public oracleCouncilAddress;
    address public safeBoxAddress;
    address public thalesBonds;
    address public paymentToken;
    address public tagsAddress;
    address public theRundownConsumerAddress;
    address public marketDataAddress;
    address public exoticMarketOpenBidMastercopy;
    address public exoticRewards;

    mapping(uint => address) public pauserAddress;
    mapping(address => uint) public pauserIndex;

    mapping(address => address) public creatorAddress;
    mapping(address => address) public resolverAddress;
    mapping(address => bool) public isChainLinkMarket;
    mapping(address => bool) public cancelledByCreator;
    uint public maxAmountForOpenBidPosition;
    uint public maxFinalWithdrawPercentage;
    uint public maxFixedTicketPrice;

    function initialize(address _owner) public initializer {
        setOwner(_owner);
        initNonReentrant();
    }

    // Create Exotic market
    function createExoticMarket(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        uint _positionCount,
        uint[] memory _positionsOfCreator,
        string[] memory _positionPhrases
    ) external nonReentrant whenNotPaused {
        require(_endOfPositioning >= block.timestamp.add(minimumPositioningDuration), "endOfPositioning too low.");
        require(!creationRestrictedToOwner || msg.sender == owner, "Restricted creation");
        require(
            (openBidAllowed && _fixedTicketPrice == 0) ||
                (_fixedTicketPrice >= minFixedTicketPrice && _fixedTicketPrice <= maxFixedTicketPrice),
            "Exc min/max"
        );
        require(_tags.length > 0 && _tags.length <= maxNumberOfTags);
        require(keccak256(abi.encode(_marketQuestion)) != keccak256(abi.encode("")), "Invalid question.");
        require(keccak256(abi.encode(_marketSource)) != keccak256(abi.encode("")), "Invalid source");
        require(_positionCount == _positionPhrases.length, "Invalid posCount.");
        require(bytes(_marketQuestion).length < marketQuestionStringLimit, "mQuestion exceeds length");
        require(bytes(_marketSource).length < marketSourceStringLimit, "mSource exceeds length");
        require(thereAreNonEqualPositions(_positionPhrases), "Equal positional phrases");
        for (uint i = 0; i < _tags.length; i++) {
            require(IExoticPositionalTags(tagsAddress).isValidTagNumber(_tags[i]), "Invalid tag.");
        }

        if (_fixedTicketPrice > 0) {
            require(
                IERC20(paymentToken).balanceOf(msg.sender) >= fixedBondAmount.add(_fixedTicketPrice),
                "Low amount for creation."
            );
            require(
                IERC20(paymentToken).allowance(msg.sender, thalesBonds) >= fixedBondAmount.add(_fixedTicketPrice),
                "No allowance."
            );
            ExoticPositionalFixedMarket exoticMarket = ExoticPositionalFixedMarket(Clones.clone(exoticMarketMastercopy));

            exoticMarket.initialize(
                _marketQuestion,
                _marketSource,
                _endOfPositioning,
                _fixedTicketPrice,
                _withdrawalAllowed,
                _tags,
                _positionCount,
                _positionPhrases
            );
            creatorAddress[address(exoticMarket)] = msg.sender;
            IThalesBonds(thalesBonds).sendCreatorBondToMarket(address(exoticMarket), msg.sender, fixedBondAmount);
            _activeMarkets.add(address(exoticMarket));
            exoticMarket.takeCreatorInitialPosition(_positionsOfCreator[0]);
            emit MarketCreated(
                address(exoticMarket),
                _marketQuestion,
                _marketSource,
                _endOfPositioning,
                _fixedTicketPrice,
                _withdrawalAllowed,
                _tags,
                _positionCount,
                _positionPhrases,
                msg.sender
            );
        } else {
            require(_positionsOfCreator.length == _positionCount, "Creator init pos invalid");
            uint totalCreatorDeposit;
            uint[] memory creatorPositions = new uint[](_positionCount);
            for (uint i = 0; i < _positionCount; i++) {
                totalCreatorDeposit = totalCreatorDeposit.add(_positionsOfCreator[i]);
                creatorPositions[i] = i + 1;
            }
            require(IERC20(paymentToken).balanceOf(msg.sender) >= fixedBondAmount.add(totalCreatorDeposit), "Low amount");
            require(
                IERC20(paymentToken).allowance(msg.sender, thalesBonds) >= fixedBondAmount.add(totalCreatorDeposit),
                "No allowance."
            );

            ExoticPositionalOpenBidMarket exoticMarket =
                ExoticPositionalOpenBidMarket(Clones.clone(exoticMarketOpenBidMastercopy));

            exoticMarket.initialize(
                _marketQuestion,
                _marketSource,
                _endOfPositioning,
                _fixedTicketPrice,
                _withdrawalAllowed,
                _tags,
                _positionCount,
                _positionPhrases
            );
            creatorAddress[address(exoticMarket)] = msg.sender;
            IThalesBonds(thalesBonds).sendCreatorBondToMarket(address(exoticMarket), msg.sender, fixedBondAmount);
            _activeMarkets.add(address(exoticMarket));
            exoticMarket.takeCreatorInitialOpenBidPositions(creatorPositions, _positionsOfCreator);
            emit MarketCreated(
                address(exoticMarket),
                _marketQuestion,
                _marketSource,
                _endOfPositioning,
                _fixedTicketPrice,
                _withdrawalAllowed,
                _tags,
                _positionCount,
                _positionPhrases,
                msg.sender
            );
        }
    }

    function createCLMarket(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        uint _positionCount,
        uint[] memory _positionsOfCreator,
        string[] memory _positionPhrases
    ) external nonReentrant whenNotPaused {
        require(_endOfPositioning >= block.timestamp.add(minimumPositioningDuration), "endOfPositioning too low");
        require(theRundownConsumerAddress != address(0), "Invalid theRundownConsumer");
        require(msg.sender == theRundownConsumerAddress, "Invalid creator");
        require(_tags.length > 0 && _tags.length <= maxNumberOfTags);
        require(keccak256(abi.encode(_marketQuestion)) != keccak256(abi.encode("")), "Invalid question");
        require(keccak256(abi.encode(_marketSource)) != keccak256(abi.encode("")), "Invalid source");
        require(_positionCount == _positionPhrases.length, "Invalid posCount");
        require(bytes(_marketQuestion).length < 110, "Q exceeds length");
        require(thereAreNonEqualPositions(_positionPhrases), "Equal pos phrases");
        require(_positionsOfCreator.length == _positionCount, "Creator deposits wrong");
        uint totalCreatorDeposit;
        uint[] memory creatorPositions = new uint[](_positionCount);
        for (uint i = 0; i < _positionCount; i++) {
            totalCreatorDeposit = totalCreatorDeposit.add(_positionsOfCreator[i]);
            creatorPositions[i] = i + 1;
        }
        require(IERC20(paymentToken).balanceOf(msg.sender) >= totalCreatorDeposit, "Low creation amount");
        require(IERC20(paymentToken).allowance(msg.sender, thalesBonds) >= totalCreatorDeposit, "No allowance.");

        ExoticPositionalOpenBidMarket exoticMarket =
            ExoticPositionalOpenBidMarket(Clones.clone(exoticMarketOpenBidMastercopy));
        exoticMarket.initialize(
            _marketQuestion,
            _marketSource,
            _endOfPositioning,
            _fixedTicketPrice,
            _withdrawalAllowed,
            _tags,
            _positionCount,
            _positionPhrases
        );
        isChainLinkMarket[address(exoticMarket)] = true;
        creatorAddress[address(exoticMarket)] = msg.sender;
        _activeMarkets.add(address(exoticMarket));
        exoticMarket.takeCreatorInitialOpenBidPositions(creatorPositions, _positionsOfCreator);
        emit CLMarketCreated(
            address(exoticMarket),
            _marketQuestion,
            _marketSource,
            _endOfPositioning,
            _fixedTicketPrice,
            _withdrawalAllowed,
            _tags,
            _positionCount,
            _positionPhrases,
            msg.sender
        );
    }

    function resolveMarket(address _marketAddress, uint _outcomePosition) external whenNotPaused {
        require(isActiveMarket(_marketAddress), "NotActive");
        if (isChainLinkMarket[_marketAddress]) {
            require(msg.sender == theRundownConsumerAddress, "Only theRundownConsumer");
        }
        require(!IThalesOracleCouncil(oracleCouncilAddress).isOracleCouncilMember(msg.sender), "OC mem can not resolve");
        if (msg.sender != owner && msg.sender != oracleCouncilAddress) {
            require(IExoticPositionalMarket(_marketAddress).canMarketBeResolved(), "Resolved");
        }
        if (IExoticPositionalMarket(_marketAddress).paused()) {
            require(msg.sender == owner, "Only pDAO while paused");
        }
        if (
            (msg.sender == creatorAddress[_marketAddress] &&
                IThalesBonds(thalesBonds).getCreatorBondForMarket(_marketAddress) > 0) ||
            msg.sender == owner ||
            msg.sender == oracleCouncilAddress
        ) {
            require(oracleCouncilAddress != address(0), "Invalid OC");
            require(creatorAddress[_marketAddress] != address(0), "Invalid creator");
            require(owner != address(0), "Invalid owner");
            if (msg.sender == creatorAddress[_marketAddress]) {
                IThalesBonds(thalesBonds).transferCreatorToResolverBonds(_marketAddress);
            }
        } else {
            require(
                IERC20(paymentToken).balanceOf(msg.sender) >= IExoticPositionalMarket(_marketAddress).fixedBondAmount(),
                "Low amount for creation"
            );
            require(
                IERC20(paymentToken).allowance(msg.sender, thalesBonds) >=
                    IExoticPositionalMarket(_marketAddress).fixedBondAmount(),
                "No allowance."
            );
            IThalesBonds(thalesBonds).sendResolverBondToMarket(
                _marketAddress,
                msg.sender,
                IExoticPositionalMarket(_marketAddress).fixedBondAmount()
            );
        }
        resolverAddress[_marketAddress] = (msg.sender == oracleCouncilAddress || msg.sender == owner)
            ? safeBoxAddress
            : msg.sender;
        IExoticPositionalMarket(_marketAddress).resolveMarket(_outcomePosition, resolverAddress[_marketAddress]);
        emit MarketResolved(_marketAddress, _outcomePosition);
    }

    function cancelMarket(address _marketAddress) external whenNotPaused {
        require(isActiveMarket(_marketAddress), "NotActive");
        require(
            msg.sender == oracleCouncilAddress || msg.sender == owner || msg.sender == creatorAddress[_marketAddress],
            "Invalid address"
        );
        if (msg.sender != owner) {
            require(oracleCouncilAddress != address(0), "Invalid address");
        }
        // Creator can cancel if it is the only ticket holder or only one that placed open bid
        if (msg.sender == creatorAddress[_marketAddress]) {
            require(
                IExoticPositionalMarket(_marketAddress).canCreatorCancelMarket(),
                "Market can not be cancelled by creator"
            );
            cancelledByCreator[_marketAddress] = true;
            if (!IThalesOracleCouncil(oracleCouncilAddress).isMarketClosedForDisputes(_marketAddress)) {
                IThalesOracleCouncil(oracleCouncilAddress).closeMarketForDisputes(_marketAddress);
            }
        }
        if (IExoticPositionalMarket(_marketAddress).paused()) {
            require(msg.sender == owner, "only pDAO");
        }
        IExoticPositionalMarket(_marketAddress).cancelMarket();
        resolverAddress[msg.sender] = safeBoxAddress;
        if (cancelledByCreator[_marketAddress]) {
            IExoticPositionalMarket(_marketAddress).claimWinningTicketOnBehalf(creatorAddress[_marketAddress]);
        }
        emit MarketCanceled(_marketAddress);
    }

    function resetMarket(address _marketAddress) external onlyOracleCouncilAndOwner {
        require(isActiveMarket(_marketAddress), "NotActive");
        if (IExoticPositionalMarket(_marketAddress).paused()) {
            require(msg.sender == owner, "only pDAO");
            if (IThalesBonds(thalesBonds).getResolverBondForMarket(_marketAddress) > 0) {
                IThalesBonds(thalesBonds).sendBondFromMarketToUser(
                    _marketAddress,
                    safeBoxAddress,
                    IThalesBonds(thalesBonds).getResolverBondForMarket(_marketAddress),
                    102,
                    safeBoxAddress
                );
            }
        }
        IExoticPositionalMarket(_marketAddress).resetMarket();
        emit MarketReset(_marketAddress);
    }

    function sendRewardToDisputor(
        address _market,
        address _disputorAddress,
        uint _amount
    ) external onlyOracleCouncilAndOwner whenNotPaused {
        require(isActiveMarket(_market), "NotActive");
        IExoticRewards(exoticRewards).sendRewardToDisputoraddress(_market, _disputorAddress, _amount);
    }

    function issueBondsBackToCreatorAndResolver(address _marketAddress) external nonReentrant {
        require(isActiveMarket(_marketAddress), "NotActive");
        require(
            IExoticPositionalMarket(_marketAddress).canUsersClaim() || cancelledByCreator[_marketAddress],
            "Not claimable"
        );
        if (
            IThalesBonds(thalesBonds).getCreatorBondForMarket(_marketAddress) > 0 ||
            IThalesBonds(thalesBonds).getResolverBondForMarket(_marketAddress) > 0
        ) {
            IThalesBonds(thalesBonds).issueBondsBackToCreatorAndResolver(_marketAddress);
        }
    }

    function disputeMarket(address _marketAddress, address _disputor) external onlyOracleCouncil whenNotPaused {
        require(isActiveMarket(_marketAddress), "NotActive");
        IThalesBonds(thalesBonds).sendDisputorBondToMarket(
            _marketAddress,
            _disputor,
            IExoticPositionalMarket(_marketAddress).disputePrice()
        );
        require(!IExoticPositionalMarket(_marketAddress).paused(), "Market paused");
        if (!IExoticPositionalMarket(_marketAddress).disputed()) {
            IExoticPositionalMarket(_marketAddress).openDispute();
        }
    }

    function closeDispute(address _marketAddress) external onlyOracleCouncilAndOwner whenNotPaused {
        require(isActiveMarket(_marketAddress), "NotActive");
        if (IExoticPositionalMarket(_marketAddress).paused()) {
            require(msg.sender == owner, "Only pDAO");
        }
        require(IExoticPositionalMarket(_marketAddress).disputed(), "Market not disputed");
        IExoticPositionalMarket(_marketAddress).closeDispute();
    }

    function isActiveMarket(address _marketAddress) public view returns (bool) {
        return _activeMarkets.contains(_marketAddress);
    }

    function numberOfActiveMarkets() external view returns (uint) {
        return _activeMarkets.elements.length;
    }

    function getActiveMarketAddress(uint _index) external view returns (address) {
        return _activeMarkets.elements[_index];
    }

    function isPauserAddress(address _pauser) external view returns (bool) {
        return pauserIndex[_pauser] > 0;
    }

    function setBackstopTimeout(address _market) external onlyOracleCouncilAndOwner {
        IExoticPositionalMarket(_market).setBackstopTimeout(backstopTimeout);
    }

    function setCustomBackstopTimeout(address _market, uint _timeout) external onlyOracleCouncilAndOwner {
        require(_timeout > 0, "Invalid timeout");
        if (IExoticPositionalMarket(_market).backstopTimeout() != _timeout) {
            IExoticPositionalMarket(_market).setBackstopTimeout(_timeout);
        }
    }

    function setAddresses(
        address _exoticMarketMastercopy,
        address _exoticMarketOpenBidMastercopy,
        address _oracleCouncilAddress,
        address _paymentToken,
        address _tagsAddress,
        address _theRundownConsumerAddress,
        address _marketDataAddress,
        address _exoticRewards,
        address _safeBoxAddress
    ) external onlyOwner {
        if (_paymentToken != paymentToken) {
            paymentToken = _paymentToken;
        }
        if (_exoticMarketMastercopy != exoticMarketMastercopy) {
            exoticMarketMastercopy = _exoticMarketMastercopy;
        }
        if (_exoticMarketOpenBidMastercopy != exoticMarketOpenBidMastercopy) {
            exoticMarketOpenBidMastercopy = _exoticMarketOpenBidMastercopy;
        }
        if (_oracleCouncilAddress != oracleCouncilAddress) {
            oracleCouncilAddress = _oracleCouncilAddress;
        }
        if (_tagsAddress != tagsAddress) {
            tagsAddress = _tagsAddress;
        }

        if (_theRundownConsumerAddress != theRundownConsumerAddress) {
            theRundownConsumerAddress = _theRundownConsumerAddress;
        }

        if (_marketDataAddress != marketDataAddress) {
            marketDataAddress = _marketDataAddress;
        }
        if (_exoticRewards != exoticRewards) {
            exoticRewards = _exoticRewards;
        }

        if (_safeBoxAddress != safeBoxAddress) {
            safeBoxAddress = _safeBoxAddress;
        }
        emit AddressesUpdated(
            _paymentToken,
            _exoticMarketMastercopy,
            _exoticMarketOpenBidMastercopy,
            _oracleCouncilAddress,
            _tagsAddress,
            _theRundownConsumerAddress,
            _marketDataAddress,
            _exoticRewards,
            _safeBoxAddress
        );
    }

    function setPercentages(
        uint _safeBoxPercentage,
        uint _creatorPercentage,
        uint _resolverPercentage,
        uint _withdrawalPercentage,
        uint _maxFinalWithdrawPercentage
    ) external onlyOwner {
        if (_safeBoxPercentage != safeBoxPercentage) {
            safeBoxPercentage = _safeBoxPercentage;
        }
        if (_creatorPercentage != creatorPercentage) {
            creatorPercentage = _creatorPercentage;
        }
        if (_resolverPercentage != resolverPercentage) {
            resolverPercentage = _resolverPercentage;
        }
        if (_withdrawalPercentage != withdrawalPercentage) {
            withdrawalPercentage = _withdrawalPercentage;
        }
        if (_maxFinalWithdrawPercentage != maxFinalWithdrawPercentage) {
            maxFinalWithdrawPercentage = _maxFinalWithdrawPercentage;
        }
        emit PercentagesUpdated(
            _safeBoxPercentage,
            _creatorPercentage,
            _resolverPercentage,
            _withdrawalPercentage,
            _maxFinalWithdrawPercentage
        );
    }

    function setDurations(
        uint _backstopTimeout,
        uint _minimumPositioningDuration,
        uint _withdrawalTimePeriod,
        uint _pDAOResolveTimePeriod,
        uint _claimTimeoutDefaultPeriod
    ) external onlyOwner {
        if (_backstopTimeout != backstopTimeout) {
            backstopTimeout = _backstopTimeout;
        }

        if (_minimumPositioningDuration != minimumPositioningDuration) {
            minimumPositioningDuration = _minimumPositioningDuration;
        }

        if (_withdrawalTimePeriod != withdrawalTimePeriod) {
            withdrawalTimePeriod = _withdrawalTimePeriod;
        }

        if (_pDAOResolveTimePeriod != pDAOResolveTimePeriod) {
            pDAOResolveTimePeriod = _pDAOResolveTimePeriod;
        }

        if (_claimTimeoutDefaultPeriod != claimTimeoutDefaultPeriod) {
            claimTimeoutDefaultPeriod = _claimTimeoutDefaultPeriod;
        }

        emit DurationsUpdated(
            _backstopTimeout,
            _minimumPositioningDuration,
            _withdrawalTimePeriod,
            _pDAOResolveTimePeriod,
            _claimTimeoutDefaultPeriod
        );
    }

    function setLimits(
        uint _marketQuestionStringLimit,
        uint _marketSourceStringLimit,
        uint _marketPositionStringLimit,
        uint _disputeStringLengthLimit,
        uint _maximumPositionsAllowed,
        uint _maxNumberOfTags,
        uint _maxOracleCouncilMembers
    ) external onlyOwner {
        if (_marketQuestionStringLimit != marketQuestionStringLimit) {
            marketQuestionStringLimit = _marketQuestionStringLimit;
        }

        if (_marketSourceStringLimit != marketSourceStringLimit) {
            marketSourceStringLimit = _marketSourceStringLimit;
        }

        if (_marketPositionStringLimit != marketPositionStringLimit) {
            marketPositionStringLimit = _marketPositionStringLimit;
        }

        if (_disputeStringLengthLimit != disputeStringLengthLimit) {
            disputeStringLengthLimit = _disputeStringLengthLimit;
        }

        if (_maximumPositionsAllowed != maximumPositionsAllowed) {
            maximumPositionsAllowed = _maximumPositionsAllowed;
        }

        if (_maxNumberOfTags != maxNumberOfTags) {
            maxNumberOfTags = _maxNumberOfTags;
        }

        if (_maxOracleCouncilMembers != maxOracleCouncilMembers) {
            maxOracleCouncilMembers = _maxOracleCouncilMembers;
        }

        emit LimitsUpdated(
            _marketQuestionStringLimit,
            _marketSourceStringLimit,
            _marketPositionStringLimit,
            _disputeStringLengthLimit,
            _maximumPositionsAllowed,
            _maxNumberOfTags,
            _maxOracleCouncilMembers
        );
    }

    function setAmounts(
        uint _minFixedTicketPrice,
        uint _maxFixedTicketPrice,
        uint _disputePrice,
        uint _fixedBondAmount,
        uint _safeBoxLowAmount,
        uint _arbitraryRewardForDisputor,
        uint _maxAmountForOpenBidPosition
    ) external onlyOwner {
        if (_minFixedTicketPrice != minFixedTicketPrice) {
            minFixedTicketPrice = _minFixedTicketPrice;
        }

        if (_maxFixedTicketPrice != maxFixedTicketPrice) {
            maxFixedTicketPrice = _maxFixedTicketPrice;
        }

        if (_disputePrice != disputePrice) {
            disputePrice = _disputePrice;
        }

        if (_fixedBondAmount != fixedBondAmount) {
            fixedBondAmount = _fixedBondAmount;
        }

        if (_safeBoxLowAmount != safeBoxLowAmount) {
            safeBoxLowAmount = _safeBoxLowAmount;
        }

        if (_arbitraryRewardForDisputor != arbitraryRewardForDisputor) {
            arbitraryRewardForDisputor = _arbitraryRewardForDisputor;
        }

        if (_maxAmountForOpenBidPosition != maxAmountForOpenBidPosition) {
            maxAmountForOpenBidPosition = _maxAmountForOpenBidPosition;
        }

        emit AmountsUpdated(
            _minFixedTicketPrice,
            _maxFixedTicketPrice,
            _disputePrice,
            _fixedBondAmount,
            _safeBoxLowAmount,
            _arbitraryRewardForDisputor,
            _maxAmountForOpenBidPosition
        );
    }

    function setFlags(bool _creationRestrictedToOwner, bool _openBidAllowed) external onlyOwner {
        if (_creationRestrictedToOwner != creationRestrictedToOwner) {
            creationRestrictedToOwner = _creationRestrictedToOwner;
        }

        if (_openBidAllowed != openBidAllowed) {
            openBidAllowed = _openBidAllowed;
        }

        emit FlagsUpdated(_creationRestrictedToOwner, _openBidAllowed);
    }

    function setThalesBonds(address _thalesBonds) external onlyOwner {
        require(_thalesBonds != address(0), "Invalid address");
        if (thalesBonds != address(0)) {
            IERC20(paymentToken).approve(address(thalesBonds), 0);
        }
        thalesBonds = _thalesBonds;
        IERC20(paymentToken).approve(address(thalesBonds), type(uint256).max);
        emit NewThalesBonds(_thalesBonds);
    }

    function addPauserAddress(address _pauserAddress) external onlyOracleCouncilAndOwner {
        require(_pauserAddress != address(0), "Invalid address");
        require(pauserIndex[_pauserAddress] == 0, "Exists as pauser");
        pausersCount = pausersCount.add(1);
        pauserIndex[_pauserAddress] = pausersCount;
        pauserAddress[pausersCount] = _pauserAddress;
        emit PauserAddressAdded(_pauserAddress);
    }

    function removePauserAddress(address _pauserAddress) external onlyOracleCouncilAndOwner {
        require(_pauserAddress != address(0), "Invalid address");
        require(pauserIndex[_pauserAddress] != 0, "Not exists");
        pauserAddress[pauserIndex[_pauserAddress]] = pauserAddress[pausersCount];
        pauserIndex[pauserAddress[pausersCount]] = pauserIndex[_pauserAddress];
        pausersCount = pausersCount.sub(1);
        pauserIndex[_pauserAddress] = 0;
        emit PauserAddressRemoved(_pauserAddress);
    }

    // INTERNAL

    function thereAreNonEqualPositions(string[] memory positionPhrases) internal view returns (bool) {
        for (uint i = 0; i < positionPhrases.length - 1; i++) {
            if (
                keccak256(abi.encode(positionPhrases[i])) == keccak256(abi.encode(positionPhrases[i + 1])) ||
                bytes(positionPhrases[i]).length > marketPositionStringLimit
            ) {
                return false;
            }
        }
        return true;
    }

    event AddressesUpdated(
        address _exoticMarketMastercopy,
        address _exoticMarketOpenBidMastercopy,
        address _oracleCouncilAddress,
        address _paymentToken,
        address _tagsAddress,
        address _theRundownConsumerAddress,
        address _marketDataAddress,
        address _exoticRewards,
        address _safeBoxAddress
    );

    event PercentagesUpdated(
        uint safeBoxPercentage,
        uint creatorPercentage,
        uint resolverPercentage,
        uint withdrawalPercentage,
        uint maxFinalWithdrawPercentage
    );

    event DurationsUpdated(
        uint backstopTimeout,
        uint minimumPositioningDuration,
        uint withdrawalTimePeriod,
        uint pDAOResolveTimePeriod,
        uint claimTimeoutDefaultPeriod
    );
    event LimitsUpdated(
        uint marketQuestionStringLimit,
        uint marketSourceStringLimit,
        uint marketPositionStringLimit,
        uint disputeStringLengthLimit,
        uint maximumPositionsAllowed,
        uint maxNumberOfTags,
        uint maxOracleCouncilMembers
    );

    event AmountsUpdated(
        uint minFixedTicketPrice,
        uint maxFixedTicketPrice,
        uint disputePrice,
        uint fixedBondAmount,
        uint safeBoxLowAmount,
        uint arbitraryRewardForDisputor,
        uint maxAmountForOpenBidPosition
    );

    event FlagsUpdated(bool _creationRestrictedToOwner, bool _openBidAllowed);

    event MarketResolved(address marketAddress, uint outcomePosition);
    event MarketCanceled(address marketAddress);
    event MarketReset(address marketAddress);
    event PauserAddressAdded(address pauserAddress);
    event PauserAddressRemoved(address pauserAddress);
    event NewThalesBonds(address thalesBondsAddress);

    event MarketCreated(
        address marketAddress,
        string marketQuestion,
        string marketSource,
        uint endOfPositioning,
        uint fixedTicketPrice,
        bool withdrawalAllowed,
        uint[] tags,
        uint positionCount,
        string[] positionPhrases,
        address marketOwner
    );

    event CLMarketCreated(
        address marketAddress,
        string marketQuestion,
        string marketSource,
        uint endOfPositioning,
        uint fixedTicketPrice,
        bool withdrawalAllowed,
        uint[] tags,
        uint positionCount,
        string[] positionPhrases,
        address marketOwner
    );

    modifier onlyOracleCouncil() {
        require(msg.sender == oracleCouncilAddress, "No OC");
        require(oracleCouncilAddress != address(0), "No OC");
        _;
    }
    modifier onlyOracleCouncilAndOwner() {
        require(msg.sender == oracleCouncilAddress || msg.sender == owner, "No OC/owner");
        if (msg.sender != owner) {
            require(oracleCouncilAddress != address(0), "No OC/owner");
        }
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "./OraclePausable.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/utils/SafeERC20.sol";
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";
import "../interfaces/IThalesBonds.sol";

contract ExoticPositionalFixedMarket is Initializable, ProxyOwned, OraclePausable, ProxyReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    enum TicketType {FIXED_TICKET_PRICE, FLEXIBLE_BID}
    uint private constant HUNDRED = 100;
    uint private constant ONE_PERCENT = 1e16;
    uint private constant HUNDRED_PERCENT = 1e18;
    uint private constant CANCELED = 0;

    uint public creationTime;
    uint public resolvedTime;
    uint public lastDisputeTime;
    uint public positionCount;
    uint public endOfPositioning;
    uint public marketMaturity;
    uint public fixedTicketPrice;
    uint public backstopTimeout;
    uint public totalUsersTakenPositions;
    uint public claimableTicketsCount;
    uint public winningPosition;
    uint public disputeClosedTime;
    uint public fixedBondAmount;
    uint public disputePrice;
    uint public safeBoxLowAmount;
    uint public arbitraryRewardForDisputor;
    uint public withdrawalPeriod;

    bool public noWinners;
    bool public disputed;
    bool public resolved;
    bool public disputedInPositioningPhase;
    bool public feesAndBondsClaimed;
    bool public withdrawalAllowed;

    address public resolverAddress;
    TicketType public ticketType;
    IExoticPositionalMarketManager public marketManager;
    IThalesBonds public thalesBonds;

    mapping(address => uint) public userPosition;
    mapping(address => uint) public userAlreadyClaimed;
    mapping(uint => uint) public ticketsPerPosition;
    mapping(uint => string) public positionPhrase;
    uint[] public tags;
    string public marketQuestion;
    string public marketSource;

    function initialize(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        uint _positionCount,
        string[] memory _positionPhrases
    ) external initializer {
        require(
            _positionCount >= 2 && _positionCount <= IExoticPositionalMarketManager(msg.sender).maximumPositionsAllowed(),
            "Invalid num of positions"
        );
        require(_tags.length > 0);
        setOwner(msg.sender);
        marketManager = IExoticPositionalMarketManager(msg.sender);
        thalesBonds = IThalesBonds(marketManager.thalesBonds());
        _initializeWithTwoParameters(
            _marketQuestion,
            _marketSource,
            _endOfPositioning,
            _fixedTicketPrice,
            _withdrawalAllowed,
            _tags,
            _positionPhrases[0],
            _positionPhrases[1]
        );
        if (_positionCount > 2) {
            for (uint i = 2; i < _positionCount; i++) {
                _addPosition(_positionPhrases[i]);
            }
        }
        fixedBondAmount = marketManager.fixedBondAmount();
        disputePrice = marketManager.disputePrice();
        safeBoxLowAmount = marketManager.safeBoxLowAmount();
        arbitraryRewardForDisputor = marketManager.arbitraryRewardForDisputor();
        withdrawalPeriod = _endOfPositioning.sub(marketManager.withdrawalTimePeriod());
    }

    function takeCreatorInitialPosition(uint _position) external onlyOwner {
        require(_position > 0 && _position <= positionCount, "Value invalid");
        require(ticketType == TicketType.FIXED_TICKET_PRICE, "Not Fixed type");
        address creatorAddress = marketManager.creatorAddress(address(this));
        totalUsersTakenPositions = totalUsersTakenPositions.add(1);
        ticketsPerPosition[_position] = ticketsPerPosition[_position].add(1);
        userPosition[creatorAddress] = _position;
        transferToMarket(creatorAddress, fixedTicketPrice);
        emit NewPositionTaken(creatorAddress, _position, fixedTicketPrice);
    }

    function takeAPosition(uint _position) external notPaused nonReentrant {
        require(_position > 0, "Invalid position");
        require(_position <= positionCount, "Position value invalid");
        require(canUsersPlacePosition(), "Positioning finished/market resolved");
        //require(same position)
        require(ticketType == TicketType.FIXED_TICKET_PRICE, "Not Fixed type");
        if (userPosition[msg.sender] == 0) {
            transferToMarket(msg.sender, fixedTicketPrice);
            totalUsersTakenPositions = totalUsersTakenPositions.add(1);
        } else {
            ticketsPerPosition[userPosition[msg.sender]] = ticketsPerPosition[userPosition[msg.sender]].sub(1);
        }
        ticketsPerPosition[_position] = ticketsPerPosition[_position].add(1);
        userPosition[msg.sender] = _position;
        emit NewPositionTaken(msg.sender, _position, fixedTicketPrice);
    }

    function withdraw() external notPaused nonReentrant {
        require(withdrawalAllowed, "Not allowed");
        require(canUsersPlacePosition(), "Market resolved");
        require(block.timestamp <= withdrawalPeriod, "Withdrawal expired");
        require(userPosition[msg.sender] > 0, "Not a ticket holder");
        require(msg.sender != marketManager.creatorAddress(address(this)), "Can not withdraw");
        uint withdrawalFee =
            fixedTicketPrice.mul(marketManager.withdrawalPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
        totalUsersTakenPositions = totalUsersTakenPositions.sub(1);
        ticketsPerPosition[userPosition[msg.sender]] = ticketsPerPosition[userPosition[msg.sender]].sub(1);
        userPosition[msg.sender] = 0;
        thalesBonds.transferFromMarket(marketManager.safeBoxAddress(), withdrawalFee.div(2));
        thalesBonds.transferFromMarket(marketManager.creatorAddress(address(this)), withdrawalFee.div(2));
        thalesBonds.transferFromMarket(msg.sender, fixedTicketPrice.sub(withdrawalFee));
        emit TicketWithdrawn(msg.sender, fixedTicketPrice.sub(withdrawalFee));
    }

    function issueFees() external notPaused nonReentrant {
        require(canUsersClaim(), "Not finalized");
        require(!feesAndBondsClaimed, "Fees claimed");
        if (winningPosition != CANCELED) {
            thalesBonds.transferFromMarket(marketManager.creatorAddress(address(this)), getAdditionalCreatorAmount());
            thalesBonds.transferFromMarket(resolverAddress, getAdditionalResolverAmount());
            thalesBonds.transferFromMarket(marketManager.safeBoxAddress(), getSafeBoxAmount());
        }
        marketManager.issueBondsBackToCreatorAndResolver(address(this));
        feesAndBondsClaimed = true;
        emit FeesIssued(getTotalFeesAmount());
    }

    // market resolved only through the Manager
    function resolveMarket(uint _outcomePosition, address _resolverAddress) external onlyOwner {
        require(canMarketBeResolvedByOwner(), "Not resolvable. Disputed/not matured");
        require(_outcomePosition <= positionCount, "Outcome exeeds positionNum");
        winningPosition = _outcomePosition;
        if (_outcomePosition == CANCELED) {
            claimableTicketsCount = totalUsersTakenPositions;
            ticketsPerPosition[winningPosition] = totalUsersTakenPositions;
        } else {
            if (ticketsPerPosition[_outcomePosition] == 0) {
                claimableTicketsCount = totalUsersTakenPositions;
                noWinners = true;
            } else {
                claimableTicketsCount = ticketsPerPosition[_outcomePosition];
                noWinners = false;
            }
        }
        resolved = true;
        resolvedTime = block.timestamp;
        resolverAddress = _resolverAddress;
        emit MarketResolved(_outcomePosition, _resolverAddress, noWinners);
    }

    function resetMarket() external onlyOwner {
        require(resolved, "Not resolved");
        if (winningPosition == CANCELED) {
            ticketsPerPosition[winningPosition] = 0;
        }
        winningPosition = 0;
        claimableTicketsCount = 0;
        resolved = false;
        noWinners = false;
        resolvedTime = 0;
        resolverAddress = marketManager.safeBoxAddress();
        emit MarketReset();
    }

    function cancelMarket() external onlyOwner {
        winningPosition = CANCELED;
        claimableTicketsCount = totalUsersTakenPositions;
        ticketsPerPosition[winningPosition] = totalUsersTakenPositions;
        resolved = true;
        noWinners = false;
        resolvedTime = block.timestamp;
        resolverAddress = marketManager.safeBoxAddress();
        emit MarketResolved(CANCELED, msg.sender, noWinners);
    }

    function claimWinningTicket() external notPaused nonReentrant {
        require(canUsersClaim(), "Not finalized.");
        uint amount = getUserClaimableAmount(msg.sender);
        require(amount > 0, "Zero claimable.");
        claimableTicketsCount = claimableTicketsCount.sub(1);
        userPosition[msg.sender] = 0;
        thalesBonds.transferFromMarket(msg.sender, amount);
        if (!feesAndBondsClaimed) {
            if (winningPosition != CANCELED) {
                thalesBonds.transferFromMarket(marketManager.creatorAddress(address(this)), getAdditionalCreatorAmount());
                thalesBonds.transferFromMarket(resolverAddress, getAdditionalResolverAmount());
                thalesBonds.transferFromMarket(marketManager.safeBoxAddress(), getSafeBoxAmount());
            }
            marketManager.issueBondsBackToCreatorAndResolver(address(this));
            feesAndBondsClaimed = true;
            emit FeesIssued(getTotalFeesAmount());
        }
        userAlreadyClaimed[msg.sender] = userAlreadyClaimed[msg.sender].add(amount);
        emit WinningTicketClaimed(msg.sender, amount);
    }

    function claimWinningTicketOnBehalf(address _user) external onlyOwner {
        require(canUsersClaim() || marketManager.cancelledByCreator(address(this)), "Not finalized.");
        uint amount = getUserClaimableAmount(_user);
        require(amount > 0, "Zero claimable.");
        claimableTicketsCount = claimableTicketsCount.sub(1);
        userPosition[_user] = 0;
        thalesBonds.transferFromMarket(_user, amount);
        if (
            winningPosition == CANCELED &&
            marketManager.cancelledByCreator(address(this)) &&
            thalesBonds.getCreatorBondForMarket(address(this)) > 0
        ) {
            marketManager.issueBondsBackToCreatorAndResolver(address(this));
            feesAndBondsClaimed = true;
        } else if (!feesAndBondsClaimed) {
            if (winningPosition != CANCELED) {
                thalesBonds.transferFromMarket(marketManager.creatorAddress(address(this)), getAdditionalCreatorAmount());
                thalesBonds.transferFromMarket(resolverAddress, getAdditionalResolverAmount());
                thalesBonds.transferFromMarket(marketManager.safeBoxAddress(), getSafeBoxAmount());
            }
            marketManager.issueBondsBackToCreatorAndResolver(address(this));
            feesAndBondsClaimed = true;
            emit FeesIssued(getTotalFeesAmount());
        }
        userAlreadyClaimed[msg.sender] = userAlreadyClaimed[msg.sender].add(amount);
        emit WinningTicketClaimed(_user, amount);
    }

    function openDispute() external onlyOwner {
        require(isMarketCreated(), "Not created");
        require(!disputed, "Already disputed");
        disputed = true;
        disputedInPositioningPhase = canUsersPlacePosition();
        lastDisputeTime = block.timestamp;
        emit MarketDisputed(true);
    }

    function closeDispute() external onlyOwner {
        require(disputed, "Not disputed");
        disputeClosedTime = block.timestamp;
        if (disputedInPositioningPhase) {
            disputed = false;
            disputedInPositioningPhase = false;
        } else {
            disputed = false;
        }
        emit MarketDisputed(false);
    }

    function transferToMarket(address _sender, uint _amount) internal notPaused {
        require(_sender != address(0), "Invalid sender");
        require(IERC20(marketManager.paymentToken()).balanceOf(_sender) >= _amount, "Sender balance low");
        require(
            IERC20(marketManager.paymentToken()).allowance(_sender, marketManager.thalesBonds()) >= _amount,
            "No allowance."
        );
        IThalesBonds(marketManager.thalesBonds()).transferToMarket(_sender, _amount);
    }

    // SETTERS ///////////////////////////////////////////////////////

    function setBackstopTimeout(uint _timeoutPeriod) external onlyOwner {
        backstopTimeout = _timeoutPeriod;
        emit BackstopTimeoutPeriodChanged(_timeoutPeriod);
    }

    // VIEWS /////////////////////////////////////////////////////////

    function isMarketCreated() public view returns (bool) {
        return creationTime > 0;
    }

    function isMarketCancelled() public view returns (bool) {
        return resolved && winningPosition == CANCELED;
    }

    function canUsersPlacePosition() public view returns (bool) {
        return block.timestamp <= endOfPositioning && creationTime > 0 && !resolved;
    }

    function canMarketBeResolved() public view returns (bool) {
        return block.timestamp >= endOfPositioning && creationTime > 0 && (!disputed) && !resolved;
    }

    function canMarketBeResolvedByOwner() public view returns (bool) {
        return block.timestamp >= endOfPositioning && creationTime > 0 && (!disputed);
    }

    function canMarketBeResolvedByPDAO() public view returns (bool) {
        return
            canMarketBeResolvedByOwner() && block.timestamp >= endOfPositioning.add(marketManager.pDAOResolveTimePeriod());
    }

    function canCreatorCancelMarket() external view returns (bool) {
        if (disputed) {
            return false;
        } else if (totalUsersTakenPositions != 1) {
            return totalUsersTakenPositions > 1 ? false : true;
        } else {
            return userPosition[marketManager.creatorAddress(address(this))] > 0 ? true : false;
        }
    }

    function canUsersClaim() public view returns (bool) {
        return
            resolved &&
            (!disputed) &&
            ((resolvedTime > 0 && block.timestamp > resolvedTime.add(marketManager.claimTimeoutDefaultPeriod())) ||
                (backstopTimeout > 0 &&
                    resolvedTime > 0 &&
                    disputeClosedTime > 0 &&
                    block.timestamp > disputeClosedTime.add(backstopTimeout)));
    }

    function canUserClaim(address _user) external view returns (bool) {
        return canUsersClaim() && getUserClaimableAmount(_user) > 0;
    }

    function canIssueFees() external view returns (bool) {
        return
            !feesAndBondsClaimed &&
            (thalesBonds.getCreatorBondForMarket(address(this)) > 0 ||
                thalesBonds.getResolverBondForMarket(address(this)) > 0);
    }

    function canUserWithdraw(address _account) public view returns (bool) {
        if (_account == marketManager.creatorAddress(address(this))) {
            return false;
        }
        return
            withdrawalAllowed &&
            canUsersPlacePosition() &&
            userPosition[_account] > 0 &&
            block.timestamp <= withdrawalPeriod;
    }

    function getPositionPhrase(uint index) public view returns (string memory) {
        return (index <= positionCount && index > 0) ? positionPhrase[index] : string("");
    }

    function getTotalPlacedAmount() public view returns (uint) {
        return totalUsersTakenPositions > 0 ? fixedTicketPrice.mul(totalUsersTakenPositions) : 0;
    }

    function getTotalClaimableAmount() public view returns (uint) {
        if (totalUsersTakenPositions == 0) {
            return 0;
        } else {
            return winningPosition == CANCELED ? getTotalPlacedAmount() : applyDeduction(getTotalPlacedAmount());
        }
    }

    function getTotalFeesAmount() public view returns (uint) {
        return getTotalPlacedAmount().sub(getTotalClaimableAmount());
    }

    function getPlacedAmountPerPosition(uint _position) public view returns (uint) {
        return fixedTicketPrice.mul(ticketsPerPosition[_position]);
    }

    function getUserClaimableAmount(address _account) public view returns (uint) {
        return
            userPosition[_account] > 0 &&
                (noWinners || userPosition[_account] == winningPosition || winningPosition == CANCELED)
                ? getWinningAmountPerTicket()
                : 0;
    }

    /// FLEXIBLE BID FUNCTIONS

    function getAllUserPositions(address _account) external view returns (uint[] memory) {
        uint[] memory userAllPositions = new uint[](positionCount);
        if (positionCount == 0) {
            return userAllPositions;
        }
        userAllPositions[userPosition[_account]] = 1;
        return userAllPositions;
    }

    /// FIXED TICKET FUNCTIONS

    function getUserPosition(address _account) external view returns (uint) {
        return userPosition[_account];
    }

    function getUserPositionPhrase(address _account) external view returns (string memory) {
        return (userPosition[_account] > 0) ? positionPhrase[userPosition[_account]] : string("");
    }

    function getPotentialWinningAmountForAllPosition(bool forNewUserView, uint userAlreadyTakenPosition)
        external
        view
        returns (uint[] memory)
    {
        uint[] memory potentialWinning = new uint[](positionCount);
        for (uint i = 1; i <= positionCount; i++) {
            potentialWinning[i - 1] = getPotentialWinningAmountForPosition(i, forNewUserView, userAlreadyTakenPosition == i);
        }
        return potentialWinning;
    }

    function getUserPotentialWinningAmount(address _account) external view returns (uint) {
        return userPosition[_account] > 0 ? getPotentialWinningAmountForPosition(userPosition[_account], false, true) : 0;
    }

    function getPotentialWinningAmountForPosition(
        uint _position,
        bool forNewUserView,
        bool userHasAlreadyTakenThisPosition
    ) internal view returns (uint) {
        if (totalUsersTakenPositions == 0) {
            return 0;
        }
        if (ticketsPerPosition[_position] == 0) {
            return
                forNewUserView
                    ? applyDeduction(getTotalPlacedAmount().add(fixedTicketPrice))
                    : applyDeduction(getTotalPlacedAmount());
        } else {
            if (forNewUserView) {
                return
                    applyDeduction(getTotalPlacedAmount().add(fixedTicketPrice)).div(ticketsPerPosition[_position].add(1));
            } else {
                uint calculatedPositions =
                    userHasAlreadyTakenThisPosition && ticketsPerPosition[_position] > 0
                        ? ticketsPerPosition[_position]
                        : ticketsPerPosition[_position].add(1);
                return applyDeduction(getTotalPlacedAmount()).div(calculatedPositions);
            }
        }
    }

    function getWinningAmountPerTicket() public view returns (uint) {
        if (totalUsersTakenPositions == 0 || !resolved || (!noWinners && (ticketsPerPosition[winningPosition] == 0))) {
            return 0;
        }
        if (noWinners) {
            return getTotalClaimableAmount().div(totalUsersTakenPositions);
        } else {
            return
                winningPosition == CANCELED
                    ? fixedTicketPrice
                    : getTotalClaimableAmount().div(ticketsPerPosition[winningPosition]);
        }
    }

    function applyDeduction(uint value) internal view returns (uint) {
        return
            (value)
                .mul(
                HUNDRED.sub(
                    marketManager.safeBoxPercentage().add(marketManager.creatorPercentage()).add(
                        marketManager.resolverPercentage()
                    )
                )
            )
                .mul(ONE_PERCENT)
                .div(HUNDRED_PERCENT);
    }

    function getTagsCount() external view returns (uint) {
        return tags.length;
    }

    function getTags() external view returns (uint[] memory) {
        return tags;
    }

    function getTicketType() external view returns (uint) {
        return uint(ticketType);
    }

    function getAllAmounts()
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint
        )
    {
        return (fixedBondAmount, disputePrice, safeBoxLowAmount, arbitraryRewardForDisputor);
    }

    function getAllFees()
        external
        view
        returns (
            uint,
            uint,
            uint,
            uint
        )
    {
        return (getAdditionalCreatorAmount(), getAdditionalResolverAmount(), getSafeBoxAmount(), getTotalFeesAmount());
    }

    function getAdditionalCreatorAmount() internal view returns (uint) {
        return getTotalPlacedAmount().mul(marketManager.creatorPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
    }

    function getAdditionalResolverAmount() internal view returns (uint) {
        return getTotalPlacedAmount().mul(marketManager.resolverPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
    }

    function getSafeBoxAmount() internal view returns (uint) {
        return getTotalPlacedAmount().mul(marketManager.safeBoxPercentage()).mul(ONE_PERCENT).div(HUNDRED_PERCENT);
    }

    function _initializeWithTwoParameters(
        string memory _marketQuestion,
        string memory _marketSource,
        uint _endOfPositioning,
        uint _fixedTicketPrice,
        bool _withdrawalAllowed,
        uint[] memory _tags,
        string memory _positionPhrase1,
        string memory _positionPhrase2
    ) internal {
        creationTime = block.timestamp;
        marketQuestion = _marketQuestion;
        marketSource = _marketSource;
        endOfPositioning = _endOfPositioning;
        // Ticket Type can be determined based on ticket price
        ticketType = _fixedTicketPrice > 0 ? TicketType.FIXED_TICKET_PRICE : TicketType.FLEXIBLE_BID;
        fixedTicketPrice = _fixedTicketPrice;
        // Withdrawal allowance determined based on withdrawal percentage, if it is over 100% then it is forbidden
        withdrawalAllowed = _withdrawalAllowed;
        // The tag is just a number for now
        tags = _tags;
        _addPosition(_positionPhrase1);
        _addPosition(_positionPhrase2);
    }

    function _addPosition(string memory _position) internal {
        require(keccak256(abi.encode(_position)) != keccak256(abi.encode("")), "Invalid position label (empty string)");
        // require(bytes(_position).length < marketManager.marketPositionStringLimit(), "Position label exceeds length");
        positionCount = positionCount.add(1);
        positionPhrase[positionCount] = _position;
    }

    event MarketDisputed(bool disputed);
    event MarketCreated(uint creationTime, uint positionCount, bytes32 phrase);
    event MarketResolved(uint winningPosition, address resolverAddress, bool noWinner);
    event MarketReset();
    event WinningTicketClaimed(address account, uint amount);
    event BackstopTimeoutPeriodChanged(uint timeoutPeriod);
    event NewPositionTaken(address account, uint position, uint fixedTicketAmount);
    event TicketWithdrawn(address account, uint amount);
    event BondIncreased(uint amount, uint totalAmount);
    event BondDecreased(uint amount, uint totalAmount);
    event FeesIssued(uint totalFees);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IExoticPositionalTags {
    /* ========== VIEWS / VARIABLES ========== */
    function isValidTagNumber(uint _number) external view returns (bool);
    function isValidTagLabel(string memory _label) external view returns (bool);
    function isValidTag(string memory _label, uint _number) external view returns (bool);
    function getTagLabel(uint _number) external view returns (string memory);
    function getTagNumber(string memory _label) external view returns (uint);
    function getTagNumberIndex(uint _number) external view returns (uint);
    function getTagIndexNumber(uint _index) external view returns (uint);
    function getTagByIndex(uint _index) external view returns (string memory, uint);
    function getTagsCount() external view returns (uint);

    function addTag(string memory _label, uint _number) external;
    function editTagNumber(string memory _label, uint _number) external;
    function editTagLabel(string memory _label, uint _number) external;
    function removeTag(uint _number) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IThalesOracleCouncil {
    /* ========== VIEWS / VARIABLES ========== */
    function isOracleCouncilMember(address _councilMember) external view returns (bool);
    function isMarketClosedForDisputes(address _market) external view returns (bool);

    function closeMarketForDisputes(address _market) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IExoticRewards {
    /* ========== VIEWS / VARIABLES ========== */
    function sendRewardToDisputoraddress(
        address _market,
        address _disputorAddress,
        uint _amount
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "../interfaces/IPositionalMarketManager.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";

// Libraries
import "../utils/libraries/AddressSetLib.sol";
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
import "./PositionalMarketFactory.sol";
import "./PositionalMarket.sol";
import "./Position.sol";
import "../interfaces/IPositionalMarket.sol";
import "../interfaces/IPriceFeed.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PositionalMarketManager is Initializable, ProxyOwned, ProxyPausable, IPositionalMarketManager {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;
    using AddressSetLib for AddressSetLib.AddressSet;

    /* ========== TYPES ========== */

    struct Fees {
        uint poolFee;
        uint creatorFee;
    }

    struct Durations {
        uint expiryDuration;
        uint maxTimeToMaturity;
    }

    /* ========== STATE VARIABLES ========== */

    Durations public override durations;
    uint public override capitalRequirement;

    bool public override marketCreationEnabled;
    bool public customMarketCreationEnabled;

    bool public onlyWhitelistedAddressesCanCreateMarkets;
    mapping(address => bool) public whitelistedAddresses;

    uint public override totalDeposited;

    AddressSetLib.AddressSet internal _activeMarkets;
    AddressSetLib.AddressSet internal _maturedMarkets;

    PositionalMarketManager internal _migratingManager;

    IPriceFeed public priceFeed;
    IERC20 public sUSD;

    address public positionalMarketFactory;

    bool public needsTransformingCollateral;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _owner,
        IERC20 _sUSD,
        IPriceFeed _priceFeed,
        uint _expiryDuration,
        uint _maxTimeToMaturity,
        uint _creatorCapitalRequirement
    ) external initializer {
        setOwner(_owner);
        priceFeed = _priceFeed;
        sUSD = _sUSD;

        // Temporarily change the owner so that the setters don't revert.
        owner = msg.sender;

        marketCreationEnabled = true;
        customMarketCreationEnabled = false;
        onlyWhitelistedAddressesCanCreateMarkets = false;

        setExpiryDuration(_expiryDuration);
        setMaxTimeToMaturity(_maxTimeToMaturity);
        setCreatorCapitalRequirement(_creatorCapitalRequirement);
    }

    /* ========== SETTERS ========== */
    function setPositionalMarketFactory(address _positionalMarketFactory) external onlyOwner {
        positionalMarketFactory = _positionalMarketFactory;
        emit SetPositionalMarketFactory(_positionalMarketFactory);
    }

    function setNeedsTransformingCollateral(bool _needsTransformingCollateral) external onlyOwner {
        needsTransformingCollateral = _needsTransformingCollateral;
    }

    function setWhitelistedAddresses(address[] calldata _whitelistedAddresses) external onlyOwner {
        require(_whitelistedAddresses.length > 0, "Whitelisted addresses cannot be empty");
        onlyWhitelistedAddressesCanCreateMarkets = true;
        for (uint256 index = 0; index < _whitelistedAddresses.length; index++) {
            whitelistedAddresses[_whitelistedAddresses[index]] = true;
        }
    }

    function disableWhitelistedAddresses() external onlyOwner {
        onlyWhitelistedAddressesCanCreateMarkets = false;
    }

    function enableWhitelistedAddresses() external onlyOwner {
        onlyWhitelistedAddressesCanCreateMarkets = true;
    }

    function addWhitelistedAddress(address _address) external onlyOwner {
        whitelistedAddresses[_address] = true;
    }

    function removeWhitelistedAddress(address _address) external onlyOwner {
        delete whitelistedAddresses[_address];
    }

    /* ========== VIEWS ========== */

    /* ---------- Market Information ---------- */

    function isKnownMarket(address candidate) public view override returns (bool) {
        return _activeMarkets.contains(candidate) || _maturedMarkets.contains(candidate);
    }

    function isActiveMarket(address candidate) public view override returns (bool) {
        return _activeMarkets.contains(candidate);
    }

    function numActiveMarkets() external view override returns (uint) {
        return _activeMarkets.elements.length;
    }

    function activeMarkets(uint index, uint pageSize) external view override returns (address[] memory) {
        return _activeMarkets.getPage(index, pageSize);
    }

    function numMaturedMarkets() external view override returns (uint) {
        return _maturedMarkets.elements.length;
    }

    function maturedMarkets(uint index, uint pageSize) external view override returns (address[] memory) {
        return _maturedMarkets.getPage(index, pageSize);
    }

    function _isValidKey(bytes32 oracleKey) internal view returns (bool) {
        // If it has a rate, then it's possibly a valid key
        if (priceFeed.rateForCurrency(oracleKey) != 0) {
            // But not sUSD
            if (oracleKey == "sUSD") {
                return false;
            }

            return true;
        }

        return false;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Setters ---------- */

    function setExpiryDuration(uint _expiryDuration) public onlyOwner {
        durations.expiryDuration = _expiryDuration;
        emit ExpiryDurationUpdated(_expiryDuration);
    }

    function setMaxTimeToMaturity(uint _maxTimeToMaturity) public onlyOwner {
        durations.maxTimeToMaturity = _maxTimeToMaturity;
        emit MaxTimeToMaturityUpdated(_maxTimeToMaturity);
    }

    function setCreatorCapitalRequirement(uint _creatorCapitalRequirement) public onlyOwner {
        capitalRequirement = _creatorCapitalRequirement;
        emit CreatorCapitalRequirementUpdated(_creatorCapitalRequirement);
    }

    function setPriceFeed(address _address) external onlyOwner {
        priceFeed = IPriceFeed(_address);
        emit SetPriceFeed(_address);
    }

    function setsUSD(address _address) external onlyOwner {
        sUSD = IERC20(_address);
        emit SetsUSD(_address);
    }

    /* ---------- Deposit Management ---------- */

    function incrementTotalDeposited(uint delta) external onlyActiveMarkets notPaused {
        totalDeposited = totalDeposited.add(delta);
    }

    function decrementTotalDeposited(uint delta) external onlyKnownMarkets notPaused {
        // NOTE: As individual market debt is not tracked here, the underlying markets
        //       need to be careful never to subtract more debt than they added.
        //       This can't be enforced without additional state/communication overhead.
        totalDeposited = totalDeposited.sub(delta);
    }

    /* ---------- Market Lifecycle ---------- */

    function createMarket(
        bytes32 oracleKey,
        uint strikePrice,
        uint maturity,
        uint initialMint, // initial sUSD to mint options for,
        bool customMarket,
        address customOracle
    )
        external
        override
        notPaused
        returns (
            IPositionalMarket // no support for returning PositionalMarket polymorphically given the interface
        )
    {
        require(marketCreationEnabled, "Market creation is disabled");
        if (!customMarket) {
            require(_isValidKey(oracleKey), "Invalid key");
        } else {
            if (!customMarketCreationEnabled) {
                require(owner == msg.sender, "Only owner can create custom markets");
            }
            require(address(0) != customOracle, "Invalid custom oracle");
        }

        if (onlyWhitelistedAddressesCanCreateMarkets) {
            require(whitelistedAddresses[msg.sender], "Only whitelisted addresses can create markets");
        }

        require(maturity <= block.timestamp + durations.maxTimeToMaturity, "Maturity too far in the future");
        uint expiry = maturity.add(durations.expiryDuration);

        require(block.timestamp < maturity, "Maturity has to be in the future");
        // We also require maturity < expiry. But there is no need to check this.
        // The market itself validates the capital and skew requirements.

        require(capitalRequirement <= initialMint, "Insufficient capital");

        PositionalMarket market =
            PositionalMarketFactory(positionalMarketFactory).createMarket(
                PositionalMarketFactory.PositionCreationMarketParameters(
                    msg.sender,
                    sUSD,
                    priceFeed,
                    oracleKey,
                    strikePrice,
                    [maturity, expiry],
                    initialMint,
                    customMarket,
                    customOracle
                )
            );

        _activeMarkets.add(address(market));

        // The debt can't be incremented in the new market's constructor because until construction is complete,
        // the manager doesn't know its address in order to grant it permission.
        totalDeposited = totalDeposited.add(initialMint);
        sUSD.transferFrom(msg.sender, address(market), _transformCollateral(initialMint));

        (IPosition up, IPosition down) = market.getOptions();

        emit MarketCreated(
            address(market),
            msg.sender,
            oracleKey,
            strikePrice,
            maturity,
            expiry,
            address(up),
            address(down),
            customMarket,
            customOracle
        );
        return market;
    }

    function transferSusdTo(
        address sender,
        address receiver,
        uint amount
    ) external override {
        //only to be called by markets themselves
        require(isKnownMarket(address(msg.sender)), "Market unknown.");
        bool success = sUSD.transferFrom(sender, receiver, amount);
        if (!success) {
            revert("TransferFrom function failed");
        }
    }

    function resolveMarket(address market) external override {
        require(_activeMarkets.contains(market), "Not an active market");
        PositionalMarket(market).resolve();
        _activeMarkets.remove(market);
        _maturedMarkets.add(market);
    }

    function expireMarkets(address[] calldata markets) external override notPaused onlyOwner {
        for (uint i = 0; i < markets.length; i++) {
            address market = markets[i];

            require(isKnownMarket(address(market)), "Market unknown.");

            // The market itself handles decrementing the total deposits.
            PositionalMarket(market).expire(payable(msg.sender));

            // Note that we required that the market is known, which guarantees
            // its index is defined and that the list of markets is not empty.
            _maturedMarkets.remove(market);

            emit MarketExpired(market);
        }
    }

    function setMarketCreationEnabled(bool enabled) external onlyOwner {
        if (enabled != marketCreationEnabled) {
            marketCreationEnabled = enabled;
            emit MarketCreationEnabledUpdated(enabled);
        }
    }

    function setCustomMarketCreationEnabled(bool enabled) external onlyOwner {
        customMarketCreationEnabled = enabled;
        emit SetCustomMarketCreationEnabled(enabled);
    }

    function setMigratingManager(PositionalMarketManager manager) external onlyOwner {
        _migratingManager = manager;
        emit SetMigratingManager(address(manager));
    }

    function migrateMarkets(
        PositionalMarketManager receivingManager,
        bool active,
        PositionalMarket[] calldata marketsToMigrate
    ) external onlyOwner {
        require(address(receivingManager) != address(this), "Can't migrate to self");

        uint _numMarkets = marketsToMigrate.length;
        if (_numMarkets == 0) {
            return;
        }
        AddressSetLib.AddressSet storage markets = active ? _activeMarkets : _maturedMarkets;

        uint runningDepositTotal;
        for (uint i; i < _numMarkets; i++) {
            PositionalMarket market = marketsToMigrate[i];
            require(isKnownMarket(address(market)), "Market unknown.");

            // Remove it from our list and deposit total.
            markets.remove(address(market));
            runningDepositTotal = runningDepositTotal.add(market.deposited());

            // Prepare to transfer ownership to the new manager.
            market.nominateNewOwner(address(receivingManager));
        }
        // Deduct the total deposits of the migrated markets.
        totalDeposited = totalDeposited.sub(runningDepositTotal);
        emit MarketsMigrated(receivingManager, marketsToMigrate);

        // Now actually transfer the markets over to the new manager.
        receivingManager.receiveMarkets(active, marketsToMigrate);
    }

    function receiveMarkets(bool active, PositionalMarket[] calldata marketsToReceive) external {
        require(msg.sender == address(_migratingManager), "Only permitted for migrating manager.");

        uint _numMarkets = marketsToReceive.length;
        if (_numMarkets == 0) {
            return;
        }
        AddressSetLib.AddressSet storage markets = active ? _activeMarkets : _maturedMarkets;

        uint runningDepositTotal;
        for (uint i; i < _numMarkets; i++) {
            PositionalMarket market = marketsToReceive[i];
            require(!isKnownMarket(address(market)), "Market already known.");

            market.acceptOwnership();
            markets.add(address(market));
            // Update the market with the new manager address,
            runningDepositTotal = runningDepositTotal.add(market.deposited());
        }
        totalDeposited = totalDeposited.add(runningDepositTotal);
        emit MarketsReceived(_migratingManager, marketsToReceive);
    }

    // support USDC with 6 decimals
    function transformCollateral(uint value) external view override returns (uint) {
        return _transformCollateral(value);
    }

    function _transformCollateral(uint value) internal view returns (uint) {
        if (needsTransformingCollateral) {
            return value / 1e12;
        } else {
            return value;
        }
    }

    function reverseTransformCollateral(uint value) external view override returns (uint) {
        if (needsTransformingCollateral) {
            return value * 1e12;
        } else {
            return value;
        }
    }

    /* ========== MODIFIERS ========== */

    modifier onlyActiveMarkets() {
        require(_activeMarkets.contains(msg.sender), "Permitted only for active markets.");
        _;
    }

    modifier onlyKnownMarkets() {
        require(isKnownMarket(msg.sender), "Permitted only for known markets.");
        _;
    }

    /* ========== EVENTS ========== */

    event MarketCreated(
        address market,
        address indexed creator,
        bytes32 indexed oracleKey,
        uint strikePrice,
        uint maturityDate,
        uint expiryDate,
        address up,
        address down,
        bool customMarket,
        address customOracle
    );
    event MarketExpired(address market);
    event MarketsMigrated(PositionalMarketManager receivingManager, PositionalMarket[] markets);
    event MarketsReceived(PositionalMarketManager migratingManager, PositionalMarket[] markets);
    event MarketCreationEnabledUpdated(bool enabled);
    event ExpiryDurationUpdated(uint duration);
    event MaxTimeToMaturityUpdated(uint duration);
    event CreatorCapitalRequirementUpdated(uint value);
    event SetPositionalMarketFactory(address _positionalMarketFactory);
    event SetZeroExAddress(address _zeroExAddress);
    event SetPriceFeed(address _address);
    event SetsUSD(address _address);
    event SetCustomMarketCreationEnabled(bool enabled);
    event SetMigratingManager(address manager);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

// Internal references
import "./Position.sol";
import "./PositionalMarket.sol";
import "./PositionalMarketFactory.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/IPositionalMarket.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-4.4.1/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PositionalMarketFactory is Initializable, ProxyOwned {
    /* ========== STATE VARIABLES ========== */
    address public positionalMarketManager;

    address public positionalMarketMastercopy;
    address public positionMastercopy;

    address public limitOrderProvider;
    address public thalesAMM;

    struct PositionCreationMarketParameters {
        address creator;
        IERC20 _sUSD;
        IPriceFeed _priceFeed;
        bytes32 oracleKey;
        uint strikePrice;
        uint[2] times; // [maturity, expiry]
        uint initialMint;
        bool customMarket;
        address customOracle;
    }

    /* ========== INITIALIZER ========== */

    function initialize(address _owner) external initializer {
        setOwner(_owner);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createMarket(PositionCreationMarketParameters calldata _parameters) external returns (PositionalMarket) {
        require(positionalMarketManager == msg.sender, "Only permitted by the manager.");

        PositionalMarket pom =
            PositionalMarket(
                Clones.clone(positionalMarketMastercopy)
            );
        Position up = Position(Clones.clone(positionMastercopy));
        Position down = Position(Clones.clone(positionMastercopy));
        pom.initialize(
            PositionalMarket.PositionalMarketParameters(
                positionalMarketManager,
                _parameters._sUSD,
                _parameters._priceFeed,
                _parameters.creator,
                _parameters.oracleKey,
                _parameters.strikePrice,
                _parameters.times,
                _parameters.initialMint,
                _parameters.customMarket,
                _parameters.customOracle,
                address(up),
                address(down),
                limitOrderProvider,
                thalesAMM
            )
        );
        emit MarketCreated(
            address(pom),
            _parameters.oracleKey,
            _parameters.strikePrice,
            _parameters.times[0],
            _parameters.times[1],
            _parameters.initialMint,
            _parameters.customMarket,
            _parameters.customOracle
        );
        return pom;
    }

    /* ========== SETTERS ========== */
    function setPositionalMarketManager(address _positionalMarketManager) external onlyOwner {
        positionalMarketManager = _positionalMarketManager;
        emit PositionalMarketManagerChanged(_positionalMarketManager);
    }

    function setPositionalMarketMastercopy(address _positionalMarketMastercopy) external onlyOwner {
        positionalMarketMastercopy = _positionalMarketMastercopy;
        emit PositionalMarketMastercopyChanged(_positionalMarketMastercopy);
    }

    function setPositionMastercopy(address _positionMastercopy) external onlyOwner {
        positionMastercopy = _positionMastercopy;
        emit PositionMastercopyChanged(_positionMastercopy);
    }

    function setLimitOrderProvider(address _limitOrderProvider) external onlyOwner {
        limitOrderProvider = _limitOrderProvider;
        emit SetLimitOrderProvider(_limitOrderProvider);
    }

    function setThalesAMM(address _thalesAMM) external onlyOwner {
        thalesAMM = _thalesAMM;
        emit SetThalesAMM(_thalesAMM);
    }

    event PositionalMarketManagerChanged(address _positionalMarketManager);
    event PositionalMarketMastercopyChanged(address _positionalMarketMastercopy);
    event PositionMastercopyChanged(address _positionMastercopy);
    event SetThalesAMM(address _thalesAMM);
    event SetLimitOrderProvider(address _limitOrderProvider);
    event MarketCreated(
        address market,
        bytes32 indexed oracleKey,
        uint strikePrice,
        uint maturityDate,
        uint expiryDate,
        uint initialMint,
        bool customMarket,
        address customOracle
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "../OwnedWithInit.sol";
import "../interfaces/IPositionalMarket.sol";
import "../interfaces/IOracleInstance.sol";

// Libraries
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
import "./PositionalMarketManager.sol";
import "./Position.sol";
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";

contract PositionalMarket is OwnedWithInit, IPositionalMarket {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;

    /* ========== TYPES ========== */

    struct Options {
        Position up;
        Position down;
    }

    struct Times {
        uint maturity;
        uint expiry;
    }

    struct OracleDetails {
        bytes32 key;
        uint strikePrice;
        uint finalPrice;
        bool customMarket;
        address iOracleInstanceAddress;
    }

    struct PositionalMarketParameters {
        address owner;
        IERC20 sUSD;
        IPriceFeed priceFeed;
        address creator;
        bytes32 oracleKey;
        uint strikePrice;
        uint[2] times; // [maturity, expiry]
        uint deposit; // sUSD deposit
        bool customMarket;
        address iOracleInstanceAddress;
        address up;
        address down;
        address limitOrderProvider;
        address thalesAMM;
    }

    /* ========== STATE VARIABLES ========== */

    Options public options;
    Times public override times;
    OracleDetails public oracleDetails;
    PositionalMarketManager.Fees public override fees;
    IPriceFeed public priceFeed;
    IERC20 public sUSD;

    IOracleInstance public iOracleInstance;
    bool public customMarket;

    // `deposited` tracks the sum of all deposits.
    // This must explicitly be kept, in case tokens are transferred to the contract directly.
    uint public override deposited;
    uint public initialMint;
    address public override creator;
    bool public override resolved;

    /* ========== CONSTRUCTOR ========== */

    bool public initialized = false;

    function initialize(PositionalMarketParameters calldata _parameters) external {
        require(!initialized, "Positional Market already initialized");
        initialized = true;
        initOwner(_parameters.owner);
        sUSD = _parameters.sUSD;
        priceFeed = _parameters.priceFeed;
        creator = _parameters.creator;

        oracleDetails = OracleDetails(
            _parameters.oracleKey,
            _parameters.strikePrice,
            0,
            _parameters.customMarket,
            _parameters.iOracleInstanceAddress
        );
        customMarket = _parameters.customMarket;
        iOracleInstance = IOracleInstance(_parameters.iOracleInstanceAddress);

        times = Times(_parameters.times[0], _parameters.times[1]);

        deposited = _parameters.deposit;
        initialMint = _parameters.deposit;

        // Instantiate the options themselves
        options.up = Position(_parameters.up);
        options.down = Position(_parameters.down);
        // abi.encodePacked("sUP: ", _oracleKey)
        // consider naming the option: sUpBTC>[email protected]
        options.up.initialize("Position Up", "UP", _parameters.limitOrderProvider, _parameters.thalesAMM);
        options.down.initialize("Position Down", "DOWN", _parameters.limitOrderProvider, _parameters.thalesAMM);
        _mint(creator, initialMint);

        // Note: the ERC20 base contract does not have a constructor, so we do not have to worry
        // about initializing its state separately
    }

    /* ---------- External Contracts ---------- */

    function _priceFeed() internal view returns (IPriceFeed) {
        return priceFeed;
    }

    function _manager() internal view returns (PositionalMarketManager) {
        return PositionalMarketManager(owner);
    }

    /* ---------- Phases ---------- */

    function _matured() internal view returns (bool) {
        return times.maturity < block.timestamp;
    }

    function _expired() internal view returns (bool) {
        return resolved && (times.expiry < block.timestamp || deposited == 0);
    }

    function phase() external view override returns (Phase) {
        if (!_matured()) {
            return Phase.Trading;
        }
        if (!_expired()) {
            return Phase.Maturity;
        }
        return Phase.Expiry;
    }

    /* ---------- Market Resolution ---------- */

    function _oraclePrice() internal view returns (uint price) {
        return _priceFeed().rateForCurrency(oracleDetails.key);
    }

    function _oraclePriceAndTimestamp() internal view returns (uint price, uint updatedAt) {
        return _priceFeed().rateAndUpdatedTime(oracleDetails.key);
    }

    function oraclePriceAndTimestamp() external view override returns (uint price, uint updatedAt) {
        return _oraclePriceAndTimestamp();
    }

    function oraclePrice() external view override returns (uint price) {
        return _oraclePrice();
    }

    function canResolve() public view override returns (bool) {
        if (customMarket) {
            return !resolved && _matured() && iOracleInstance.resolvable();
        } else {
            return !resolved && _matured();
        }
    }

    function _result() internal view returns (Side) {
        if (customMarket) {
            return iOracleInstance.getOutcome() ? Side.Up : Side.Down;
        } else {
            uint price;
            if (resolved) {
                price = oracleDetails.finalPrice;
            } else {
                price = _oraclePrice();
            }

            return oracleDetails.strikePrice <= price ? Side.Up : Side.Down;
        }
    }

    function result() external view override returns (Side) {
        return _result();
    }

    /* ---------- Option Balances and Mints ---------- */

    function _balancesOf(address account) internal view returns (uint up, uint down) {
        return (options.up.getBalanceOf(account), options.down.getBalanceOf(account));
    }

    function balancesOf(address account) external view override returns (uint up, uint down) {
        return _balancesOf(account);
    }

    function totalSupplies() external view override returns (uint up, uint down) {
        return (options.up.totalSupply(), options.down.totalSupply());
    }

    function getMaximumBurnable(address account) external view override returns (uint amount) {
        return _getMaximumBurnable(account);
    }

    function getOptions() external view override returns (IPosition up, IPosition down) {
        up = options.up;
        down = options.down;
    }

    function getOracleDetails()
        external
        view
        override
        returns (
            bytes32 key,
            uint strikePrice,
            uint finalPrice
        )
    {
        key = oracleDetails.key;
        strikePrice = oracleDetails.strikePrice;
        finalPrice = oracleDetails.finalPrice;
    }

    function _getMaximumBurnable(address account) internal view returns (uint amount) {
        (uint upBalance, uint downBalance) = _balancesOf(account);
        return (upBalance > downBalance) ? downBalance : upBalance;
    }

    /* ---------- Utilities ---------- */

    function _incrementDeposited(uint value) internal returns (uint _deposited) {
        _deposited = deposited.add(value);
        deposited = _deposited;
        _manager().incrementTotalDeposited(value);
    }

    function _decrementDeposited(uint value) internal returns (uint _deposited) {
        _deposited = deposited.sub(value);
        deposited = _deposited;
        _manager().decrementTotalDeposited(value);
    }

    function _requireManagerNotPaused() internal view {
        require(!_manager().paused(), "This action cannot be performed while the contract is paused");
    }

    function requireUnpaused() external view {
        _requireManagerNotPaused();
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Minting ---------- */

    function mint(uint value) external override duringMinting {
        if (value == 0) {
            return;
        }

        _mint(msg.sender, value);

        _incrementDeposited(value);
        _manager().transferSusdTo(msg.sender, address(this), _manager().transformCollateral(value));
    }

    function _mint(address minter, uint amount) internal {
        options.up.mint(minter, amount);
        options.down.mint(minter, amount);

        emit Mint(Side.Up, minter, amount);
        emit Mint(Side.Down, minter, amount);
    }

    function burnOptionsMaximum() external override {
        _burnOptions(msg.sender, _getMaximumBurnable(msg.sender));
    }

    function burnOptions(uint amount) external override {
        _burnOptions(msg.sender, amount);
    }

    function _burnOptions(address account, uint amount) internal {
        require(amount > 0, "Can not burn zero amount!");
        require(_getMaximumBurnable(account) >= amount, "There is not enough options!");

        // decrease deposit
        _decrementDeposited(amount);

        // decrease up and down options
        options.up.exerciseWithAmount(account, amount);
        options.down.exerciseWithAmount(account, amount);

        // transfer balance
        sUSD.transfer(account, _manager().transformCollateral(amount));

        // emit events
        emit OptionsBurned(account, amount);
    }

    /* ---------- Custom oracle configuration ---------- */
    function setIOracleInstance(address _address) external onlyOwner {
        iOracleInstance = IOracleInstance(_address);
        emit SetIOracleInstance(_address);
    }

    function setPriceFeed(address _address) external onlyOwner {
        priceFeed = IPriceFeed(_address);
        emit SetPriceFeed(_address);
    }

    function setsUSD(address _address) external onlyOwner {
        sUSD = IERC20(_address);
        emit SetsUSD(_address);
    }

    /* ---------- Market Resolution ---------- */

    function resolve() external onlyOwner afterMaturity managerNotPaused {
        require(canResolve(), "Can not resolve market");
        uint price;
        uint updatedAt;
        if (!customMarket) {
            (price, updatedAt) = _oraclePriceAndTimestamp();
            oracleDetails.finalPrice = price;
        }
        resolved = true;

        emit MarketResolved(_result(), price, updatedAt, deposited, 0, 0);
    }

    /* ---------- Claiming and Exercising Options ---------- */

    function exerciseOptions() external override afterMaturity returns (uint) {
        // The market must be resolved if it has not been.
        if (!resolved) {
            _manager().resolveMarket(address(this));
        }

        // If the account holds no options, revert.
        (uint upBalance, uint downBalance) = _balancesOf(msg.sender);
        require(upBalance != 0 || downBalance != 0, "Nothing to exercise");

        // Each option only needs to be exercised if the account holds any of it.
        if (upBalance != 0) {
            options.up.exercise(msg.sender);
        }
        if (downBalance != 0) {
            options.down.exercise(msg.sender);
        }

        // Only pay out the side that won.
        uint payout = (_result() == Side.Up) ? upBalance : downBalance;
        emit OptionsExercised(msg.sender, payout);
        if (payout != 0) {
            _decrementDeposited(payout);
            sUSD.transfer(msg.sender, _manager().transformCollateral(payout));
        }
        return payout;
    }

    /* ---------- Market Expiry ---------- */

    function _selfDestruct(address payable beneficiary) internal {
        uint _deposited = deposited;
        if (_deposited != 0) {
            _decrementDeposited(_deposited);
        }

        // Transfer the balance rather than the deposit value in case there are any synths left over
        // from direct transfers.
        uint balance = sUSD.balanceOf(address(this));
        if (balance != 0) {
            sUSD.transfer(beneficiary, balance);
        }

        // Destroy the option tokens before destroying the market itself.
        options.up.expire(beneficiary);
        options.down.expire(beneficiary);
        selfdestruct(beneficiary);
    }

    function expire(address payable beneficiary) external onlyOwner {
        require(_expired(), "Unexpired options remaining");
        emit Expired(beneficiary);
        _selfDestruct(beneficiary);
    }

    /* ========== MODIFIERS ========== */

    modifier duringMinting() {
        require(!_matured(), "Minting inactive");
        _;
    }

    modifier afterMaturity() {
        require(_matured(), "Not yet mature");
        _;
    }

    modifier managerNotPaused() {
        _requireManagerNotPaused();
        _;
    }

    /* ========== EVENTS ========== */

    event Mint(Side side, address indexed account, uint value);
    event MarketResolved(
        Side result,
        uint oraclePrice,
        uint oracleTimestamp,
        uint deposited,
        uint poolFees,
        uint creatorFees
    );

    event OptionsExercised(address indexed account, uint value);
    event OptionsBurned(address indexed account, uint value);
    event SetZeroExAddress(address _zeroExAddress);
    event SetZeroExAddressAtInit(address _zeroExAddress);
    event SetsUSD(address _address);
    event SetPriceFeed(address _address);
    event SetIOracleInstance(address _address);
    event Expired(address beneficiary);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "@openzeppelin/contracts-4.4.1/token/ERC20/IERC20.sol";
import "../interfaces/IPosition.sol";

// Libraries
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
import "./PositionalMarket.sol";

contract Position is IERC20, IPosition {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;

    /* ========== STATE VARIABLES ========== */

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    PositionalMarket public market;

    mapping(address => uint) public override balanceOf;
    uint public override totalSupply;

    // The argument order is allowance[owner][spender]
    mapping(address => mapping(address => uint)) private allowances;

    // Enforce a 1 cent minimum amount
    uint internal constant _MINIMUM_AMOUNT = 1e16;

    address public limitOrderProvider;
    address public thalesAMM;
    /* ========== CONSTRUCTOR ========== */

    bool public initialized = false;

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _limitOrderProvider,
        address _thalesAMM
    ) external {
        require(!initialized, "Positional Market already initialized");
        initialized = true;
        name = _name;
        symbol = _symbol;
        market = PositionalMarket(msg.sender);
        // add through constructor
        limitOrderProvider = _limitOrderProvider;
        thalesAMM = _thalesAMM;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        if (spender == limitOrderProvider || spender == thalesAMM) {
            return 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        } else {
            return allowances[owner][spender];
        }
    }

    function _requireMinimumAmount(uint amount) internal pure returns (uint) {
        require(amount >= _MINIMUM_AMOUNT || amount == 0, "Balance < $0.01");
        return amount;
    }

    function mint(address minter, uint amount) external onlyMarket {
        _requireMinimumAmount(amount);
        totalSupply = totalSupply.add(amount);
        balanceOf[minter] = balanceOf[minter].add(amount); // Increment rather than assigning since a transfer may have occurred.

        emit Transfer(address(0), minter, amount);
        emit Issued(minter, amount);
    }

    // This must only be invoked after maturity.
    function exercise(address claimant) external onlyMarket {
        uint balance = balanceOf[claimant];

        if (balance == 0) {
            return;
        }

        balanceOf[claimant] = 0;
        totalSupply = totalSupply.sub(balance);

        emit Transfer(claimant, address(0), balance);
        emit Burned(claimant, balance);
    }

    // This must only be invoked after maturity.
    function exerciseWithAmount(address claimant, uint amount) external onlyMarket {
        require(amount > 0, "Can not exercise zero amount!");

        require(balanceOf[claimant] >= amount, "Balance must be greather or equal amount that is burned");

        balanceOf[claimant] = balanceOf[claimant] - amount;
        totalSupply = totalSupply.sub(amount);

        emit Transfer(claimant, address(0), amount);
        emit Burned(claimant, amount);
    }

    // This must only be invoked after the exercise window is complete.
    // Note that any options which have not been exercised will linger.
    function expire(address payable beneficiary) external onlyMarket {
        selfdestruct(beneficiary);
    }

    /* ---------- ERC20 Functions ---------- */

    function _transfer(
        address _from,
        address _to,
        uint _value
    ) internal returns (bool success) {
        market.requireUnpaused();
        require(_to != address(0) && _to != address(this), "Invalid address");

        uint fromBalance = balanceOf[_from];
        require(_value <= fromBalance, "Insufficient balance");

        balanceOf[_from] = fromBalance.sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint _value) external override returns (bool success) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint _value
    ) external override returns (bool success) {
        if (msg.sender != limitOrderProvider && msg.sender != thalesAMM) {
            uint fromAllowance = allowances[_from][msg.sender];
            require(_value <= fromAllowance, "Insufficient allowance");
            allowances[_from][msg.sender] = fromAllowance.sub(_value);
        }
        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint _value) external override returns (bool success) {
        require(_spender != address(0));
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function getBalanceOf(address account) external view override returns (uint) {
        return balanceOf[account];
    }

    function getTotalSupply() external view override returns (uint) {
        return totalSupply;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyMarket() {
        require(msg.sender == address(market), "Only market allowed");
        _;
    }

    /* ========== EVENTS ========== */

    event Issued(address indexed account, uint value);
    event Burned(address indexed account, uint value);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IPositionalMarket.sol";

interface IOracleInstance {
    /* ========== VIEWS / VARIABLES ========== */

    function getOutcome() external view returns (bool);

    function resolvable() external view returns (bool);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "./Position.sol";
import "./PositionalMarket.sol";
import "./PositionalMarketManager.sol";

contract PositionalMarketData {
    struct OptionValues {
        uint up;
        uint down;
    }

    struct Deposits {
        uint deposited;
    }

    struct Resolution {
        bool resolved;
        bool canResolve;
    }

    struct OraclePriceAndTimestamp {
        uint price;
        uint updatedAt;
    }

    // used for things that don't change over the lifetime of the contract
    struct MarketParameters {
        address creator;
        PositionalMarket.Options options;
        PositionalMarket.Times times;
        PositionalMarket.OracleDetails oracleDetails;
        PositionalMarketManager.Fees fees;
    }

    struct MarketData {
        OraclePriceAndTimestamp oraclePriceAndTimestamp;
        Deposits deposits;
        Resolution resolution;
        PositionalMarket.Phase phase;
        PositionalMarket.Side result;
        OptionValues totalSupplies;
    }

    struct AccountData {
        OptionValues balances;
    }

    function getMarketParameters(PositionalMarket market) external view returns (MarketParameters memory) {
        (Position up, Position down) = market.options();
        (uint maturityDate, uint expiryDate) = market.times();
        (bytes32 key, uint strikePrice, uint finalPrice, bool customMarket, address iOracleInstanceAddress) = market
            .oracleDetails();
        (uint poolFee, uint creatorFee) = market.fees();

        MarketParameters memory data = MarketParameters(
            market.creator(),
            PositionalMarket.Options(up, down),
            PositionalMarket.Times(maturityDate, expiryDate),
            PositionalMarket.OracleDetails(key, strikePrice, finalPrice, customMarket, iOracleInstanceAddress),
            PositionalMarketManager.Fees(poolFee, creatorFee)
        );

        return data;
    }

    function getMarketData(PositionalMarket market) external view returns (MarketData memory) {
        (uint price, uint updatedAt) = market.oraclePriceAndTimestamp();
        (uint upSupply, uint downSupply) = market.totalSupplies();

        return
            MarketData(
                OraclePriceAndTimestamp(price, updatedAt),
                Deposits(market.deposited()),
                Resolution(market.resolved(), market.canResolve()),
                market.phase(),
                market.result(),
                OptionValues(upSupply, downSupply)
            );
    }

    function getAccountMarketData(PositionalMarket market, address account) external view returns (AccountData memory) {
        (uint upBalance, uint downBalance) = market.balancesOf(account);

        return AccountData(OptionValues(upBalance, downBalance));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "./PositionalMarket.sol";

contract PositionalMarketMastercopy is PositionalMarket {
    constructor() OwnedWithInit() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-4.4.1/proxy/Clones.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/proxy/solidity-0.8.0/ProxyPausable.sol";
import "../utils/libraries/AddressSetLib.sol";

contract Referrals is Initializable, ProxyOwned, ProxyPausable, ProxyReentrancyGuard {
    mapping(address => bool) public whitelistedAddresses;
    mapping(address => address) public referrals;
    mapping(address => uint) public referralStarted;

    mapping(address => bool) public tradedBefore;

    function initialize(
        address _owner,
        address thalesAmm,
        address rangedAMM
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        whitelistedAddresses[thalesAmm] = true;
        whitelistedAddresses[rangedAMM] = true;
    }

    function setReferrer(address referrer, address referred) external {
        require(referrer != address(0) && referred != address(0), "Cant refer zero addresses");
        require(referrer != referred, "Cant refer to yourself");
        require(
            whitelistedAddresses[msg.sender] || owner == msg.sender,
            "Only whitelisted addresses or owner set referrers"
        );
        if (!tradedBefore[referred] && referrals[referred] == address(0)) {
            referrals[referred] = referrer;
            referralStarted[referred] = block.timestamp;
            emit ReferralAdded(referrer, referred, block.timestamp);
        }
    }

    function setWhitelistedAddress(address _address, bool enabled) external onlyOwner {
        require(whitelistedAddresses[_address] != enabled, "Address already enabled/disabled");
        whitelistedAddresses[_address] = enabled;
        emit SetWhitelistedAddress(_address, enabled);
    }

    function setTradedBefore(address[] calldata _addresses) external onlyOwner {
        for (uint256 index = 0; index < _addresses.length; index++) {
            tradedBefore[_addresses[index]] = true;
            emit TradedBefore(_addresses[index]);
        }
    }

    event ReferralAdded(address referrer, address referred, uint timeStarted);
    event TradedBefore(address trader);
    event SetWhitelistedAddress(address whitelisted, bool enabled);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../interfaces/IExoticPositionalMarketManager.sol";
import "../interfaces/IExoticPositionalMarket.sol";

contract ExoticPositionalMarketData is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct MarketData {
        string marketQuestion;
        string marketSource;
        uint ticketType;
        uint endOfPositioning;
        uint fixedTicketPrice;
        uint creationTime;
        bool withdrawalAllowed;
        bool disputed;
        bool resolved;
        uint resolvedTime;
        string[] positionPhrasesList;
        uint[] tags;
        uint totalPlacedAmount;
        uint totalClaimableAmount;
        uint[] amountsPerPosition;
        bool canUsersPlacePosition;
        bool canMarketBeResolved;
        bool canMarketBeResolvedByPDAO;
        bool canUsersClaim;
        bool isCancelled;
        bool paused;
        uint winningPosition;
        address creatorAddress;
        address resolverAddress;
        uint fixedBondAmount;
        uint disputePrice;
        uint safeBoxLowAmount;
        uint arbitraryRewardForDisputor;
        uint backstopTimeout;
        uint disputeClosedTime;
        bool canCreatorCancelMarket;
        uint totalUsersTakenPositions;
        bool noWinners;
        bool canIssueFees;
        uint creatorFee;
        uint resolverFee;
        uint safeBoxFee;
        uint totalFee;
    }

    address public marketManagerAddress;

    function initialize(address _owner, address _marketManagerAddress) public initializer {
        setOwner(_owner);
        initNonReentrant();
        marketManagerAddress = _marketManagerAddress;
    }

    function setMarketManager(address _marketManagerAddress) external onlyOwner {
        require(_marketManagerAddress != address(0), "Invalid address");
        marketManagerAddress = _marketManagerAddress;
        emit NewMarketManagerAddress(_marketManagerAddress);
    }

    function getAllMarketData(address _market) external view returns (MarketData memory) {
        uint positionCount = IExoticPositionalMarket(_market).positionCount();
        IExoticPositionalMarket market = IExoticPositionalMarket(_market);
        MarketData memory marketData;
        marketData.marketQuestion = market.marketQuestion();
        marketData.marketSource = market.marketSource();
        marketData.ticketType = market.getTicketType();
        marketData.endOfPositioning = market.endOfPositioning();
        marketData.fixedTicketPrice = market.fixedTicketPrice();
        marketData.creationTime = market.creationTime();
        marketData.withdrawalAllowed = market.withdrawalAllowed();
        marketData.disputed = market.disputed();
        marketData.resolved = market.resolved();
        marketData.resolvedTime = market.resolvedTime();
        marketData.paused = market.paused();
        marketData.winningPosition = market.winningPosition();
        marketData.fixedBondAmount = market.fixedBondAmount();
        marketData.disputePrice = market.disputePrice();
        marketData.safeBoxLowAmount = market.safeBoxLowAmount();
        marketData.arbitraryRewardForDisputor = market.arbitraryRewardForDisputor();
        marketData.backstopTimeout = market.backstopTimeout();
        marketData.disputeClosedTime = market.disputeClosedTime();
        marketData.totalPlacedAmount = market.getTotalPlacedAmount();
        marketData.totalClaimableAmount = market.getTotalClaimableAmount();
        marketData.canUsersPlacePosition = market.canUsersPlacePosition();
        marketData.canMarketBeResolved = market.canMarketBeResolved();
        marketData.canMarketBeResolvedByPDAO = market.canMarketBeResolvedByPDAO();
        marketData.canUsersClaim = market.canUsersClaim();
        marketData.isCancelled = market.isMarketCancelled();
        marketData.creatorAddress = IExoticPositionalMarketManager(marketManagerAddress).creatorAddress(_market);
        marketData.resolverAddress = IExoticPositionalMarketManager(marketManagerAddress).resolverAddress(_market);
        marketData.canCreatorCancelMarket = market.canCreatorCancelMarket();
        marketData.tags = market.getTags();
        marketData.totalUsersTakenPositions = market.totalUsersTakenPositions();
        marketData.noWinners = market.noWinners();
        (marketData.creatorFee, marketData.resolverFee, marketData.safeBoxFee, marketData.totalFee) = market.getAllFees();
        marketData.canIssueFees = market.canIssueFees();

        string[] memory positionPhrasesList = new string[](positionCount);
        uint[] memory amountsPerPosition = new uint[](positionCount);
        if (positionCount > 0) {
            for (uint i = 1; i <= positionCount; i++) {
                positionPhrasesList[i - 1] = market.positionPhrase(i);
                amountsPerPosition[i - 1] = market.getPlacedAmountPerPosition(i);
            }
        }
        marketData.positionPhrasesList = positionPhrasesList;
        marketData.amountsPerPosition = amountsPerPosition;
        return marketData;
    }

    event NewMarketManagerAddress(address _marketManagerAddress);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// external
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// internal
import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

contract ExoticManagerData is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    using SafeMathUpgradeable for uint;

    uint public fixedBondAmount;
    uint public backstopTimeout;
    uint public minimumPositioningDuration;
    uint public claimTimeoutDefaultPeriod;
    uint public pDAOResolveTimePeriod;
    uint public safeBoxPercentage;
    uint public creatorPercentage;
    uint public resolverPercentage;
    uint public withdrawalPercentage;
    uint public maximumPositionsAllowed;
    uint public disputePrice;
    uint public maxOracleCouncilMembers;
    uint public maxNumberOfTags;
    uint public safeBoxLowAmount;
    uint public arbitraryRewardForDisputor;
    uint public minFixedTicketPrice;
    uint public disputeStringLengthLimit;
    uint public marketQuestionStringLimit;
    uint public marketSourceStringLimit;
    uint public marketPositionStringLimit;
    uint public withdrawalTimePeriod;
    uint public maxAmountForOpenBidPosition;
    uint public maxFinalWithdrawPercentage;

    bool public creationRestrictedToOwner;
    bool public openBidAllowed;

    address public exoticMarketMastercopy;
    address public exoticMarketOpenBidMastercopy;
    address public oracleCouncilAddress;
    address public safeBoxAddress;
    address public paymentToken;
    address public tagsAddress;
    address public theRundownConsumerAddress;
    address public marketDataAddress;
    address public exoticRewards;
    // address public thalesBonds;

    struct DummyStruct {
        uint fixedBondAmount;
        uint backstopTimeout;
        uint minimumPositioningDuration;
    }

    struct ManagerData {
        uint fixedBondAmount;
        uint backstopTimeout;
        uint minimumPositioningDuration;
        uint claimTimeoutDefaultPeriod;
        uint pDAOResolveTimePeriod;
        uint safeBoxPercentage;
        uint creatorPercentage;
        uint resolverPercentage;
        uint withdrawalPercentage;
        uint maximumPositionsAllowed;
        uint disputePrice;
        uint maxOracleCouncilMembers;
        uint maxNumberOfTags;
        uint safeBoxLowAmount;
        uint arbitraryRewardForDisputor;
        uint minFixedTicketPrice;
        uint disputeStringLengthLimit;
        uint marketQuestionStringLimit;
        uint marketSourceStringLimit;
        uint marketPositionStringLimit;
        uint withdrawalTimePeriod;
        uint maxAmountForOpenBidPosition;
        uint maxFinalWithdrawPercentage;
        bool creationRestrictedToOwner;
        bool openBidAllowed;
        address exoticMarketMastercopy;
        address exoticMarketOpenBidMastercopy;
        address oracleCouncilAddress;
        address safeBoxAddress;
        // address thalesBonds;
        address paymentToken;
        address tagsAddress;
        address theRundownConsumerAddress;
        address marketDataAddress;
        address exoticRewards;
    }

    function initialize(address _owner) public initializer {
        setOwner(_owner);
        initNonReentrant();
    }

    function setSafeBoxAddress(address _safeBoxAddress) external onlyOwner {
        require(_safeBoxAddress != address(0), "Invalid address");
        safeBoxAddress = _safeBoxAddress;
        emit NewSafeBoxAddress(_safeBoxAddress);
    }

    function setExoticMarketMastercopy(address _exoticMastercopy) external onlyOwner {
        require(_exoticMastercopy != address(0), "Exotic market invalid");
        exoticMarketMastercopy = _exoticMastercopy;
        emit ExoticMarketMastercopyChanged(_exoticMastercopy);
    }

    function setExoticMarketOpenBidMastercopy(address _exoticOpenBidMastercopy) external onlyOwner {
        require(_exoticOpenBidMastercopy != address(0), "Exotic market invalid");
        exoticMarketOpenBidMastercopy = _exoticOpenBidMastercopy;
        emit ExoticMarketOpenBidMastercopyChanged(_exoticOpenBidMastercopy);
    }

    function setExoticRewards(address _exoticRewards) external onlyOwner {
        require(_exoticRewards != address(0), "Exotic rewards invalid");
        exoticRewards = _exoticRewards;
        emit ExoticRewardsChanged(_exoticRewards);
    }

    function setMinimumPositioningDuration(uint _duration) external onlyOwner {
        minimumPositioningDuration = _duration;
        emit MinimumPositionDurationChanged(_duration);
    }

    function setSafeBoxPercentage(uint _safeBoxPercentage) external onlyOwner {
        safeBoxPercentage = _safeBoxPercentage;
        emit SafeBoxPercentageChanged(_safeBoxPercentage);
    }

    function setCreatorPercentage(uint _creatorPercentage) external onlyOwner {
        creatorPercentage = _creatorPercentage;
        emit CreatorPercentageChanged(_creatorPercentage);
    }

    function setResolverPercentage(uint _resolverPercentage) external onlyOwner {
        resolverPercentage = _resolverPercentage;
        emit ResolverPercentageChanged(_resolverPercentage);
    }

    function setWithdrawalPercentage(uint _withdrawalPercentage) external onlyOwner {
        withdrawalPercentage = _withdrawalPercentage;
        emit WithdrawalPercentageChanged(_withdrawalPercentage);
    }

    function setWithdrawalTimePeriod(uint _withdrawalTimePeriod) external onlyOwner {
        withdrawalTimePeriod = _withdrawalTimePeriod;
        emit WithdrawalTimePeriodChanged(_withdrawalTimePeriod);
    }

    function setMarketQuestionStringLimit(uint _marketQuestionStringLimit) external onlyOwner {
        marketQuestionStringLimit = _marketQuestionStringLimit;
        emit MarketQuestionStringLimitChanged(_marketQuestionStringLimit);
    }

    function setMarketSourceStringLimit(uint _marketSourceStringLimit) external onlyOwner {
        marketSourceStringLimit = _marketSourceStringLimit;
        emit MarketSourceStringLimitChanged(_marketSourceStringLimit);
    }

    function setMarketPositionStringLimit(uint _marketPositionStringLimit) external onlyOwner {
        marketPositionStringLimit = _marketPositionStringLimit;
        emit MarketSourceStringLimitChanged(_marketPositionStringLimit);
    }

    function setPDAOResolveTimePeriod(uint _pDAOResolveTimePeriod) external onlyOwner {
        pDAOResolveTimePeriod = _pDAOResolveTimePeriod;
        emit PDAOResolveTimePeriodChanged(_pDAOResolveTimePeriod);
    }

    function setOracleCouncilAddress(address _councilAddress) external onlyOwner {
        require(_councilAddress != address(0), "Invalid address");
        oracleCouncilAddress = _councilAddress;
        emit NewOracleCouncilAddress(_councilAddress);
    }

    function setMarketDataAddress(address _marketDataAddress) external onlyOwner {
        require(_marketDataAddress != address(0), "Invalid address");
        marketDataAddress = _marketDataAddress;
        emit NewMarketDataAddress(_marketDataAddress);
    }

    function setTheRundownConsumerAddress(address _theRundownConsumerAddress) external onlyOwner {
        require(_theRundownConsumerAddress != address(0), "Invalid address");
        theRundownConsumerAddress = _theRundownConsumerAddress;
        emit NewTheRundownConsumerAddress(_theRundownConsumerAddress);
    }

    function setMaximumPositionsAllowed(uint _maximumPositionsAllowed) external onlyOwner {
        require(_maximumPositionsAllowed > 2, "Invalid ");
        maximumPositionsAllowed = _maximumPositionsAllowed;
        emit NewMaximumPositionsAllowed(_maximumPositionsAllowed);
    }

    function setMinimumFixedTicketAmount(uint _minFixedTicketPrice) external onlyOwner {
        require(_minFixedTicketPrice != minFixedTicketPrice, "Invalid");
        minFixedTicketPrice = _minFixedTicketPrice;
        emit NewMinimumFixedTicketAmount(_minFixedTicketPrice);
    }

    function setMaxNumberOfTags(uint _maxNumberOfTags) external onlyOwner {
        require(_maxNumberOfTags > 2, "Invalid");
        maxNumberOfTags = _maxNumberOfTags;
        emit NewMaxNumberOfTags(_maxNumberOfTags);
    }

    function setDisputePrice(uint _disputePrice) external onlyOwner {
        require(_disputePrice > 0, "Invalid price");
        require(_disputePrice != disputePrice, "Equal to last");
        disputePrice = _disputePrice;
        emit NewDisputePrice(_disputePrice);
    }

    function setDefaultBackstopTimeout(uint _timeout) external onlyOwner {
        require(_timeout > 0, "Invalid timeout");
        require(_timeout != backstopTimeout, "Equal to last");
        backstopTimeout = _timeout;
        emit NewDefaultBackstopTimeout(_timeout);
    }

    function setFixedBondAmount(uint _bond) external onlyOwner {
        require(_bond > 0, "Invalid bond");
        require(_bond != fixedBondAmount, "Equal to last");
        fixedBondAmount = _bond;
        emit NewFixedBondAmount(_bond);
    }

    function setSafeBoxLowAmount(uint _safeBoxLowAmount) external onlyOwner {
        require(_safeBoxLowAmount > 0, "Invalid amount");
        require(_safeBoxLowAmount != safeBoxLowAmount, "Equal to last");
        require(_safeBoxLowAmount < disputePrice, "Higher than dispute price.");
        safeBoxLowAmount = _safeBoxLowAmount;
        emit NewSafeBoxLowAmount(_safeBoxLowAmount);
    }

    function setDisputeStringLengthLimit(uint _disputeStringLengthLimit) external onlyOwner {
        require(_disputeStringLengthLimit > 0, "Invalid amount");
        require(_disputeStringLengthLimit != disputeStringLengthLimit, "Equal to last");
        disputeStringLengthLimit = _disputeStringLengthLimit;
        emit NewDisputeStringLengthLimit(_disputeStringLengthLimit);
    }

    function setArbitraryRewardForDisputor(uint _arbitraryRewardForDisputor) external onlyOwner {
        require(_arbitraryRewardForDisputor > 0, "Invalid amount");
        require(_arbitraryRewardForDisputor != arbitraryRewardForDisputor, "Equal to last");
        arbitraryRewardForDisputor = _arbitraryRewardForDisputor;
        emit NewArbitraryRewardForDisputor(_arbitraryRewardForDisputor);
    }

    function setClaimTimeoutDefaultPeriod(uint _claimTimeout) external onlyOwner {
        require(_claimTimeout > 0, "Invalid timeout");
        require(_claimTimeout != claimTimeoutDefaultPeriod, "Equal to last");
        claimTimeoutDefaultPeriod = _claimTimeout;
        emit NewClaimTimeoutDefaultPeriod(_claimTimeout);
    }

    function setMaxOracleCouncilMembers(uint _maxOracleCouncilMembers) external onlyOwner {
        require(_maxOracleCouncilMembers > 3, "Number too low");
        maxOracleCouncilMembers = _maxOracleCouncilMembers;
        emit NewMaxOracleCouncilMembers(_maxOracleCouncilMembers);
    }

    function setCreationRestrictedToOwner(bool _creationRestrictedToOwner) external onlyOwner {
        require(_creationRestrictedToOwner != creationRestrictedToOwner, "Number too low");
        creationRestrictedToOwner = _creationRestrictedToOwner;
        emit CreationRestrictedToOwnerChanged(_creationRestrictedToOwner);
    }

    function setOpenBidAllowed(bool _openBidAllowed) external onlyOwner {
        openBidAllowed = _openBidAllowed;
        emit OpenBidAllowedChanged(_openBidAllowed);
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0), "Invalid address");
        paymentToken = _paymentToken;
        emit NewPaymentToken(_paymentToken);
    }

    function setTagsAddress(address _tagsAddress) external onlyOwner {
        require(_tagsAddress != address(0), "Invalid address");
        tagsAddress = _tagsAddress;
        emit NewTagsAddress(_tagsAddress);
    }

    function setMaxAmountForOpenBidPosition(uint _maxAmountForOpenBidPosition) external onlyOwner {
        require(_maxAmountForOpenBidPosition != maxAmountForOpenBidPosition, "Same value");
        maxAmountForOpenBidPosition = _maxAmountForOpenBidPosition;
        emit NewMaxAmountForOpenBidPosition(_maxAmountForOpenBidPosition);
    }

    function setMaxFinalWithdrawPercentage(uint _maxFinalWithdrawPercentage) external onlyOwner {
        require(maxFinalWithdrawPercentage != _maxFinalWithdrawPercentage, "Same value");
        maxFinalWithdrawPercentage = _maxFinalWithdrawPercentage;
        emit NewMaxFinalWithdrawPercentage(_maxFinalWithdrawPercentage);
    }

    function setManagerDummyData(DummyStruct memory _data) external {
        if (_data.fixedBondAmount != fixedBondAmount) {
            fixedBondAmount = _data.fixedBondAmount;
            emit NewFixedBondAmount(_data.fixedBondAmount);
        }
        if (_data.backstopTimeout != backstopTimeout) {
            backstopTimeout = _data.backstopTimeout;
            emit NewDefaultBackstopTimeout(_data.backstopTimeout);
        }

        if (_data.minimumPositioningDuration != minimumPositioningDuration) {
            minimumPositioningDuration = _data.minimumPositioningDuration;
            emit MinimumPositionDurationChanged(_data.minimumPositioningDuration);
        }
    }

    function setManagerData(ManagerData memory _data) external {
        if (_data.fixedBondAmount != fixedBondAmount) {
            fixedBondAmount = _data.fixedBondAmount;
            emit NewFixedBondAmount(_data.fixedBondAmount);
        }
        if (_data.backstopTimeout != backstopTimeout) {
            backstopTimeout = _data.backstopTimeout;
            emit NewDefaultBackstopTimeout(_data.backstopTimeout);
        }

        if (_data.minimumPositioningDuration != minimumPositioningDuration) {
            minimumPositioningDuration = _data.minimumPositioningDuration;
            emit MinimumPositionDurationChanged(_data.minimumPositioningDuration);
        }

        if (_data.claimTimeoutDefaultPeriod != claimTimeoutDefaultPeriod) {
            claimTimeoutDefaultPeriod = _data.claimTimeoutDefaultPeriod;
            emit NewClaimTimeoutDefaultPeriod(_data.claimTimeoutDefaultPeriod);
        }

        if (_data.pDAOResolveTimePeriod != pDAOResolveTimePeriod) {
            pDAOResolveTimePeriod = _data.pDAOResolveTimePeriod;
            emit PDAOResolveTimePeriodChanged(_data.pDAOResolveTimePeriod);
        }
        if (_data.safeBoxPercentage != safeBoxPercentage) {
            safeBoxPercentage = _data.safeBoxPercentage;
            emit SafeBoxPercentageChanged(_data.safeBoxPercentage);
        }

        if (_data.creatorPercentage != creatorPercentage) {
            creatorPercentage = _data.creatorPercentage;
            emit CreatorPercentageChanged(_data.creatorPercentage);
        }

        if (_data.resolverPercentage != resolverPercentage) {
            resolverPercentage = _data.resolverPercentage;
            emit ResolverPercentageChanged(_data.resolverPercentage);
        }

        if (_data.withdrawalPercentage != withdrawalPercentage) {
            withdrawalPercentage = _data.withdrawalPercentage;
            emit WithdrawalPercentageChanged(_data.withdrawalPercentage);
        }

        if (_data.maximumPositionsAllowed != maximumPositionsAllowed) {
            maximumPositionsAllowed = _data.maximumPositionsAllowed;
            emit NewMaximumPositionsAllowed(_data.maximumPositionsAllowed);
        }

        if (_data.disputePrice != disputePrice) {
            disputePrice = _data.disputePrice;
            emit NewDisputePrice(_data.disputePrice);
        }

        if (_data.maxOracleCouncilMembers != maxOracleCouncilMembers) {
            maxOracleCouncilMembers = _data.maxOracleCouncilMembers;
            emit NewMaxOracleCouncilMembers(_data.maxOracleCouncilMembers);
        }

        if (_data.maxNumberOfTags != maxNumberOfTags) {
            maxNumberOfTags = _data.maxNumberOfTags;
            emit NewMaxNumberOfTags(_data.maxNumberOfTags);
        }

        if (_data.maxNumberOfTags != maxNumberOfTags) {
            maxNumberOfTags = _data.maxNumberOfTags;
            emit NewMaxNumberOfTags(_data.maxNumberOfTags);
        }

        if (_data.safeBoxLowAmount != safeBoxLowAmount) {
            safeBoxLowAmount = _data.safeBoxLowAmount;
            emit NewSafeBoxLowAmount(_data.safeBoxLowAmount);
        }

        if (_data.arbitraryRewardForDisputor != arbitraryRewardForDisputor) {
            arbitraryRewardForDisputor = _data.arbitraryRewardForDisputor;
            emit NewArbitraryRewardForDisputor(_data.arbitraryRewardForDisputor);
        }

        if (_data.minFixedTicketPrice != minFixedTicketPrice) {
            minFixedTicketPrice = _data.minFixedTicketPrice;
            emit NewMinimumFixedTicketAmount(_data.minFixedTicketPrice);
        }

        if (_data.disputeStringLengthLimit != disputeStringLengthLimit) {
            disputeStringLengthLimit = _data.disputeStringLengthLimit;
            emit NewDisputeStringLengthLimit(_data.disputeStringLengthLimit);
        }

        if (_data.marketQuestionStringLimit != marketQuestionStringLimit) {
            marketQuestionStringLimit = _data.marketQuestionStringLimit;
            emit MarketQuestionStringLimitChanged(_data.marketQuestionStringLimit);
        }

        if (_data.marketSourceStringLimit != marketSourceStringLimit) {
            marketSourceStringLimit = _data.marketSourceStringLimit;
            emit MarketSourceStringLimitChanged(_data.marketSourceStringLimit);
        }

        if (_data.marketPositionStringLimit != marketPositionStringLimit) {
            marketPositionStringLimit = _data.marketPositionStringLimit;
            emit MarketPositionStringLimitChanged(_data.marketPositionStringLimit);
        }

        if (_data.withdrawalTimePeriod != withdrawalTimePeriod) {
            withdrawalTimePeriod = _data.withdrawalTimePeriod;
            emit WithdrawalTimePeriodChanged(_data.withdrawalTimePeriod);
        }

        if (_data.maxAmountForOpenBidPosition != maxAmountForOpenBidPosition) {
            maxAmountForOpenBidPosition = _data.maxAmountForOpenBidPosition;
            emit NewMaxAmountForOpenBidPosition(_data.maxAmountForOpenBidPosition);
        }

        if (_data.maxFinalWithdrawPercentage != maxFinalWithdrawPercentage) {
            maxFinalWithdrawPercentage = _data.maxFinalWithdrawPercentage;
            emit NewMaxFinalWithdrawPercentage(_data.maxFinalWithdrawPercentage);
        }

        if (_data.creationRestrictedToOwner != creationRestrictedToOwner) {
            creationRestrictedToOwner = _data.creationRestrictedToOwner;
            emit CreationRestrictedToOwnerChanged(_data.creationRestrictedToOwner);
        }

        if (_data.openBidAllowed != openBidAllowed) {
            openBidAllowed = _data.openBidAllowed;
            emit OpenBidAllowedChanged(_data.openBidAllowed);
        }

        if (_data.exoticMarketMastercopy != exoticMarketMastercopy && _data.exoticMarketMastercopy != address(0)) {
            exoticMarketMastercopy = _data.exoticMarketMastercopy;
            emit ExoticMarketMastercopyChanged(_data.exoticMarketMastercopy);
        }

        if (
            _data.exoticMarketOpenBidMastercopy != exoticMarketOpenBidMastercopy &&
            _data.exoticMarketOpenBidMastercopy != address(0)
        ) {
            exoticMarketOpenBidMastercopy = _data.exoticMarketOpenBidMastercopy;
            emit ExoticMarketOpenBidMastercopyChanged(_data.exoticMarketOpenBidMastercopy);
        }

        if (_data.oracleCouncilAddress != oracleCouncilAddress && _data.oracleCouncilAddress != address(0)) {
            oracleCouncilAddress = _data.oracleCouncilAddress;
            emit NewOracleCouncilAddress(_data.oracleCouncilAddress);
        }

        if (_data.paymentToken != paymentToken && _data.paymentToken != address(0)) {
            paymentToken = _data.paymentToken;
            emit NewPaymentToken(_data.paymentToken);
        }

        if (_data.tagsAddress != tagsAddress && _data.tagsAddress != address(0)) {
            tagsAddress = _data.tagsAddress;
            emit NewTagsAddress(_data.tagsAddress);
        }

        if (_data.theRundownConsumerAddress != theRundownConsumerAddress && _data.theRundownConsumerAddress != address(0)) {
            theRundownConsumerAddress = _data.theRundownConsumerAddress;
            emit NewTheRundownConsumerAddress(_data.theRundownConsumerAddress);
        }

        if (_data.exoticRewards != exoticRewards && _data.exoticRewards != address(0)) {
            exoticRewards = _data.exoticRewards;
            emit ExoticRewardsChanged(_data.exoticRewards);
        }

        if (_data.marketDataAddress != marketDataAddress && _data.marketDataAddress != address(0)) {
            marketDataAddress = _data.marketDataAddress;
            emit NewMarketDataAddress(_data.marketDataAddress);
        }
    }

    event NewFixedBondAmount(uint fixedBond);
    event NewDefaultBackstopTimeout(uint timeout);
    event MinimumPositionDurationChanged(uint duration);
    event NewClaimTimeoutDefaultPeriod(uint claimTimeout);
    event PDAOResolveTimePeriodChanged(uint pDAOResolveTimePeriod);
    event SafeBoxPercentageChanged(uint safeBoxPercentage);
    event CreatorPercentageChanged(uint creatorPercentage);
    event ResolverPercentageChanged(uint resolverPercentage);
    event WithdrawalPercentageChanged(uint withdrawalPercentage);
    event NewMaximumPositionsAllowed(uint maximumPositionsAllowed);
    event NewDisputePrice(uint disputePrice);
    event NewMaxOracleCouncilMembers(uint maxOracleCouncilMembers);
    event NewMaxNumberOfTags(uint maxNumberOfTags);
    event NewSafeBoxLowAmount(uint safeBoxLowAmount);
    event NewArbitraryRewardForDisputor(uint arbitraryRewardForDisputor);
    event NewMinimumFixedTicketAmount(uint minFixedTicketPrice);
    event NewDisputeStringLengthLimit(uint disputeStringLengthLimit);
    event MarketQuestionStringLimitChanged(uint marketQuestionStringLimit);
    event MarketSourceStringLimitChanged(uint marketSourceStringLimit);
    event MarketPositionStringLimitChanged(uint marketPositionStringLimit);
    event WithdrawalTimePeriodChanged(uint withdrawalTimePeriod);
    event NewMaxAmountForOpenBidPosition(uint maxAmountForOpenBidPosition);
    event NewMaxFinalWithdrawPercentage(uint maxFinalWithdrawPercentage);
    event CreationRestrictedToOwnerChanged(bool creationRestrictedToOwner);
    event OpenBidAllowedChanged(bool openBidAllowed);
    event ExoticMarketMastercopyChanged(address _exoticMastercopy);
    event ExoticMarketOpenBidMastercopyChanged(address exoticOpenBidMastercopy);
    event NewOracleCouncilAddress(address oracleCouncilAddress);
    event NewSafeBoxAddress(address safeBox);
    event NewTagsAddress(address tagsAddress);
    event NewPaymentToken(address paymentTokenAddress);
    event NewTheRundownConsumerAddress(address theRundownConsumerAddress);
    event ExoticRewardsChanged(address exoticRewards);
    event NewMarketDataAddress(address marketDataAddress);

    // event NewThalesBonds(address thalesBondsAddress);
    // event PauserAddressAdded(address pauserAddress);
    // event PauserAddressRemoved(address pauserAddress);
    // event MarketPaused(address marketAddress);
    // // event RewardSentToDisputorForMarket(address market, address disputorAddress, uint amount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "./RangedMarket.sol";

contract RangedMarketMastercopy is RangedMarket {
    constructor() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inheritance
import "./RangedPosition.sol";

contract RangedPositionMastercopy is RangedPosition {
    constructor() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Contracts
import "../utils/Owned.sol";

// Inheritance
import "../interfaces/IPriceFeed.sol";

// Libraries
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
// AggregatorInterface from Chainlink represents a decentralized pricing network for a single currency key
import "@chainlink/contracts-0.0.10/src/v0.5/interfaces/AggregatorV2V3Interface.sol";

contract MockPriceFeed is Owned, IPriceFeed {
    using SafeMath for uint;

    // Decentralized oracle networks that feed into pricing aggregators
    mapping(bytes32 => AggregatorV2V3Interface) public aggregators;
    mapping(bytes32 => uint8) public currencyKeyDecimals;

    // List of aggregator keys for convenient iteration
    bytes32[] public aggregatorKeys;

    uint public priceToReturn;
    uint public timestampToReturn;

    // ========== CONSTRUCTOR ==========
    constructor(address _owner) Owned(_owner) {}

    /* ========== MUTATIVE FUNCTIONS ========== */
    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external override onlyOwner {
        AggregatorV2V3Interface aggregator = AggregatorV2V3Interface(aggregatorAddress);
        // require(aggregator.latestRound() >= 0, "Given Aggregator is invalid");
        uint8 decimals = 18;
        require(decimals <= 18, "Aggregator decimals should be lower or equal to 18");
        if (address(aggregators[currencyKey]) == address(0)) {
            aggregatorKeys.push(currencyKey);
        }
        aggregators[currencyKey] = aggregator;
        currencyKeyDecimals[currencyKey] = decimals;
        emit AggregatorAdded(currencyKey, address(aggregator));
    }

    function removeAggregator(bytes32 currencyKey) external override onlyOwner {
        address aggregator = address(aggregators[currencyKey]);
        require(aggregator != address(0), "No aggregator exists for key");
        delete aggregators[currencyKey];
        delete currencyKeyDecimals[currencyKey];

        bool wasRemoved = removeFromArray(currencyKey, aggregatorKeys);

        if (wasRemoved) {
            emit AggregatorRemoved(currencyKey, aggregator);
        }
    }

    function getRates() external view override returns (uint[] memory rates) {
        uint count = 0;
        rates = new uint[](aggregatorKeys.length);
        for (uint i = 0; i < aggregatorKeys.length; i++) {
            bytes32 currencyKey = aggregatorKeys[i];
            rates[count++] =_getRateAndUpdatedTime(currencyKey).rate;
        }
    }

    function getCurrencies() external view override returns (bytes32[] memory) {
        return aggregatorKeys;
    }

    function rateForCurrency(bytes32 currencyKey) external view override returns (uint) {
        return _getRateAndUpdatedTime(currencyKey).rate;
    }

    function rateAndUpdatedTime(bytes32 currencyKey) external view override returns (uint rate, uint time) {
        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);
        return (rateAndTime.rate, rateAndTime.time);
    }

    function removeFromArray(bytes32 entry, bytes32[] storage array) internal returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == entry) {
                delete array[i];
                array[i] = array[array.length - 1];
                return true;
            }
        }
        return false;
    }

    function _formatAggregatorAnswer(bytes32 currencyKey, int256 rate) internal view returns (uint) {
        require(rate >= 0, "Negative rate not supported");
        if (currencyKeyDecimals[currencyKey] > 0) {
            uint multiplier = 10**uint(SafeMath.sub(18, currencyKeyDecimals[currencyKey]));
            return uint(uint(rate).mul(multiplier));
        }
        return uint(rate);
    }

    function _getRateAndUpdatedTime(bytes32 currencyKey) internal view returns (RateAndUpdatedTime memory) {
        return
            RateAndUpdatedTime({rate:  uint216(_formatAggregatorAnswer(currencyKey, int256(priceToReturn))), time: uint40(timestampToReturn)});
        
    }

    function setPricetoReturn(uint priceToSet) external {
        priceToReturn = priceToSet;
    }

    function setTimestamptoReturn(uint timestampToSet) external {
        timestampToReturn = timestampToSet;
    }

    /* ========== EVENTS ========== */
    event AggregatorAdded(bytes32 currencyKey, address aggregator);
    event AggregatorRemoved(bytes32 currencyKey, address aggregator);
}

pragma solidity >=0.5.0;

import "./AggregatorInterface.sol";
import "./AggregatorV3Interface.sol";

/**
 * @title The V2 & V3 Aggregator Interface
 * @notice Solidity V0.5 does not allow interfaces to inherit from other
 * interfaces so this contract is a combination of v0.5 AggregatorInterface.sol
 * and v0.5 AggregatorV3Interface.sol.
 */
interface AggregatorV2V3Interface {
  //
  // V2 Interface:
  //
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);

  //
  // V3 Interface:
  //
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

pragma solidity >=0.5.0;

interface AggregatorInterface {
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

pragma solidity >=0.5.0;

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

pragma solidity >=0.4.24;

import "./IVirtualSynth.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    // Views
    function calculateAmountAfterSettlement(
        address from,
        bytes32 currencyKey,
        uint amount,
        uint refunded
    ) external view returns (uint amountAfterSettlement);

    function isSynthRateInvalid(bytes32 currencyKey) external view returns (bool);

    function maxSecsLeftInWaitingPeriod(address account, bytes32 currencyKey) external view returns (uint);

    function settlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (
            uint reclaimAmount,
            uint rebateAmount,
            uint numEntries
        );

    function hasWaitingPeriodOrSettlementOwing(address account, bytes32 currencyKey) external view returns (bool);

    function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint exchangeFeeRate);

    function getAmountsForExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint amountReceived,
            uint fee,
            uint exchangeFeeRate
        );

    function priceDeviationThresholdFactor() external view returns (uint);

    function waitingPeriodSecs() external view returns (uint);

    // Mutative functions
    function exchange(
        address exchangeForAddress,
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bool virtualSynth,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived, IVirtualSynth vSynth);

    function settle(address from, bytes32 currencyKey)
        external
        returns (
            uint reclaimed,
            uint refunded,
            uint numEntries
        );

    function setLastExchangeRateForSynth(bytes32 currencyKey, uint rate) external;

    function resetLastExchangeRate(bytes32[] calldata currencyKeys) external;

    function suspendSynthWithInvalidRate(bytes32 currencyKey) external;
}

pragma solidity >=0.4.24;

import "./ISynth.sol";

interface IVirtualSynth {
    // Views
    function balanceOfUnderlying(address account) external view returns (uint);

    function rate() external view returns (uint);

    function readyToSettle() external view returns (bool);

    function secsLeftInWaitingPeriod() external view returns (uint);

    function settled() external view returns (bool);

    function synth() external view returns (ISynth);

    // Mutative functions
    function settle(address account) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ISynth {
    // Views
    function currencyKey() external view returns (bytes32);

    function transferableSynths(address account) external view returns (uint);

    // Mutative functions
    function transferAndSettle(address to, uint value) external returns (bool);

    function transferFromAndSettle(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Restricted: used internally to Synthetix
    function burn(address account, uint amount) external;

    function issue(address account, uint amount) external;
}

pragma solidity >=0.4.24;

import "../interfaces/ISynth.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iissuer
interface IIssuer {
    // Views
    function anySynthOrSNXRateIsInvalid() external view returns (bool anyRateInvalid);

    function availableCurrencyKeys() external view returns (bytes32[] memory);

    function availableSynthCount() external view returns (uint);

    function availableSynths(uint index) external view returns (ISynth);

    function canBurnSynths(address account) external view returns (bool);

    function collateral(address account) external view returns (uint);

    function collateralisationRatio(address issuer) external view returns (uint);

    function collateralisationRatioAndAnyRatesInvalid(address _issuer)
        external
        view
        returns (uint cratio, bool anyRateIsInvalid);

    function debtBalanceOf(address issuer, bytes32 currencyKey) external view returns (uint debtBalance);

    function issuanceRatio() external view returns (uint);

    function lastIssueEvent(address account) external view returns (uint);

    function maxIssuableSynths(address issuer) external view returns (uint maxIssuable);

    function minimumStakeTime() external view returns (uint);

    function remainingIssuableSynths(address issuer)
        external
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt
        );

    function synths(bytes32 currencyKey) external view returns (ISynth);

    function getSynths(bytes32[] calldata currencyKeys) external view returns (ISynth[] memory);

    function synthsByAddress(address synthAddress) external view returns (bytes32);

    function totalIssuedSynths(bytes32 currencyKey, bool excludeOtherCollateral) external view returns (uint);

    function transferableSynthetixAndAnyRateIsInvalid(address account, uint balance)
        external
        view
        returns (uint transferable, bool anyRateIsInvalid);

    // Restricted: used internally to Synthetix
    function issueSynths(address from, uint amount) external;

    function issueSynthsOnBehalf(
        address issueFor,
        address from,
        uint amount
    ) external;

    function issueMaxSynths(address from) external;

    function issueMaxSynthsOnBehalf(address issueFor, address from) external;

    function burnSynths(address from, uint amount) external;

    function burnSynthsOnBehalf(
        address burnForAddress,
        address from,
        uint amount
    ) external;

    function burnSynthsToTarget(address from) external;

    function burnSynthsToTargetOnBehalf(address burnForAddress, address from) external;

    function burnForRedemption(
        address deprecatedSynthProxy,
        address account,
        uint balance
    ) external;

    function liquidateDelinquentAccount(
        address account,
        uint susdAmount,
        address liquidator
    ) external returns (uint totalRedeemed, uint amountToLiquidate);
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/ierc20
interface IERC20 {
    // ERC20 Optional Views
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    // Views
    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    // Mutative functions
    function transfer(address to, uint value) external returns (bool);

    function approve(address spender, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Events
    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/isystemstatus
interface ISystemStatus {
    struct Status {
        bool canSuspend;
        bool canResume;
    }

    struct Suspension {
        bool suspended;
        // reason is an integer code,
        // 0 => no reason, 1 => upgrading, 2+ => defined by system usage
        uint248 reason;
    }

    // Views
    function accessControl(bytes32 section, address account) external view returns (bool canSuspend, bool canResume);

    function requireSystemActive() external view;

    function requireIssuanceActive() external view;

    function requireExchangeActive() external view;

    function requireExchangeBetweenSynthsAllowed(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view;

    function requireSynthActive(bytes32 currencyKey) external view;

    function requireSynthsActive(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view;

    function systemSuspension() external view returns (bool suspended, uint248 reason);

    function issuanceSuspension() external view returns (bool suspended, uint248 reason);

    function exchangeSuspension() external view returns (bool suspended, uint248 reason);

    function synthExchangeSuspension(bytes32 currencyKey) external view returns (bool suspended, uint248 reason);

    function synthSuspension(bytes32 currencyKey) external view returns (bool suspended, uint248 reason);

    function getSynthExchangeSuspensions(bytes32[] calldata synths)
        external
        view
        returns (bool[] memory exchangeSuspensions, uint256[] memory reasons);

    function getSynthSuspensions(bytes32[] calldata synths)
        external
        view
        returns (bool[] memory suspensions, uint256[] memory reasons);

    // Restricted functions
    function suspendSynth(bytes32 currencyKey, uint256 reason) external;

    function updateAccessControl(
        bytes32 section,
        address account,
        bool canSuspend,
        bool canResume
    ) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangestate
interface IExchangeState {
    // Views
    struct ExchangeEntry {
        bytes32 src;
        uint amount;
        bytes32 dest;
        uint amountReceived;
        uint exchangeFeeRate;
        uint timestamp;
        uint roundIdForSrc;
        uint roundIdForDest;
    }

    function getLengthOfEntries(address account, bytes32 currencyKey) external view returns (uint);

    function getEntryAt(
        address account,
        bytes32 currencyKey,
        uint index
    )
        external
        view
        returns (
            bytes32 src,
            uint amount,
            bytes32 dest,
            uint amountReceived,
            uint exchangeFeeRate,
            uint timestamp,
            uint roundIdForSrc,
            uint roundIdForDest
        );

    function getMaxTimestamp(address account, bytes32 currencyKey) external view returns (uint);

    // Mutative functions
    function appendExchangeEntry(
        address account,
        bytes32 src,
        uint amount,
        bytes32 dest,
        uint amountReceived,
        uint exchangeFeeRate,
        uint timestamp,
        uint roundIdForSrc,
        uint roundIdForDest
    ) external;

    function removeEntries(address account, bytes32 currencyKey) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getSynth(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >0.5.0;
pragma experimental ABIEncoderV2;

/**
 * @title iOVM_L1ERC20Bridge
 */
interface iOVM_L1ERC20Bridge {

    /**********
     * Events *
     **********/

    event ERC20DepositInitiated (
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event ERC20WithdrawalFinalized (
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    /********************
     * Public Functions *
     ********************/

    /**
     * @dev get the address of the corresponding L2 bridge contract.
     * @return Address of the corresponding L2 bridge contract.
     */
    function l2TokenBridge() external returns(address);

    /**
     * @dev deposit an amount of the ERC20 to the caller's balance on L2.
     * @param _l1Token Address of the L1 ERC20 we are depositing
     * @param _l2Token Address of the L1 respective L2 ERC20
     * @param _amount Amount of the ERC20 to deposit
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function depositERC20 (
        address _l1Token,
        address _l2Token,
        uint _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external;

    /**
     * @dev deposit an amount of ERC20 to a recipient's balance on L2.
     * @param _l1Token Address of the L1 ERC20 we are depositing
     * @param _l2Token Address of the L1 respective L2 ERC20
     * @param _to L2 address to credit the withdrawal to.
     * @param _amount Amount of the ERC20 to deposit.
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function depositERC20To (
        address _l1Token,
        address _l2Token,
        address _to,
        uint _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external;


    /*************************
     * Cross-chain Functions *
     *************************/

    /**
     * @dev Complete a withdrawal from L2 to L1, and credit funds to the recipient's balance of the
     * L1 ERC20 token.
     * This call will fail if the initialized withdrawal from L2 has not been finalized.
     *
     * @param _l1Token Address of L1 token to finalizeWithdrawal for.
     * @param _l2Token Address of L2 token where withdrawal was initiated.
     * @param _from L2 address initiating the transfer.
     * @param _to L1 address to credit the withdrawal to.
     * @param _amount Amount of the ERC20 to deposit.
     * @param _data Data provided by the sender on L2. This data is provided
     *   solely as a convenience for external contracts. Aside from enforcing a maximum
     *   length, these contracts provide no guarantees about its content.
     */
    function finalizeERC20Withdrawal (
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint _amount,
        bytes calldata _data
    )
        external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface ISNXRewards {
    /* ========== VIEWS / VARIABLES ========== */
    function collateralisationRatioAndAnyRatesInvalid(address account) external view returns (uint, bool);
    function debtBalanceOf(address _issuer, bytes32 currencyKey) external view returns (uint);
    function issuanceRatio() external view returns (uint);

    function setCRatio(address account, uint _c_ratio) external;
    function setIssuanceRatio(uint _issuanceRation) external;
    
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ISNXRewards.sol";

contract SNXRewards is ISNXRewards {

    mapping(address => uint) public c_ratio;
    mapping(address => uint) public debtBalance;
    uint public issuanceGeneralRatio;


    constructor() {}
    /* ========== VIEWS / VARIABLES ========== */
    function collateralisationRatioAndAnyRatesInvalid(address _account)
        external
        view
        override
        returns (uint, bool) {

        return (c_ratio[_account], false);
    }
    
    function debtBalanceOf(address _issuer, bytes32 currencyKey) external view override returns (uint) {
        // to silence compile warning
        currencyKey = currencyKey;
        return debtBalance[_issuer];
    }

    function issuanceRatio() external view override returns (uint) {
        return issuanceGeneralRatio;
    }

    function setCRatio(address account, uint _c_ratio) external override {
        c_ratio[account] = _c_ratio;
    }
    
    function setDebtBalance(address account, uint _debtBalance) external {
        debtBalance[account] = _debtBalance;
    }
    function setIssuanceRatio(uint _issuanceRation) external override {
        issuanceGeneralRatio = _issuanceRation;
    }
    
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/isystemsettings
interface ISystemSettings {
    // Views
    function priceDeviationThresholdFactor() external view returns (uint);

    function waitingPeriodSecs() external view returns (uint);

    function issuanceRatio() external view returns (uint);

    function feePeriodDuration() external view returns (uint);

    function targetThreshold() external view returns (uint);

    function liquidationDelay() external view returns (uint);

    function liquidationRatio() external view returns (uint);

    function liquidationPenalty() external view returns (uint);

    function rateStalePeriod() external view returns (uint);

    function exchangeFeeRate(bytes32 currencyKey) external view returns (uint);

    function minimumStakeTime() external view returns (uint);

    function etherWrapperMaxETH() external view returns (uint);

    function etherWrapperBurnFeeRate() external view returns (uint);

    function etherWrapperMintFeeRate() external view returns (uint);

    function minCratio(address collateral) external view returns (uint);

    function collateralManager(address collateral) external view returns (address);

    function interactionDelay(address collateral) external view returns (uint);
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/iflexiblestorage
interface IFlexibleStorage {
    // Views
    function getUIntValue(bytes32 contractName, bytes32 record) external view returns (uint);

    function getUIntValues(bytes32 contractName, bytes32[] calldata records) external view returns (uint[] memory);

    function getIntValue(bytes32 contractName, bytes32 record) external view returns (int);

    function getIntValues(bytes32 contractName, bytes32[] calldata records) external view returns (int[] memory);

    function getAddressValue(bytes32 contractName, bytes32 record) external view returns (address);

    function getAddressValues(bytes32 contractName, bytes32[] calldata records) external view returns (address[] memory);

    function getBoolValue(bytes32 contractName, bytes32 record) external view returns (bool);

    function getBoolValues(bytes32 contractName, bytes32[] calldata records) external view returns (bool[] memory);

    function getBytes32Value(bytes32 contractName, bytes32 record) external view returns (bytes32);

    function getBytes32Values(bytes32 contractName, bytes32[] calldata records) external view returns (bytes32[] memory);

    // Mutative functions
    function deleteUIntValue(bytes32 contractName, bytes32 record) external;

    function deleteIntValue(bytes32 contractName, bytes32 record) external;

    function deleteAddressValue(bytes32 contractName, bytes32 record) external;

    function deleteBoolValue(bytes32 contractName, bytes32 record) external;

    function deleteBytes32Value(bytes32 contractName, bytes32 record) external;

    function setUIntValue(
        bytes32 contractName,
        bytes32 record,
        uint value
    ) external;

    function setUIntValues(
        bytes32 contractName,
        bytes32[] calldata records,
        uint[] calldata values
    ) external;

    function setIntValue(
        bytes32 contractName,
        bytes32 record,
        int value
    ) external;

    function setIntValues(
        bytes32 contractName,
        bytes32[] calldata records,
        int[] calldata values
    ) external;

    function setAddressValue(
        bytes32 contractName,
        bytes32 record,
        address value
    ) external;

    function setAddressValues(
        bytes32 contractName,
        bytes32[] calldata records,
        address[] calldata values
    ) external;

    function setBoolValue(
        bytes32 contractName,
        bytes32 record,
        bool value
    ) external;

    function setBoolValues(
        bytes32 contractName,
        bytes32[] calldata records,
        bool[] calldata values
    ) external;

    function setBytes32Value(
        bytes32 contractName,
        bytes32 record,
        bytes32 value
    ) external;

    function setBytes32Values(
        bytes32 contractName,
        bytes32[] calldata records,
        bytes32[] calldata values
    ) external;
}

pragma solidity >=0.4.24;

import "./ISynth.sol";
import "./IVirtualSynth.sol";

// https://docs.synthetix.io/contracts/source/interfaces/isynthetix
interface ISynthetix {
    // Views
    function anySynthOrSNXRateIsInvalid() external view returns (bool anyRateInvalid);

    function availableCurrencyKeys() external view returns (bytes32[] memory);

    function availableSynthCount() external view returns (uint);

    function availableSynths(uint index) external view returns (ISynth);

    function collateral(address account) external view returns (uint);

    function collateralisationRatio(address issuer) external view returns (uint);

    function debtBalanceOf(address issuer, bytes32 currencyKey) external view returns (uint);

    function isWaitingPeriod(bytes32 currencyKey) external view returns (bool);

    function maxIssuableSynths(address issuer) external view returns (uint maxIssuable);

    function remainingIssuableSynths(address issuer)
        external
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt
        );

    function synths(bytes32 currencyKey) external view returns (ISynth);

    function synthsByAddress(address synthAddress) external view returns (bytes32);

    function totalIssuedSynths(bytes32 currencyKey) external view returns (uint);

    function totalIssuedSynthsExcludeOtherCollateral(bytes32 currencyKey) external view returns (uint);

    function transferableSynthetix(address account) external view returns (uint transferable);

    // Mutative Functions
    function burnSynths(uint amount) external;

    function burnSynthsOnBehalf(address burnForAddress, uint amount) external;

    function burnSynthsToTarget() external;

    function burnSynthsToTargetOnBehalf(address burnForAddress) external;

    function exchange(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);

    function exchangeOnBehalf(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);

    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);

    function exchangeWithTrackingForInitiator(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);

    function exchangeOnBehalfWithTracking(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);

    function exchangeWithVirtual(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        bytes32 trackingCode
    ) external returns (uint amountReceived, IVirtualSynth vSynth);

    function issueMaxSynths() external;

    function issueMaxSynthsOnBehalf(address issueForAddress) external;

    function issueSynths(uint amount) external;

    function issueSynthsOnBehalf(address issueForAddress, uint amount) external;

    function mint() external returns (bool);

    function settle(bytes32 currencyKey)
        external
        returns (
            uint reclaimed,
            uint refunded,
            uint numEntries
        );

    // Liquidations
    function liquidateDelinquentAccount(address account, uint susdAmount) external returns (bool);

    // Restricted Functions

    function mintSecondary(address account, uint amount) external;

    function mintSecondaryRewards(uint amount) external;

    function burnSecondary(address account, uint amount) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/itradingrewards
interface ITradingRewards {
    /* ========== VIEWS ========== */

    function getAvailableRewards() external view returns (uint);

    function getUnassignedRewards() external view returns (uint);

    function getRewardsToken() external view returns (address);

    function getPeriodController() external view returns (address);

    function getCurrentPeriod() external view returns (uint);

    function getPeriodIsClaimable(uint periodID) external view returns (bool);

    function getPeriodIsFinalized(uint periodID) external view returns (bool);

    function getPeriodRecordedFees(uint periodID) external view returns (uint);

    function getPeriodTotalRewards(uint periodID) external view returns (uint);

    function getPeriodAvailableRewards(uint periodID) external view returns (uint);

    function getUnaccountedFeesForAccountForPeriod(address account, uint periodID) external view returns (uint);

    function getAvailableRewardsForAccountForPeriod(address account, uint periodID) external view returns (uint);

    function getAvailableRewardsForAccountForPeriods(address account, uint[] calldata periodIDs)
        external
        view
        returns (uint totalRewards);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function claimRewardsForPeriod(uint periodID) external;

    function claimRewardsForPeriods(uint[] calldata periodIDs) external;

    /* ========== RESTRICTED FUNCTIONS ========== */

    function recordExchangeFeeForAccount(uint usdFeeAmount, address account) external;

    function closeCurrentPeriodWithRewards(uint rewards) external;

    function recoverTokens(address tokenAddress, address recoverAddress) external;

    function recoverUnassignedRewardTokens(address recoverAddress) external;

    function recoverAssignedRewardTokensAndDestroyPeriod(address recoverAddress, uint periodID) external;

    function setPeriodController(address newPeriodController) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/idelegateapprovals
interface IDelegateApprovals {
    // Views
    function canBurnFor(address authoriser, address delegate) external view returns (bool);

    function canIssueFor(address authoriser, address delegate) external view returns (bool);

    function canClaimFor(address authoriser, address delegate) external view returns (bool);

    function canExchangeFor(address authoriser, address delegate) external view returns (bool);

    // Mutative
    function approveAllDelegatePowers(address delegate) external;

    function removeAllDelegatePowers(address delegate) external;

    function approveBurnOnBehalf(address delegate) external;

    function removeBurnOnBehalf(address delegate) external;

    function approveIssueOnBehalf(address delegate) external;

    function removeIssueOnBehalf(address delegate) external;

    function approveClaimOnBehalf(address delegate) external;

    function removeClaimOnBehalf(address delegate) external;

    function approveExchangeOnBehalf(address delegate) external;

    function removeExchangeOnBehalf(address delegate) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/ifeepool
interface IFeePool {
    // Views

    // solhint-disable-next-line func-name-mixedcase
    function FEE_ADDRESS() external view returns (address);

    function feesAvailable(address account) external view returns (uint, uint);

    function feePeriodDuration() external view returns (uint);

    function isFeesClaimable(address account) external view returns (bool);

    function targetThreshold() external view returns (uint);

    function totalFeesAvailable() external view returns (uint);

    function totalRewardsAvailable() external view returns (uint);

    // Mutative Functions
    function claimFees() external returns (bool);

    function claimOnBehalf(address claimingForAddress) external returns (bool);

    function closeCurrentFeePeriod() external;

    // Restricted: used internally to Synthetix
    function appendAccountIssuanceRecord(
        address account,
        uint lockedAmount,
        uint debtEntryIndex
    ) external;

    function recordFeePaid(uint sUSDAmount) external;

    function setRewardsToDistribute(uint amount) external;
}

pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
    // Structs
    struct RateAndUpdatedTime {
        uint216 rate;
        uint40 time;
    }

    struct InversePricing {
        uint entryPoint;
        uint upperLimit;
        uint lowerLimit;
        bool frozenAtUpperLimit;
        bool frozenAtLowerLimit;
    }

    // Views
    function aggregators(bytes32 currencyKey) external view returns (address);

    function aggregatorWarningFlags() external view returns (address);

    function anyRateIsInvalid(bytes32[] calldata currencyKeys) external view returns (bool);

    function canFreezeRate(bytes32 currencyKey) external view returns (bool);

    function currentRoundForRate(bytes32 currencyKey) external view returns (uint);

    function currenciesUsingAggregator(address aggregator) external view returns (bytes32[] memory);

    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view returns (uint value);

    function effectiveValueAndRates(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint value,
            uint sourceRate,
            uint destinationRate
        );

    function effectiveValueAtRound(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        uint roundIdForSrc,
        uint roundIdForDest
    ) external view returns (uint value);

    function getCurrentRoundId(bytes32 currencyKey) external view returns (uint);

    function getLastRoundIdBeforeElapsedSecs(
        bytes32 currencyKey,
        uint startingRoundId,
        uint startingTimestamp,
        uint timediff
    ) external view returns (uint);

    function inversePricing(bytes32 currencyKey)
        external
        view
        returns (
            uint entryPoint,
            uint upperLimit,
            uint lowerLimit,
            bool frozenAtUpperLimit,
            bool frozenAtLowerLimit
        );

    function lastRateUpdateTimes(bytes32 currencyKey) external view returns (uint256);

    function oracle() external view returns (address);

    function rateAndTimestampAtRound(bytes32 currencyKey, uint roundId) external view returns (uint rate, uint time);

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time);

    function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);

    function rateForCurrency(bytes32 currencyKey) external view returns (uint);

    function rateIsFlagged(bytes32 currencyKey) external view returns (bool);

    function rateIsFrozen(bytes32 currencyKey) external view returns (bool);

    function rateIsInvalid(bytes32 currencyKey) external view returns (bool);

    function rateIsStale(bytes32 currencyKey) external view returns (bool);

    function rateStalePeriod() external view returns (uint);

    function ratesAndUpdatedTimeForCurrencyLastNRounds(bytes32 currencyKey, uint numRounds)
        external
        view
        returns (uint[] memory rates, uint[] memory times);

    function ratesAndInvalidForCurrencies(bytes32[] calldata currencyKeys)
        external
        view
        returns (uint[] memory rates, bool anyRateInvalid);

    function ratesForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint[] memory);

    // Mutative functions
    function freezeRate(bytes32 currencyKey) external;
}

pragma solidity >=0.5.0;

interface FlagsInterface {
  function getFlag(address) external view returns (bool);
  function getFlags(address[] calldata) external view returns (bool[] memory);
  function raiseFlag(address) external;
  function raiseFlags(address[] calldata) external;
  function lowerFlags(address[] calldata) external;
  function setRaisingAccessController(address) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";
import "../utils/libraries/UniswapMath.sol";

// Libraries
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";

// Internal references
// AggregatorInterface from Chainlink represents a decentralized pricing network for a single currency key
import "@chainlink/contracts-0.0.10/src/v0.5/interfaces/AggregatorV2V3Interface.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract PriceFeed is Initializable, ProxyOwned {
    using SafeMath for uint;

    // Decentralized oracle networks that feed into pricing aggregators
    mapping(bytes32 => AggregatorV2V3Interface) public aggregators;

    mapping(bytes32 => uint8) public currencyKeyDecimals;

    bytes32[] public aggregatorKeys;

    // List of currency keys for convenient iteration
    bytes32[] public currencyKeys;
    mapping(bytes32 => IUniswapV3Pool) public pools;

    int56 public twapInterval;

    struct RateAndUpdatedTime {
        uint216 rate;
        uint40 time;
    }

    address public _ETH;
    address public _wETH;

    mapping(bytes32 => bool) public useLastTickForTWAP;

    function initialize(address _owner) external initializer {
        setOwner(_owner);
        twapInterval = 300;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external onlyOwner {
        AggregatorV2V3Interface aggregator = AggregatorV2V3Interface(aggregatorAddress);
        require(aggregator.latestRound() >= 0, "Given Aggregator is invalid");
        uint8 decimals = aggregator.decimals();
        require(decimals <= 18, "Aggregator decimals should be lower or equal to 18");
        if (address(aggregators[currencyKey]) == address(0)) {
            currencyKeys.push(currencyKey);
        }
        aggregators[currencyKey] = aggregator;
        currencyKeyDecimals[currencyKey] = decimals;
        emit AggregatorAdded(currencyKey, address(aggregator));
    }

    function addPool(bytes32 currencyKey, address currencyAddress, address poolAddress) external onlyOwner {
        // check if aggregator exists for given currency key
        AggregatorV2V3Interface aggregator = aggregators[currencyKey];
        require(address(aggregator) == address(0), "Aggregator already exists for key");

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();
        bool token0valid = token0 == _wETH || token0 == _ETH;
        bool token1valid = token1 == _wETH || token1 == _ETH;

        // check if one of tokens is wETH or ETH
        require(token0valid || token1valid, "Pool not valid: ETH is not an asset");
        // check if currency is asset in given
        require(currencyAddress == token0 || currencyAddress == token1, "Pool not valid: currency is not an asset");
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        require(sqrtPriceX96 > 0, "Pool not valid");
        if (address(pools[currencyKey]) == address(0)) {
            currencyKeys.push(currencyKey);
        }
        pools[currencyKey] = pool;
        currencyKeyDecimals[currencyKey] = 18;
        emit PoolAdded(currencyKey, address(pool));
    }

    function removeAggregator(bytes32 currencyKey) external onlyOwner {
        address aggregator = address(aggregators[currencyKey]);
        require(aggregator != address(0), "No aggregator exists for key");
        delete aggregators[currencyKey];
        delete currencyKeyDecimals[currencyKey];

        bool wasRemoved = removeFromArray(currencyKey, currencyKeys);

        if (wasRemoved) {
            emit AggregatorRemoved(currencyKey, aggregator);
        }
    }

    function removePool(bytes32 currencyKey) external onlyOwner {
        address pool = address(pools[currencyKey]);
        require(pool != address(0), "No pool exists for key");
        delete pools[currencyKey];

        bool wasRemoved = removeFromArray(currencyKey, currencyKeys);
        if (wasRemoved) {
            emit PoolRemoved(currencyKey, pool);
        }
    }

    function getRates() external view returns (uint[] memory rates) {
        uint count = 0;
        rates = new uint[](currencyKeys.length);
        for (uint i = 0; i < currencyKeys.length; i++) {
            bytes32 currencyKey = currencyKeys[i];
            rates[count++] = _getRateAndUpdatedTime(currencyKey).rate;
        }
    }

    function getCurrencies() external view returns (bytes32[] memory) {
        return currencyKeys;
    }

    function rateForCurrency(bytes32 currencyKey) external view returns (uint) {
        return _getRateAndUpdatedTime(currencyKey).rate;
    }

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time) {
        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);
        return (rateAndTime.rate, rateAndTime.time);
    }

    function removeFromArray(bytes32 entry, bytes32[] storage array) internal returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == entry) {
                delete array[i];
                array[i] = array[array.length - 1];
                array.pop();
                return true;
            }
        }
        return false;
    }

    function setTwapInterval(int56 _twapInterval) external onlyOwner {
        twapInterval = _twapInterval;
        emit TwapIntervalChanged(_twapInterval);
    }

    function setLastTickForTWAP(bytes32 _currencyKey) external onlyOwner {
        useLastTickForTWAP[_currencyKey] = !useLastTickForTWAP[_currencyKey];
        emit LastTickForTWAPChanged(_currencyKey);
    }

    function setWETH(address token) external onlyOwner {
        _wETH = token;
        emit AddressChangedwETH(token);
    }

    function setETH(address token) external onlyOwner {
        _ETH = token;
        emit AddressChangedETH(token);
    }

    function _formatAnswer(bytes32 currencyKey, int256 rate) internal view returns (uint) {
        require(rate >= 0, "Negative rate not supported");
        if (currencyKeyDecimals[currencyKey] > 0) {
            uint multiplier = 10**uint(SafeMath.sub(18, currencyKeyDecimals[currencyKey]));
            return uint(uint(rate).mul(multiplier));
        }
        return uint(rate);
    }

    function _getRateAndUpdatedTime(bytes32 currencyKey) internal view returns (RateAndUpdatedTime memory) {
        AggregatorV2V3Interface aggregator = aggregators[currencyKey];
        IUniswapV3Pool pool = pools[currencyKey];
        require(address(aggregator) != address(0) || address(pool) != address(0), "No aggregator or pool exists for key");

        if (aggregator != AggregatorV2V3Interface(address(0))) {
            return _getAggregatorRate(address(aggregator), currencyKey);
        } else {
            require(address(aggregators["ETH"]) != address(0), "Price for ETH does not exist");
            uint256 ratio = _getPriceFromSqrtPrice(_getTwap(address(pool), currencyKey));
            uint256 ethPrice = _getAggregatorRate(address(aggregators["ETH"]), "ETH").rate * 10**18; 
            address token0 = pool.token0();
            uint answer;

            if(token0 == _ETH || token0 == _wETH) {
                answer = ethPrice / ratio;
            } else {
                answer = ethPrice * ratio;
            }
            return
                RateAndUpdatedTime({
                    rate: uint216(_formatAnswer(currencyKey, int256(answer))),
                    time: uint40(block.timestamp)
                });
        }
    }

    function _getAggregatorRate(address aggregator, bytes32 currencyKey) internal view returns (RateAndUpdatedTime memory ) {
        // this view from the aggregator is the most gas efficient but it can throw when there's no data,
        // so let's call it low-level to suppress any reverts
        bytes memory payload = abi.encodeWithSignature("latestRoundData()");
        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory returnData) = aggregator.staticcall(payload);

        if (success) {
            (, int256 answer, , uint256 updatedAt, ) = abi.decode(
                returnData,
                (uint80, int256, uint256, uint256, uint80)
            );
            return RateAndUpdatedTime({rate: uint216(_formatAnswer(currencyKey, answer)), time: uint40(updatedAt)});
        }

        // must return assigned value
        return RateAndUpdatedTime({rate: 0, time: 0});
    }

    function _getTwap(address pool, bytes32 currencyKey) internal view returns (uint160 sqrtPriceX96) {
        if (twapInterval == 0 || useLastTickForTWAP[currencyKey]) {
            // return the current price
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = uint32(uint56(twapInterval));
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);
            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = UniswapMath.getSqrtRatioAtTick(int24((tickCumulatives[1] - tickCumulatives[0]) / twapInterval));
        }
    }

    function _getPriceFromSqrtPrice(uint160 sqrtPriceX96) internal pure returns (uint256 priceX96) {
        uint256 price = UniswapMath.mulDiv(sqrtPriceX96, sqrtPriceX96, UniswapMath.Q96);
        return UniswapMath.mulDiv(price, 10**18, UniswapMath.Q96);
    }

    function transferCurrencyKeys() external onlyOwner {
        require(currencyKeys.length == 0, "Currency keys is not empty");
        for (uint i = 0; i < aggregatorKeys.length; i++) {
            currencyKeys[i] = aggregatorKeys[i];
        }
    }

    /* ========== EVENTS ========== */
    event AggregatorAdded(bytes32 currencyKey, address aggregator);
    event AggregatorRemoved(bytes32 currencyKey, address aggregator);
    event PoolAdded(bytes32 currencyKey, address pool);
    event PoolRemoved(bytes32 currencyKey, address pool);
    event AddressChangedETH(address token);
    event AddressChangedwETH(address token);
    event LastTickForTWAPChanged(bytes32 currencyKey);
    event TwapIntervalChanged(int56 twapInterval);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.4.1/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-4.4.1/utils/math/Math.sol";
import "@openzeppelin/contracts-4.4.1/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-4.4.1/security/ReentrancyGuard.sol";
import "../utils/Owned.sol";

contract VestingEscrow is ReentrancyGuard, Owned {
    using Math for uint256;
    using SafeMath for uint256;

    address public token;
    uint256 public startTime;
    uint256 public endTime;
    mapping(address => uint256) public initialLocked;
    mapping(address => uint256) public totalClaimed;

    uint256 public initialLockedSupply;
    uint256 public unallocatedSupply;

    constructor(
        address _owner,
        address _token,
        uint256 _startTime,
        uint256 _endTime
    ) Owned(_owner) {
        require(_startTime >= block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be greater than start time");

        token = _token;
        startTime = _startTime;
        endTime = _endTime;
    }

    function addTokens(uint256 _amount) external onlyOwner {
        require(ERC20(token).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        unallocatedSupply = unallocatedSupply.add(_amount);
    }

    function fund(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner {
        uint256 _totalAmount = 0;
        for (uint256 index = 0; index < _recipients.length; index++) {
            uint256 amount = _amounts[index];
            address recipient = _recipients[index];
            if (recipient == address(0)) {
                break;
            }
            _totalAmount = _totalAmount.add(amount);
            initialLocked[recipient] = initialLocked[recipient].add(amount);
            emit Fund(recipient, amount);
        }

        initialLockedSupply = initialLockedSupply.add(_totalAmount);
        unallocatedSupply = unallocatedSupply.sub(_totalAmount);
    }

    function _totalVestedOf(address _recipient, uint256 _time) internal view returns (uint256) {
        uint256 start = startTime;
        uint256 end = endTime;
        uint256 locked = initialLocked[_recipient];

        if (_time < start) return 0;
        return Math.min(locked.mul(_time.sub(start)).div(end.sub(start)), locked);
    }

    function _totalVested() internal view returns (uint256) {
        uint256 start = startTime;
        uint256 end = endTime;
        uint256 locked = initialLockedSupply;

        if (block.timestamp < start) {
            return 0;
        }

        return Math.min(locked.mul(block.timestamp.sub(start)).div(end.sub(start)), locked);
    }

    function vestedSupply() public view returns (uint256) {
        return _totalVested();
    }

    function vestedOf(address _recipient) public view returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp);
    }

    function lockedSupply() public view returns (uint256) {
        return initialLockedSupply.sub(_totalVested());
    }

    function balanceOf(address _recipient) public view returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp).sub(totalClaimed[_recipient]);
    }

    function lockedOf(address _recipient) public view returns (uint256) {
        return initialLocked[_recipient].sub(_totalVestedOf(_recipient, block.timestamp));
    }

    function _selfDestruct(address payable beneficiary) external onlyOwner {
        //only callable a year after end time
        require(block.timestamp > (endTime + 365 days), "Contract can only be selfdestruct a year after endtime");

        // Transfer the balance rather than the deposit value in case there are any synths left over
        // from direct transfers.
        IERC20(token).transfer(beneficiary, IERC20(token).balanceOf(address(this)));

        // Destroy the option tokens before destroying the market itself.
        selfdestruct(beneficiary);
    }

    function claim() external nonReentrant {
        uint256 claimable = balanceOf(msg.sender);
        require(claimable > 0, "nothing to claim");
        totalClaimed[msg.sender] = totalClaimed[msg.sender].add(claimable);
        require(ERC20(token).transfer(msg.sender, claimable));
        emit Claim(msg.sender, claimable);
    }

    event Fund(address indexed _recipient, uint256 _amount);
    event Claim(address indexed _address, uint256 _amount);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Internal references
import "./Position.sol";

contract PositionMastercopy is Position {
    constructor() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * Supported `sportId`
 * --------------------
 * NCAA Men's Football: 1
 * NFL: 2
 * MLB: 3
 * NBA: 4
 * NCAA Men's Basketball: 5
 * NHL: 6
 * WNBA: 8
 * MLS: 10
 * EPL: 11
 * Ligue 1: 12
 * Bundesliga: 13
 * La Liga: 14
 * Serie A: 15
 * UEFA Champions League: 16
 */

/**
 * Supported `market`
 * --------------------
 * create : Create Market
 * resolve : Resolve Market
 */

/**
 * Supported `statusIds`
 * --------------------
 * 1 : STATUS_CANCELED
 * 2 : STATUS_DELAYED
 * 3 : STATUS_END_OF_FIGHT
 * 4 : STATUS_END_OF_ROUND
 * 5 : STATUS_END_PERIOD
 * 6 : STATUS_FIGHTERS_INTRODUCTION
 * 7 : STATUS_FIGHTERS_WALKING
 * 8 : STATUS_FINAL
 * 9 : STATUS_FINAL_PEN
 * 10 : STATUS_FIRST_HALF
 * 11 : STATUS_FULL_TIME
 * 12 : STATUS_HALFTIME
 * 13 : STATUS_IN_PROGRESS
 * 14 : STATUS_IN_PROGRESS_2
 * 15 : STATUS_POSTPONED
 * 16 : STATUS_PRE_FIGHT
 * 17 : STATUS_RAIN_DELAY
 * 18 : STATUS_SCHEDULED
 * 19 : STATUS_SECOND_HALF
 * 20 : STATUS_TBD
 * 21 : STATUS_UNCONTESTED
 * 22 : STATUS_ABANDONED
 * 23 : STATUS_FORFEIT
 */

/**
 * @title A consumer contract for Therundown API.
 * @author LinkPool.
 * @dev Uses @chainlink/contracts 0.4.0.
 */

contract TherundownConsumerTest is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    /* ========== CONSUMER STATE VARIABLES ========== */

    struct GameCreate {
        bytes32 gameId;
        uint256 startTime;
        int24 homeOdds;
        int24 awayOdds;
        int24 drawOdds;
        string homeTeam;
        string awayTeam;
    }

    struct GameResolve {
        bytes32 gameId;
        uint8 homeScore;
        uint8 awayScore;
        uint8 statusId;
    }

    struct GameOdds {
        bytes32 gameId;
        int24 homeOdds;
        int24 awayOdds;
        int24 drawOdds;
    }

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _link the LINK token address.
     * @param _oracle the Operator.sol contract address.
     */
    constructor(address _link, address _oracle) {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
    }

    // Maps <RequestId, Result>
    mapping(bytes32 => bytes[]) public requestIdGames;

    /* ========== CONSUMER REQUEST FUNCTIONS ========== */

    /**
     * @notice Returns games for a given date.
     * @dev Result format is array of encoded tuples.
     * @param _specId the jobID.
     * @param _payment the LINK amount in Juels (i.e. 10^18 aka 1 LINK).
     * @param _market the type of games we want to query (create or resolve).
     * @param _sportId the sportId of the sport to query.
     * @param _date the date for the games to be queried (format in epoch).
     * @param _gameIds the IDs of the games to query (array of gameId).
     * @param _statusIds the IDs of the statuses to query (array of statusId).
     */

    function requestGamesResolveWithFilters(
        bytes32 _specId,
        uint256 _payment,
        string memory _market,
        uint256 _sportId,
        uint256 _date,
        string[] memory _statusIds,
        string[] memory _gameIds
    ) public {
        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillGames.selector);

        req.addUint("date", _date);
        req.add("market", _market);
        req.addUint("sportId", _sportId);
        req.addStringArray("statusIds", _statusIds);
        req.addStringArray("gameIds", _gameIds);
        sendChainlinkRequest(req, _payment);
    }

    function requestGames(
        bytes32 _specId,
        uint256 _payment,
        string memory _market,
        uint256 _sportId,
        uint256 _date
    ) public {
        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillGames.selector);

        req.addUint("date", _date);
        req.add("market", _market);
        req.addUint("sportId", _sportId);
        sendChainlinkRequest(req, _payment);
    }

    /* ========== CONSUMER FULFILL FUNCTIONS ========== */

    function fulfillGames(bytes32 _requestId, bytes[] memory _games) public recordChainlinkFulfillment(_requestId) {
        requestIdGames[_requestId] = _games;
    }

    /* ========== OTHER FUNCTIONS ========== */

    function getGamesCreated(bytes32 _requestId, uint256 _idx) external view returns (GameCreate memory) {
        GameCreate memory game = abi.decode(requestIdGames[_requestId][_idx], (GameCreate));
        return game;
    }

    function getGamesResolved(bytes32 _requestId, uint256 _idx) external view returns (GameResolve memory) {
        GameResolve memory game = abi.decode(requestIdGames[_requestId][_idx], (GameResolve));
        return game;
    }

    function getGamesOdds(bytes32 _requestId, uint256 _idx) external view returns (GameOdds memory) {
        GameOdds memory game = abi.decode(requestIdGames[_requestId][_idx], (GameOdds));
        return game;
    }

    function getOracleAddress() external view returns (address) {
        return chainlinkOracleAddress();
    }

    function setOracle(address _oracle) external {
        setChainlinkOracle(_oracle);
    }

    function withdrawLink() public {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IThalesRoyale.sol";

contract TestThalesRoyale is IThalesRoyale { 

    bool public participatedInLastRoyale;
    uint public buyInAmount;
    uint public override season;

    mapping(uint => uint) public override roundInASeason;
    mapping(uint => uint) public override tokenSeason;
    mapping(uint => bool) public override seasonFinished;
    mapping(uint => mapping(uint => uint)) public override roundResultPerSeason;
    mapping(uint => mapping(address => uint256)) public playerSignedUpPerSeason;
    mapping(uint => mapping(uint => uint256)) public tokensMintedPerSeason;
    mapping(uint => mapping(uint => uint)) public totalTokensPerRoundPerSeason;
    mapping(uint => mapping(uint256 => uint256)) public tokenPositionInARoundPerSeason;
    mapping(uint => IPassportPosition.Position[]) public tokenPositions;

    constructor() {}
    /* ========== VIEWS / VARIABLES ========== */

    function hasParticipatedInCurrentOrLastRoyale(address player) external view override returns (bool){
        // to silence compiler warning
        player = player;
        return participatedInLastRoyale;
    }

    function isTokenAliveInASpecificSeason(uint tokenId, uint _season) external view override returns (bool) {
        if (roundInASeason[_season] > 1) {
            return (tokenPositionInARoundPerSeason[tokenId][roundInASeason[_season] - 1] ==
                roundResultPerSeason[_season][roundInASeason[_season] - 1]);
        } else {
            return tokensMintedPerSeason[_season][tokenId] != 0;
        }
    }

    function setParticipatedInLastRoyale(bool _participated) external {
        participatedInLastRoyale = _participated;
    }

    function getBuyInAmount() external view override returns (uint){
        return buyInAmount;
    }

    function setBuyInAmount(uint _buyIn) external {
        buyInAmount = _buyIn;
    }

    function getTokenPositions(uint tokenId) public override view returns (IPassportPosition.Position[] memory) {
        return tokenPositions[tokenId];
    }
   
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title Multicall interface
/// @notice Enables calling multiple methods in a single call to the contract
interface IMulticall {
    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
    /// @dev The `msg.value` should not be trusted for any method callable from multicall.
    /// @param data The encoded function data for each of the calls to make to this contract
    /// @return results The results from each of the calls passed in via data
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}