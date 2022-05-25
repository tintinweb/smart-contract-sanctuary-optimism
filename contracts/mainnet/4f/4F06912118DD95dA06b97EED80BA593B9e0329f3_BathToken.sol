// SPDX-License-Identifier: BUSL-1.1

/// @author Rubicon DeFi Inc. - bghughes.eth
/// @notice This contract represents a single-asset liquidity pool for Rubicon Pools
/// @notice Any user can deposit assets into this pool and earn yield from successful strategist market making with their liquidity
/// @notice This contract looks to both BathPairs and the BathHouse as its admin

pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IBathHouse.sol";
import "../interfaces/IRubiconMarket.sol";
import "../interfaces/IVestingWallet.sol";

contract BathToken {
    using SafeMath for uint256;

    /// *** Storage Variables ***

    /// @notice The initialization status of the Bath Token
    bool public initialized;

    /// @notice  ** ERC-20 **
    string public symbol;
    string public name;
    uint8 public decimals;

    /// @notice The RubiconMarket.sol instance that all pool liquidity is intially directed to as market-making offers
    address public RubiconMarketAddress;

    /// @notice The Bath House admin of the Bath Token
    address public bathHouse;

    /// @notice The withdrawal fee recipient, typically the Bath Token itself
    address public feeTo;

    /// @notice The underlying ERC-20 token which is the core asset of the Bath Token vault
    IERC20 public underlyingToken;

    /// @notice The basis point fee rate that is paid on withdrawing the underlyingToken and bonusTokens
    uint256 public feeBPS;

    /// @notice ** ERC-20 **
    uint256 public totalSupply;

    /// @notice The amount of underlying deposits that are outstanding attempting market-making on the order book for yield
    /// @dev quantity of underlyingToken that is in the orderbook that the pool still has a claim on
    /// @dev The underlyingToken is effectively mark-to-marketed when it enters the book and it could be returned at a loss due to poor strategist performance
    /// @dev outstandingAmount is NOT inclusive of any non-underlyingToken assets sitting on the Bath Tokens that have filled to here and are awaiting rebalancing to the underlyingToken by strategists
    uint256 public outstandingAmount;

    /// @dev Intentionally unused DEPRECATED STORAGE VARIABLE to maintain contiguous state on proxy-wrapped contracts. Consider it a beautiful scar of incremental progress 📈
    /// @dev Keeping deprecated variables maintains consistent network-agnostic contract abis when moving to new chains and versions
    uint256[] deprecatedStorageArray; // Kept in to avoid storage collision bathTokens that are proxy upgraded

    /// @dev Intentionally unused DEPRECATED STORAGE VARIABLE to maintain contiguous state on proxy-wrapped contracts. Consider it a beautiful scar of incremental progress 📈
    mapping(uint256 => uint256) deprecatedMapping; // Kept in to avoid storage collision on bathTokens that are upgraded
    // *******************************************

    /// @notice  ** ERC-20 **
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice EIP-2612
    bytes32 public DOMAIN_SEPARATOR;

    /// @notice EIP-2612
    /// @dev keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice EIP-2612
    mapping(address => uint256) public nonces;

    /// @notice Array of Bonus ERC-20 tokens that are given as liquidity incentives to pool withdrawers
    address[] public bonusTokens;

    /// @notice Address of the OZ Vesting Wallet which acts as means to vest bonusToken incentives to pool HODLers
    IVestingWallet public rewardsVestingWallet;

    /// *** Events ***

    /// @notice ** ERC-20 **
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /// @notice ** ERC-20 **
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Time of Bath Token instantiation
    event LogInit(uint256 timeOfInit);

    /// @notice Log details about a pool deposit
    event LogDeposit(
        uint256 depositedAmt,
        IERC20 asset,
        uint256 sharesReceived,
        address depositor,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool withdraw
    event LogWithdraw(
        uint256 amountWithdrawn,
        IERC20 asset,
        uint256 sharesWithdrawn,
        address withdrawer,
        uint256 fee,
        address feeTo,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool rebalance
    event LogRebalance(
        IERC20 pool_asset,
        address destination,
        IERC20 transferAsset,
        uint256 rebalAmt,
        uint256 stratReward,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool order canceled in the Rubicon Market book
    event LogPoolCancel(
        uint256 orderId,
        IERC20 pool_asset,
        uint256 outstandingAmountToCancel,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool order placed in the Rubicon Market book
    event LogPoolOffer(
        uint256 id,
        IERC20 pool_asset,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log the credit to outstanding amount for funds that have been filled market-making
    event LogRemoveFilledTradeAmount(
        IERC20 pool_asset,
        uint256 fillAmount,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice * EIP 4626 *
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice * EIP 4626 *
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice Log bonus token reward event
    event LogClaimBonusTokn(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        IERC20 bonusToken
    );

    /// *** Constructor ***

    /// @notice Proxy-safe initialization of storage; the constructor
    function initialize(
        ERC20 token,
        address market,
        address _feeTo
    ) external {
        require(!initialized);
        string memory _symbol = string(
            abi.encodePacked(("bath"), token.symbol())
        );
        symbol = _symbol;
        underlyingToken = token;
        RubiconMarketAddress = market;
        bathHouse = msg.sender; //NOTE: assumed admin is creator on BathHouse

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        name = string(abi.encodePacked(_symbol, (" v1")));
        decimals = token.decimals(); // v1 Change - 4626 Adherence

        // Add infinite approval of Rubicon Market for this asset
        IERC20(address(token)).approve(RubiconMarketAddress, 2**256 - 1);
        emit LogInit(block.timestamp);

        feeTo = address(this); //This contract is the fee recipient, rewarding HODLers
        feeBPS = 3; //Fee set to 3 BPS initially

        // Complete constract instantiation
        initialized = true;
    }

    /// *** Modifiers ***

    modifier onlyPair() {
        require(
            IBathHouse(bathHouse).isApprovedPair(msg.sender) == true,
            "not an approved pair - bathToken"
        );
        _;
    }

    modifier onlyBathHouse() {
        require(
            msg.sender == bathHouse,
            "caller is not bathHouse - BathToken.sol"
        );
        _;
    }

    /// *** External Functions - Only Bath House / Admin ***

    /// @notice Admin-only function to set a Bath Token's market address
    function setMarket(address newRubiconMarket) external onlyBathHouse {
        RubiconMarketAddress = newRubiconMarket;
    }

    /// @notice Admin-only function to set a Bath Token's Bath House admin
    function setBathHouse(address newBathHouse) external onlyBathHouse {
        bathHouse = newBathHouse;
    }

    /// @notice Admin-only function to approve Bath Token's RubiconMarketAddress with the maximum integer value (infinite approval)
    function approveMarket() external onlyBathHouse {
        underlyingToken.approve(RubiconMarketAddress, 2**256 - 1);
    }

    /// @notice Admin-only function to set a Bath Token's feeBPS
    function setFeeBPS(uint256 _feeBPS) external onlyBathHouse {
        feeBPS = _feeBPS;
    }

    /// @notice Admin-only function to set a Bath Token's fee recipient, typically the pool itself
    function setFeeTo(address _feeTo) external onlyBathHouse {
        feeTo = _feeTo;
    }

    /// @notice Admin-only function to add a bonus token to bonusTokens for pool incentives
    function setBonusToken(address newBonusERC20) external onlyBathHouse {
        bonusTokens.push(newBonusERC20);
    }

    /// *** External Functions - Only Approved Bath Pair / Strategist Contract ***

    /// ** Rubicon Market Functions **

    /// @notice The function for a strategist to cancel an outstanding Market Offer
    function cancel(uint256 id, uint256 amt) external onlyPair {
        outstandingAmount = outstandingAmount.sub(amt);
        IRubiconMarket(RubiconMarketAddress).cancel(id);

        emit LogPoolCancel(
            id,
            IERC20(underlyingToken),
            amt,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// @notice A function called by BathPair to maintain proper accounting of outstandingAmount
    function removeFilledTradeAmount(uint256 amt) external onlyPair {
        outstandingAmount = outstandingAmount.sub(amt);
        emit LogRemoveFilledTradeAmount(
            IERC20(underlyingToken),
            amt,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// @notice The function that places a bid and/or ask in the orderbook for a given pair from this pool
    function placeOffer(
        uint256 pay_amt,
        ERC20 pay_gem,
        uint256 buy_amt,
        ERC20 buy_gem
    ) external onlyPair returns (uint256) {
        // Place an offer in RubiconMarket
        // If incomplete offer return 0
        if (
            pay_amt == 0 ||
            pay_gem == ERC20(0) ||
            buy_amt == 0 ||
            buy_gem == ERC20(0)
        ) {
            return 0;
        }

        uint256 id = IRubiconMarket(RubiconMarketAddress).offer(
            pay_amt,
            pay_gem,
            buy_amt,
            buy_gem,
            0,
            false
        );
        outstandingAmount = outstandingAmount.add(pay_amt);

        emit LogPoolOffer(
            id,
            IERC20(underlyingToken),
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        return (id);
    }

    /// @notice This function returns filled orders to the correct liquidity pool and sends strategist rewards to the Bath Pair
    /// @dev Sends non-underlyingToken fill elsewhere in the Pools system, typically it's sister asset within a trading pair (e.g. ETH-USDC)
    /// @dev Strategists presently accrue rewards in the filled asset not underlyingToken
    function rebalance(
        address destination,
        address filledAssetToRebalance, /* sister or fill asset */
        uint256 stratProportion,
        uint256 rebalAmt
    ) external onlyPair {
        uint256 stratReward = (stratProportion.mul(rebalAmt)).div(10000);
        IERC20(filledAssetToRebalance).transfer(
            destination,
            rebalAmt.sub(stratReward)
        );
        IERC20(filledAssetToRebalance).transfer(msg.sender, stratReward);

        emit LogRebalance(
            IERC20(underlyingToken),
            destination,
            IERC20(filledAssetToRebalance),
            rebalAmt,
            stratReward,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// *** EIP 4626 Implementation ***
    // https://eips.ethereum.org/EIPS/eip-4626#specification

    /// @notice Withdraw your bathTokens for the underlyingToken
    function withdraw(uint256 _shares)
        external
        returns (uint256 amountWithdrawn)
    {
        return _withdraw(_shares, msg.sender);
    }

    /// @notice * EIP 4626 *
    function asset() public view returns (address assetTokenAddress) {
        assetTokenAddress = address(underlyingToken);
    }

    /// @notice * EIP 4626 *
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        return underlyingBalance();
    }

    /// @notice * EIP 4626 *
    function convertToShares(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        // Note: Inflationary tokens may affect this logic
        (totalSupply == 0) ? shares = assets : shares = (
            assets.mul(totalSupply)
        )
        .div(totalAssets());
    }

    // Note: MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    /// @notice * EIP 4626 *
    function convertToAssets(uint256 shares)
        public
        view
        returns (uint256 assets)
    {
        assets = (totalAssets().mul(shares)).div(totalSupply);
    }

    // Note: Unused function param to adhere to standard
    /// @notice * EIP 4626 *
    function maxDeposit(address receiver)
        public
        pure
        returns (uint256 maxAssets)
    {
        maxAssets = 2**256 - 1; // No limit on deposits in current implementation  = Max UINT
    }

    /// @notice * EIP 4626 *
    function previewDeposit(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        // The exact same logic is used, no deposit fee - only difference is deflationary token check (rare condition and probably redundant)
        shares = convertToShares(assets);
    }

    // Single asset override to reflect old functionality
    function deposit(uint256 assets) public returns (uint256 shares) {
        // Note: msg.sender is the same throughout the same contract context
        return _deposit(assets, msg.sender);
    }

    /// @notice * EIP 4626 *
    function deposit(uint256 assets, address receiver)
        public
        returns (uint256 shares)
    {
        return _deposit(assets, receiver);
    }

    // Note: Unused function param to adhere to standard
    /// @notice * EIP 4626 *
    function maxMint(address receiver) public pure returns (uint256 maxShares) {
        maxShares = 2**256 - 1; // No limit on shares that could be created via deposit in current implementation - Max UINT
    }

    // Given I want these shares, how much do I have to deposit
    /// @notice * EIP 4626 *
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        (totalSupply == 0) ? assets = shares : assets = (
            shares.mul(totalAssets())
        )
        .div(totalSupply);
    }

    // Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
    /// @notice * EIP 4626 *
    function mint(uint256 shares, address receiver)
        public
        returns (uint256 assets)
    {
        assets = previewMint(shares);
        uint256 _shares = _deposit(assets, receiver);
        require(_shares == shares, "did not mint expected share count");
    }

    // A user can withdraw whatever they hold
    /// @notice * EIP 4626 *
    function maxWithdraw(address owner)
        public
        view
        returns (uint256 maxAssets)
    {
        if (totalSupply == 0) {
            maxAssets = 0;
        } else {
            uint256 ownerShares = balanceOf[owner];
            maxAssets = convertToAssets(ownerShares);
        }
    }

    /// @notice * EIP 4626 *
    function previewWithdraw(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        if (totalSupply == 0) {
            shares = 0;
        } else {
            uint256 amountWithdrawn;
            uint256 _fee = assets.mul(feeBPS).div(10000);
            amountWithdrawn = assets.sub(_fee);
            shares = convertToShares(amountWithdrawn);
        }
    }

    /// @notice * EIP 4626 *
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public returns (uint256 shares) {
        require(
            owner == msg.sender,
            "This implementation does not support non-sender owners from withdrawing user shares"
        );
        uint256 expectedShares = previewWithdraw(assets);
        uint256 assetsReceived = _withdraw(expectedShares, receiver);
        require(
            assetsReceived >= assets,
            "You cannot withdraw the amount of assets you expected"
        );
        shares = expectedShares;
    }

    // Constraint: msg.sender is owner of shares when withdrawing
    /// @notice * EIP 4626 *
    function maxRedeem(address owner) public view returns (uint256 maxShares) {
        return balanceOf[owner];
    }

    // Constraint: msg.sender is owner of shares when withdrawing
    /// @notice * EIP 4626 *
    function previewRedeem(uint256 shares)
        public
        view
        returns (uint256 assets)
    {
        uint256 r = (underlyingBalance().mul(shares)).div(totalSupply);
        uint256 _fee = r.mul(feeBPS).div(10000);
        assets = r.sub(_fee);
    }

    /// @notice * EIP 4626 *
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public returns (uint256 assets) {
        require(
            owner == msg.sender,
            "This implementation does not support non-sender owners from withdrawing user shares"
        );
        assets = _withdraw(shares, receiver);
    }

    /// *** Internal Functions ***

    /// @notice Deposit assets for the user and mint Bath Token shares to receiver
    function _deposit(uint256 assets, address receiver)
        internal
        returns (uint256 shares)
    {
        uint256 _pool = underlyingBalance();
        uint256 _before = underlyingToken.balanceOf(address(this));

        // **Assume caller is depositor**
        underlyingToken.transferFrom(msg.sender, address(this), assets);
        uint256 _after = underlyingToken.balanceOf(address(this));
        assets = _after.sub(_before); // Additional check for deflationary tokens

        (totalSupply == 0) ? shares = assets : shares = (
            assets.mul(totalSupply)
        )
        .div(_pool);


        // Send shares to designated target
        _mint(receiver, shares);
        emit LogDeposit(
            assets,
            underlyingToken,
            shares,
            msg.sender,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        emit Deposit(msg.sender, msg.sender, assets, shares);
    }

    /// @notice Withdraw share for the user and send underlyingToken to receiver with any accrued yield and incentive tokens
    function _withdraw(uint256 _shares, address receiver)
        internal
        returns (uint256 amountWithdrawn)
    {
        uint256 _initialTotalSupply = totalSupply;

        // Distribute network rewards first in order to handle bonus token == underlying token case; it only releases vested tokens in this call
        distributeBonusTokenRewards(receiver, _shares, _initialTotalSupply);

        uint256 r = (underlyingBalance().mul(_shares)).div(_initialTotalSupply);
        _burn(msg.sender, _shares);
        uint256 _fee = r.mul(feeBPS).div(10000);
        // If FeeTo == address(0) then the fee is effectively accrued by the pool
        if (feeTo != address(0)) {
            underlyingToken.transfer(feeTo, _fee);
        }
        amountWithdrawn = r.sub(_fee);
        underlyingToken.transfer(receiver, amountWithdrawn);

        emit LogWithdraw(
            amountWithdrawn,
            underlyingToken,
            _shares,
            msg.sender,
            _fee,
            feeTo,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        emit Withdraw(
            msg.sender,
            receiver,
            msg.sender,
            amountWithdrawn,
            _shares
        );
    }

    /// @notice Function to distibute non-underlyingToken Bath Token incentives to pool withdrawers
    /// @dev Note that bonusTokens adhere to the same feeTo and feeBPS pattern
    /// @dev Note the edge case in which the bonus token is the underlyingToken, here we simply release() to the pool and skip
    function distributeBonusTokenRewards(
        address receiver,
        uint256 sharesWithdrawn,
        uint256 initialTotalSupply
    ) internal {
        // Verbose check:
        // require(initialTotalSupply == sharesWithdrawn + totalSupply);
        if (bonusTokens.length > 0) {
            for (uint256 index = 0; index < bonusTokens.length; index++) {
                IERC20 token = IERC20(bonusTokens[index]);

                // Pair each bonus token with an OZ Vesting wallet. Each time a user withdraws, they can release() the
                //  vested amount to this pool. Note, this pool must be the beneficiary of the VestingWallet.
                if (rewardsVestingWallet != IVestingWallet(0)) {
                    rewardsVestingWallet.release(address(token));
                }

                // avoid underlyingToken == token double spend
                if (address(token) == address(underlyingToken)) {
                    continue; // Skip because logic below fails on underlying token and release() already called so bonus tokens are already accrued and withdrawn
                }

                uint256 bonusTokenBalance = token.balanceOf(address(this));
                if (bonusTokenBalance > 0) {
                    uint256 amount = bonusTokenBalance.mul(sharesWithdrawn).div(
                        initialTotalSupply
                    );
                    // Note: Shares already burned in _withdraw

                    uint256 _fee = amount.mul(feeBPS).div(10000);
                    // If FeeTo == address(0) then the fee is effectively accrued by the pool
                    if (feeTo != address(0)) {
                        token.transfer(feeTo, _fee);
                    }
                    uint256 amountWithdrawn = amount.sub(_fee);
                    token.transfer(receiver, amountWithdrawn);

                    emit LogClaimBonusTokn(
                        msg.sender,
                        receiver,
                        msg.sender,
                        amountWithdrawn,
                        sharesWithdrawn,
                        token
                    );
                }
            }
        }
    }

    /// *** ERC - 20 Standard ***

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(
                value
            );
        }
        _transfer(from, to, value);
        return true;
    }

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "bathToken: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "bathToken: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }

    /// *** View Functions ***

    /// @notice The underlying ERC-20 that this bathToken handles
    function underlyingERC20() external view returns (address) {
        return address(underlyingToken);
    }

    /// @notice The best-guess total claim on assets the Bath Token has
    /// @dev returns the amount of underlying ERC20 tokens in this pool in addition to any tokens that are outstanding in the Rubicon order book seeking market-making yield (outstandingAmount)
    function underlyingBalance() public view returns (uint256) {
        uint256 _pool = IERC20(underlyingToken).balanceOf(address(this));
        return _pool.add(outstandingAmount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

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
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
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
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
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

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

interface IBathHouse {
    function getMarket() external view returns (address);

    function initialized() external returns (bool);

    function reserveRatio() external view returns (uint256);

    function tokenToBathToken(address erc20Address)
        external
        view
        returns (address bathTokenAddress);

    function isApprovedStrategist(address wouldBeStrategist)
        external
        view
        returns (bool);

    function getBPSToStrats() external view returns (uint8);

    function isApprovedPair(address pair) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRubiconMarket {
    function cancel(uint256 id) external;

    function offer(
        uint256 pay_amt, //maker (ask) sell how much
        IERC20 pay_gem, //maker (ask) sell which token
        uint256 buy_amt, //maker (ask) buy how much
        IERC20 buy_gem, //maker (ask) buy which token
        uint256 pos, //position to insert offer, 0 should be used if unknown
        bool matching //match "close enough" orders?
    ) external returns (uint256);

    // Get best offer
    function getBestOffer(IERC20 sell_gem, IERC20 buy_gem)
        external
        view
        returns (uint256);

    // get offer
    function getOffer(uint256 id)
        external
        view
        returns (
            uint256,
            IERC20,
            uint256,
            IERC20
        );
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;

interface IVestingWallet {
    function beneficiary() external view returns (address);

    function release(address token) external;

    function vestedAmount(address token, uint64 timestamp)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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