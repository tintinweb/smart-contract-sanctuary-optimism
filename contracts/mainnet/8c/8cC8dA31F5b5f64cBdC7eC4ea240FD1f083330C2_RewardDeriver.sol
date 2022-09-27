// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { IRewardDeriver } from "./IRewardDeriver.sol";
import {
    Order,
    AdditionalRecipient,
    ConsiderationItem
} from "../lib/seaport/lib/ConsiderationStructs.sol";
import { ItemType } from "../lib/seaport/lib/ConsiderationEnums.sol";
import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { TwoStepOwnable } from "../access/TwoStepOwnable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    Pausable
} from "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title RewardDeriver
 * @notice RewardDeriver calculates the OP token reward that a buyer will receive for placing an
 *         order on Quixotic via Seaport. It uses Chainlink to calculate the price conversion from
 *         the buyer's ETH payment to their reward in OP tokens.
 */
contract RewardDeriver is TwoStepOwnable, IRewardDeriver, Pausable {
    /**
     * @notice Emitted when a new marketplace fee recipient address is set.
     *
     * @param marketplaceFeeRecipient New marketplace fee recipient address.
     */
    event MarketplaceFeeRecipientSet(address indexed marketplaceFeeRecipient);

    /**
     * @notice Emitted when the marketplace fee per mille is changed by this contract's owner.
     *
     * @param marketplaceFeePerMille New marketplace fee per mille.
     */
    event MarketplaceFeePerMilleSet(uint256 marketplaceFeePerMille);

    /**
     * @notice Emitted when the OP token base reward per mille is changed by the owner.
     *
     * @param baseRewardPerMille New base reward per mille.
     */
    event BaseRewardPerMilleSet(uint256 baseRewardPerMille);

    /**
     * @notice Emitted when the OP token base reward per mille is changed by the owner.
     *
     * @param maxRewardPerMille New max reward per mille.
     */
    event MaxRewardPerMilleSet(uint256 maxRewardPerMille);

    /**
     * @notice Emitted when a max reward ERC721 is added to the array.
     *
     * @param erc721 New ERC721 address added.
     */
    event MaxRewardERC721Added(address indexed erc721);

    /**
     * @notice Emitted when a max reward ERC721 is removed from the array.
     *
     * @param erc721 ERC721 address removed.
     */
    event MaxRewardERC721Removed(address indexed erc721);

    /**
     * @notice Address of the OP token ERC20 contract.
     */
    IERC20 internal constant OP_TOKEN = IERC20(0x4200000000000000000000000000000000000042);

    /**
     * @notice Address of the SeaportWrapper.
     */
    address public immutable seaportWrapper;

    /**
     * @notice Address of Chainlink's OP-USD price oracle.
     */
    AggregatorV3Interface public opUsdPriceFeed;

    /**
     * @notice Address of Chainlink's ETH-USD price oracle.
     */
    AggregatorV3Interface public ethUsdPriceFeed;

    /**
     * @notice The address to receive marketplace fees.
     */
    address public marketplaceFeeRecipient;

    /**
     * @notice The base OP token reward per mille (i.e. out of 1000).
     */
    uint256 public baseRewardPerMille;

    /**
     * @notice The max OP token reward per mille.
     */
    uint256 public maxRewardPerMille;

    /**
     * @notice Marketplace fee per mille.
     */
    uint256 public marketplaceFeePerMille;

    /**
     * @notice Array of max reward ERC721 addresses. Buyers are able to earn the max OP
     *         token reward if the buyer owns an NFT from one of the collections in this array.
     */
    address[] internal maxRewardERC721s;

    /**
     * @param _owner                   Owner of this contract.
     * @param _seaportWrapper          Address of the SeaportWrapper.
     * @param _marketplaceFeeRecipient Address to receive the marketplace fee.
     * @param _marketplaceFeePerMille  Marketplace fee out of 1000.
     * @param _maxRewardPerMille       Max OP Token reward out of 1000.
     * @param _baseRewardPerMille      Base OP token reward out of 1000.
     * @param _maxRewardERC721s        Array of ERC721s that allow the caller to earn the max OP
     *                                 token reward.
     */
    constructor(
        address _owner,
        address _seaportWrapper,
        address _marketplaceFeeRecipient,
        uint256 _marketplaceFeePerMille,
        uint256 _maxRewardPerMille,
        uint256 _baseRewardPerMille,
        address[] memory _maxRewardERC721s
    ) {
        // The Chainlink oracles only exist on Optimism mainnet (chain ID 10). We also allow chain
        // ID 31337 to test this contract on a forked version of Optimism mainnet using Hardhat.
        if (block.chainid == 10 || block.chainid == 31337) {
            opUsdPriceFeed = AggregatorV3Interface(0x0D276FC14719f9292D5C1eA2198673d1f4269246);
            ethUsdPriceFeed = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        } else {
            // We use pre-deployed EACAggregatorProxyMock contracts to mimic the Chainlink oracles
            // on other networks.
            opUsdPriceFeed = AggregatorV3Interface(0x653eDEC47e954A613A2CD6c5C8C0d1d18781C0ad);
            ethUsdPriceFeed = AggregatorV3Interface(0x680DD45482CEAa2B9FFf17f2EE6396bC7fAc549F);
        }

        seaportWrapper = _seaportWrapper;

        setMarketplaceFeeRecipient(_marketplaceFeeRecipient);
        setMarketplaceFeePerMille(_marketplaceFeePerMille);
        setMaxRewardPerMille(_maxRewardPerMille);
        setBaseRewardPerMille(_baseRewardPerMille);

        for (uint256 i = 0; i < _maxRewardERC721s.length; i++) {
            addMaxRewardERC721(_maxRewardERC721s[i]);
        }

        _transferOwnership(_owner);
    }

    /**
     * @notice Gets the buyer's reward amount in OP for a given order. A reward is only given for
     *         orders that:
     *         - Are paid completely in ETH.
     *         - Have an equal starting and ending price (i.e. no dutch auctions).
     *         - Pay the marketplace fee.
     *         If any of these conditions are not met, the reward amount is zero. The reward amount
     *         is doubled if the buyer owns an NFT from at least one of the collections in the
     *         `maxRewardERC721s` array.
     *
     * @param _order Seaport order struct.
     *
     * @return OP token reward amount.
     */
    function getRewardInOP(Order memory _order, address _buyer) external view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        if (
            _order.parameters.consideration.length !=
            _order.parameters.totalOriginalConsiderationItems
        ) {
            return 0;
        }

        uint256 considerationAmount = 0;
        uint256 marketplacePayment = 0;
        for (uint256 i = 0; i < _order.parameters.totalOriginalConsiderationItems; i++) {
            ConsiderationItem memory considerationItem = _order.parameters.consideration[i];
            if (considerationItem.startAmount != considerationItem.endAmount) {
                return 0;
            } else if (considerationItem.itemType != ItemType.NATIVE) {
                return 0;
            } else if (considerationItem.recipient == marketplaceFeeRecipient) {
                marketplacePayment = considerationItem.startAmount;
            }
            considerationAmount += considerationItem.startAmount;
        }

        uint256 expectedMarketplacePayment = (marketplaceFeePerMille * considerationAmount) / 1000;
        if (expectedMarketplacePayment > marketplacePayment) {
            return 0;
        }

        (, int256 usdPerOP, , , ) = opUsdPriceFeed.latestRoundData();
        (, int256 usdPerETH, , , ) = ethUsdPriceFeed.latestRoundData();

        // Note that `usdPerOP` and `usdPerETH` are integers, not unsigned integers, meaning that
        // their values could theoretically be negative. Although this is highly unlikely, we check
        // that these values are positive anyways to avoid an underflow. See here for the reason
        // Chainlink made these values integers and not unsigned integers:
        // https://stackoverflow.com/questions/67094903/anybody-knows-why-chainlinks-pricefeed-return-price-value-with-int-type-while
        if (usdPerOP <= 0 || usdPerETH <= 0) {
            return 0;
        }

        // Converts the supplied amount from ETH to OP. We perform a division before multiplication
        // here for code clarity. This won't lead to truncation errors unless `usdPerOP` exceeds
        // `usdPerETH`, which won't happen anytime soon.
        // slither-disable-next-line divide-before-multiply
        uint256 considerationAmountInOP = (considerationAmount * uint256(usdPerETH)) /
            uint256(usdPerOP);

        uint256 rewardAmount = 0;
        // Check if the caller is eligible for the max reward.
        if (isEligibleForMaxReward(_buyer)) {
            // Caller gets the max OP token reward if their address is eligible.
            rewardAmount = (maxRewardPerMille * considerationAmountInOP) / 1000;
        } else {
            // If the caller is not eligible for the max reward, use the base OP token reward amount
            // instead.
            rewardAmount = (baseRewardPerMille * considerationAmountInOP) / 1000;
        }

        // Check that the owner of the SeaportWrapper has a sufficient balance of OP token
        // and that the SeaportWrapper has a sufficient allowance.
        address seaportWrapperOwner = TwoStepOwnable(seaportWrapper).owner();
        if (rewardAmount > OP_TOKEN.balanceOf(seaportWrapperOwner)) {
            return 0;
        } else if (rewardAmount > OP_TOKEN.allowance(seaportWrapperOwner, seaportWrapper)) {
            return 0;
        }
        return rewardAmount;
    }

    /**
     * @notice Determines if the specified address is eligible for the max OP token reward, given
     *         that they fulfill a valid order. This function checks if the address owns an NFT from
     *         at least one of the approved ERC721 collections.
     * 
     * @param _address Address in question.
     *
     * @return True if the address owns an NFT from at least one of the ERC721 collections.
     */
    function isEligibleForMaxReward(address _address) public view returns (bool) {
        for (uint256 i = 0; i < maxRewardERC721s.length; i++) {
            uint256 balance = IERC721(maxRewardERC721s[i]).balanceOf(_address);
            if (balance > 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Returns the array of max reward ERC721 addresses. Buyers are able to earn the max OP
     *         token reward if the buyer owns an NFT from one of the collections in this array.
     *
     * @return The `maxRewardERC721s` array of addresses.
     */
    function getMaxRewardERC721s() external view returns (address[] memory) {
        return maxRewardERC721s;
    }

    /**
     * @notice Alows the owner to set a new marketplace fee recipient address.
     *
     * @param _marketplaceFeeRecipient New marketplace fee recipient address.
     */
    function setMarketplaceFeeRecipient(address _marketplaceFeeRecipient) public onlyOwner {
        marketplaceFeeRecipient = _marketplaceFeeRecipient;
        emit MarketplaceFeeRecipientSet(_marketplaceFeeRecipient);
    }

    /**
     * @notice Allows the contract owner to set a new base OP token reward per mille. Note that this
     *         amount cannot be higher than `maxRewardPerMille`.
     *
     * @param _baseRewardPerMille New reward per mille (i.e. out of 1000).
     */
    function setBaseRewardPerMille(uint256 _baseRewardPerMille) public onlyOwner {
        require(
            _baseRewardPerMille <= maxRewardPerMille,
            "RewardDeriver: base reward cannot exceed max reward"
        );
        baseRewardPerMille = _baseRewardPerMille;
        emit BaseRewardPerMilleSet(_baseRewardPerMille);
    }

    /**
     * @notice Allows the contract owner to set a new max OP token reward per mille. Note that this
     *         amount cannot be higher than `marketplaceFeePerMille` to prevent the marketplace from
     *         losing money on each order.
     *
     * @param _maxRewardPerMille New max reward per mille (i.e. out of 1000).
     */
    function setMaxRewardPerMille(uint256 _maxRewardPerMille) public onlyOwner {
        require(
            _maxRewardPerMille < marketplaceFeePerMille,
            "RewardDeriver: max reward must be less than marketplace fee"
        );
        maxRewardPerMille = _maxRewardPerMille;
        emit MaxRewardPerMilleSet(_maxRewardPerMille);
    }

    /**
     * @notice Allows the contract owner to set a new marketplace fee per mille.
     *
     * @param _marketplaceFeePerMille New marketplace fee per mille.
     */
    function setMarketplaceFeePerMille(uint256 _marketplaceFeePerMille) public onlyOwner {
        marketplaceFeePerMille = _marketplaceFeePerMille;
        emit MarketplaceFeePerMilleSet(_marketplaceFeePerMille);
    }

    /**
     * @notice Allows the contract owner to add a new max reward ERC721 to the array.
     */
    function addMaxRewardERC721(address _erc721) public onlyOwner {
        require(
            ERC165Checker.supportsInterface(_erc721, type(IERC721).interfaceId),
            "RewardDeriver: erc721 must support erc-165 interface"
        );
        for (uint256 i = 0; i < maxRewardERC721s.length; i++) {
            require(maxRewardERC721s[i] != _erc721, "RewardDeriver: erc721 already added");
        }
        maxRewardERC721s.push(_erc721);

        emit MaxRewardERC721Added(_erc721);
    }

    /**
     * @notice Allows the owner to remove a max reward ERC721 from the array.
     */
    function removeMaxRewardERC721(address _erc721) external onlyOwner {
        uint256 lastIndex = maxRewardERC721s.length - 1;
        uint256 targetIndex = type(uint256).max;
        for (uint256 i = 0; i < maxRewardERC721s.length; i++) {
            if (_erc721 == maxRewardERC721s[i]) {
                targetIndex = i;
                break;
            }
        }

        require(targetIndex != type(uint256).max, "RewardDeriver: array does not contain erc721");

        address erc721ToRemove = maxRewardERC721s[targetIndex];
        address lastERC721 = maxRewardERC721s[lastIndex];

        // Move the last element to the slot of the address to delete
        maxRewardERC721s[targetIndex] = lastERC721;

        // Delete the last element of the array
        maxRewardERC721s.pop();

        emit MaxRewardERC721Removed(erc721ToRemove);
    }

    /**
     * @notice Allows the owner to pause marketplace activity.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Allows the owner to unpause marketplace activity.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Order } from "../lib/seaport/lib/ConsiderationStructs.sol";

/**
 * @title IRewardDeriver
 * @notice RewardDeriver interface.
 */
interface IRewardDeriver {
    /**
     * @notice Gets the buyer's reward amount in OP for a given order. A reward is only given for
     *
     * @param _order Seaport order struct.
     * @param _buyer Buyer of the order.
     *
     * @return OP token reward amount.
     */
    function getRewardInOP(Order memory _order, address _buyer) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title TwoStepOwnable
 * @notice This contract is a slightly modified version of OpenZeppelin's `Ownable` contract with the caveat
 *         that ownership transfer occurs in two phases. First, the current owner initiates the transfer,
 *         and then the new owner accepts it. Ownership isn't actually transferred until both steps have been
 *         completed. The purpose of this is to ensure that ownership isn't accidentally transferred to the
 *         incorrect address. Note that the initial owner account is the contract deployer by default. Also
 *         note that this contract can only be used through inheritance.
 */
abstract contract TwoStepOwnable is Context {
    address private _owner;

    // A potential owner is specified by the owner when the transfer is initiated. A potential owner
    // does not have any ownership privileges until it accepts the transfer.
    address private _potentialOwner;

    /**
     * @notice Emitted when ownership transfer is initiated.
     *
     * @param owner          The current owner.
     * @param potentialOwner The address that the owner specifies as the new owner.
     */
    event OwnershipTransferInitiated(
        address indexed owner,
        address indexed potentialOwner
    );

    /**
     * @notice Emitted when ownership transfer is finalized.
     *
     * @param previousOwner The previous owner.
     * @param newOwner      The new owner.
     */
    event OwnershipTransferFinalized(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @notice Emitted when ownership transfer is cancelled.
     *
     * @param owner                   The current owner.
     * @param cancelledPotentialOwner The previous potential owner that can no longer accept ownership.
     */
    event OwnershipTransferCancelled(
        address indexed owner,
        address indexed cancelledPotentialOwner
    );

    /**
     * @notice Initializes the contract, setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @notice Reverts if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @notice Reverts if called by any account other than the potential owner.
     */
    modifier onlyPotentialOwner() {
        _checkPotentialOwner();
        _;
    }

    /**
     * @notice Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @notice Returns the address of the potential owner.
     */
    function potentialOwner() public view virtual returns (address) {
        return _potentialOwner;
    }

    /**
     * @notice Reverts if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(
            owner() == _msgSender(),
            "TwoStepOwnable: caller is not the owner"
        );
    }

    /**
     * @notice Reverts if the sender is not the potential owner.
     */
    function _checkPotentialOwner() internal view virtual {
        require(
            potentialOwner() == _msgSender(),
            "TwoStepOwnable: caller is not the potential owner"
        );
    }

    /**
     * @notice Initiates ownership transfer of the contract to a new account. Can only be called by
     *         the current owner.
     * @param newOwner The address that the owner specifies as the new owner.
     */
    function initiateOwnershipTransfer(address newOwner)
        public
        virtual
        onlyOwner
    {
        require(
            newOwner != address(0),
            "TwoStepOwnable: new owner is the zero address"
        );
        _potentialOwner = newOwner;
        emit OwnershipTransferInitiated(owner(), newOwner);
    }

    /**
     * @notice Finalizes ownership transfer of the contract to a new account. Can only be called by
     *         the account that is accepting the ownership transfer.
     */
    function acceptOwnershipTransfer() public virtual onlyPotentialOwner {
        _transferOwnership(msg.sender);
    }

    /**
     * @notice Cancels the ownership transfer to the new account, keeping the current owner as is. The current
     *         owner should call this function if the transfer is initiated to the wrong address. Can only be
     *         called by the current owner.
     */
    function cancelOwnershipTransfer() public virtual onlyOwner {
        require(potentialOwner() != address(0), "TwoStepOwnable: no existing potential owner to cancel");
        address previousPotentialOwner = _potentialOwner;
        _potentialOwner = address(0);
        emit OwnershipTransferCancelled(owner(), previousPotentialOwner);
    }

    /**
     * @notice Leaves the contract without an owner forever. This makes it impossible to perform any ownership
     *         functionality, including calling `onlyOwner` functions. Can only be called by the current owner.
     *         Note that renouncing ownership is a single step process.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @notice Transfers ownership of the contract to a new account.
     *
     * @param newOwner The new owner of the contract.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        _potentialOwner = address(0);
        emit OwnershipTransferFinalized(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    OrderType,
    BasicOrderType,
    ItemType,
    Side
} from "./ConsiderationEnums.sol";

/**
 * @dev An order contains eleven components: an offerer, a zone (or account that
 *      can cancel the order or restrict who can fulfill the order depending on
 *      the type), the order type (specifying partial fill support as well as
 *      restricted order status), the start and end time, a hash that will be
 *      provided to the zone when validating restricted orders, a salt, a key
 *      corresponding to a given conduit, a counter, and an arbitrary number of
 *      offer items that can be spent along with consideration items that must
 *      be received by their respective recipient.
 */
struct OrderComponents {
    address offerer;
    address zone;
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 counter;
}

/**
 * @dev An offer item has five components: an item type (ETH or other native
 *      tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
 *      ERC1155), a token address, a dual-purpose "identifierOrCriteria"
 *      component that will either represent a tokenId or a merkle root
 *      depending on the item type, and a start and end amount that support
 *      increasing or decreasing amounts over the duration of the respective
 *      order.
 */
struct OfferItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

/**
 * @dev A consideration item has the same five components as an offer item and
 *      an additional sixth component designating the required recipient of the
 *      item.
 */
struct ConsiderationItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
}

/**
 * @dev A spent item is translated from a utilized offer item and has four
 *      components: an item type (ETH or other native tokens, ERC20, ERC721, and
 *      ERC1155), a token address, a tokenId, and an amount.
 */
struct SpentItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}

/**
 * @dev A received item is translated from a utilized consideration item and has
 *      the same four components as a spent item, as well as an additional fifth
 *      component designating the required recipient of the item.
 */
struct ReceivedItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
    address payable recipient;
}

/**
 * @dev For basic orders involving ETH / native / ERC20 <=> ERC721 / ERC1155
 *      matching, a group of six functions may be called that only requires a
 *      subset of the usual order arguments. Note the use of a "basicOrderType"
 *      enum; this represents both the usual order type as well as the "route"
 *      of the basic order (a simple derivation function for the basic order
 *      type is `basicOrderType = orderType + (4 * basicOrderRoute)`.)
 */
struct BasicOrderParameters {
    // calldata offset
    address considerationToken; // 0x24
    uint256 considerationIdentifier; // 0x44
    uint256 considerationAmount; // 0x64
    address payable offerer; // 0x84
    address zone; // 0xa4
    address offerToken; // 0xc4
    uint256 offerIdentifier; // 0xe4
    uint256 offerAmount; // 0x104
    BasicOrderType basicOrderType; // 0x124
    uint256 startTime; // 0x144
    uint256 endTime; // 0x164
    bytes32 zoneHash; // 0x184
    uint256 salt; // 0x1a4
    bytes32 offererConduitKey; // 0x1c4
    bytes32 fulfillerConduitKey; // 0x1e4
    uint256 totalOriginalAdditionalRecipients; // 0x204
    AdditionalRecipient[] additionalRecipients; // 0x224
    bytes signature; // 0x244
    // Total length, excluding dynamic array data: 0x264 (580)
}

/**
 * @dev Basic orders can supply any number of additional recipients, with the
 *      implied assumption that they are supplied from the offered ETH (or other
 *      native token) or ERC20 token for the order.
 */
struct AdditionalRecipient {
    uint256 amount;
    address payable recipient;
}

/**
 * @dev The full set of order components, with the exception of the counter,
 *      must be supplied when fulfilling more sophisticated orders or groups of
 *      orders. The total number of original consideration items must also be
 *      supplied, as the caller may specify additional consideration items.
 */
struct OrderParameters {
    address offerer; // 0x00
    address zone; // 0x20
    OfferItem[] offer; // 0x40
    ConsiderationItem[] consideration; // 0x60
    OrderType orderType; // 0x80
    uint256 startTime; // 0xa0
    uint256 endTime; // 0xc0
    bytes32 zoneHash; // 0xe0
    uint256 salt; // 0x100
    bytes32 conduitKey; // 0x120
    uint256 totalOriginalConsiderationItems; // 0x140
    // offer.length                          // 0x160
}

/**
 * @dev Orders require a signature in addition to the other order parameters.
 */
struct Order {
    OrderParameters parameters;
    bytes signature;
}

/**
 * @dev Advanced orders include a numerator (i.e. a fraction to attempt to fill)
 *      and a denominator (the total size of the order) in addition to the
 *      signature and other order parameters. It also supports an optional field
 *      for supplying extra data; this data will be included in a staticcall to
 *      `isValidOrderIncludingExtraData` on the zone for the order if the order
 *      type is restricted and the offerer or zone are not the caller.
 */
struct AdvancedOrder {
    OrderParameters parameters;
    uint120 numerator;
    uint120 denominator;
    bytes signature;
    bytes extraData;
}

/**
 * @dev Orders can be validated (either explicitly via `validate`, or as a
 *      consequence of a full or partial fill), specifically cancelled (they can
 *      also be cancelled in bulk via incrementing a per-zone counter), and
 *      partially or fully filled (with the fraction filled represented by a
 *      numerator and denominator).
 */
struct OrderStatus {
    bool isValidated;
    bool isCancelled;
    uint120 numerator;
    uint120 denominator;
}

/**
 * @dev A criteria resolver specifies an order, side (offer vs. consideration),
 *      and item index. It then provides a chosen identifier (i.e. tokenId)
 *      alongside a merkle proof demonstrating the identifier meets the required
 *      criteria.
 */
struct CriteriaResolver {
    uint256 orderIndex;
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
}

/**
 * @dev A fulfillment is applied to a group of orders. It decrements a series of
 *      offer and consideration items, then generates a single execution
 *      element. A given fulfillment can be applied to as many offer and
 *      consideration items as desired, but must contain at least one offer and
 *      at least one consideration that match. The fulfillment must also remain
 *      consistent on all key parameters across all offer items (same offerer,
 *      token, type, tokenId, and conduit preference) as well as across all
 *      consideration items (token, type, tokenId, and recipient).
 */
struct Fulfillment {
    FulfillmentComponent[] offerComponents;
    FulfillmentComponent[] considerationComponents;
}

/**
 * @dev Each fulfillment component contains one index referencing a specific
 *      order and another referencing a specific offer or consideration item.
 */
struct FulfillmentComponent {
    uint256 orderIndex;
    uint256 itemIndex;
}

/**
 * @dev An execution is triggered once all consideration items have been zeroed
 *      out. It sends the item in question from the offerer to the item's
 *      recipient, optionally sourcing approvals from either this contract
 *      directly or from the offerer's chosen conduit if one is specified. An
 *      execution is not provided as an argument, but rather is derived via
 *      orders, criteria resolvers, and fulfillments (where the total number of
 *      executions will be less than or equal to the total number of indicated
 *      fulfillments) and returned as part of `matchOrders`.
 */
struct Execution {
    ReceivedItem item;
    address offerer;
    bytes32 conduitKey;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// prettier-ignore
enum OrderType {
    // 0: no partial fills, anyone can execute
    FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED
}

// prettier-ignore
enum BasicOrderType {
    // 0: no partial fills, anyone can execute
    ETH_TO_ERC721_FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    ETH_TO_ERC721_PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    ETH_TO_ERC721_FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC721_PARTIAL_RESTRICTED,

    // 4: no partial fills, anyone can execute
    ETH_TO_ERC1155_FULL_OPEN,

    // 5: partial fills supported, anyone can execute
    ETH_TO_ERC1155_PARTIAL_OPEN,

    // 6: no partial fills, only offerer or zone can execute
    ETH_TO_ERC1155_FULL_RESTRICTED,

    // 7: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC1155_PARTIAL_RESTRICTED,

    // 8: no partial fills, anyone can execute
    ERC20_TO_ERC721_FULL_OPEN,

    // 9: partial fills supported, anyone can execute
    ERC20_TO_ERC721_PARTIAL_OPEN,

    // 10: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC721_FULL_RESTRICTED,

    // 11: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC721_PARTIAL_RESTRICTED,

    // 12: no partial fills, anyone can execute
    ERC20_TO_ERC1155_FULL_OPEN,

    // 13: partial fills supported, anyone can execute
    ERC20_TO_ERC1155_PARTIAL_OPEN,

    // 14: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC1155_FULL_RESTRICTED,

    // 15: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC1155_PARTIAL_RESTRICTED,

    // 16: no partial fills, anyone can execute
    ERC721_TO_ERC20_FULL_OPEN,

    // 17: partial fills supported, anyone can execute
    ERC721_TO_ERC20_PARTIAL_OPEN,

    // 18: no partial fills, only offerer or zone can execute
    ERC721_TO_ERC20_FULL_RESTRICTED,

    // 19: partial fills supported, only offerer or zone can execute
    ERC721_TO_ERC20_PARTIAL_RESTRICTED,

    // 20: no partial fills, anyone can execute
    ERC1155_TO_ERC20_FULL_OPEN,

    // 21: partial fills supported, anyone can execute
    ERC1155_TO_ERC20_PARTIAL_OPEN,

    // 22: no partial fills, only offerer or zone can execute
    ERC1155_TO_ERC20_FULL_RESTRICTED,

    // 23: partial fills supported, only offerer or zone can execute
    ERC1155_TO_ERC20_PARTIAL_RESTRICTED
}

// prettier-ignore
enum BasicOrderRouteType {
    // 0: provide Ether (or other native token) to receive offered ERC721 item.
    ETH_TO_ERC721,

    // 1: provide Ether (or other native token) to receive offered ERC1155 item.
    ETH_TO_ERC1155,

    // 2: provide ERC20 item to receive offered ERC721 item.
    ERC20_TO_ERC721,

    // 3: provide ERC20 item to receive offered ERC1155 item.
    ERC20_TO_ERC1155,

    // 4: provide ERC721 item to receive offered ERC20 item.
    ERC721_TO_ERC20,

    // 5: provide ERC1155 item to receive offered ERC20 item.
    ERC1155_TO_ERC20
}

// prettier-ignore
enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,

    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,

    // 2: ERC721 items
    ERC721,

    // 3: ERC1155 items
    ERC1155,

    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,

    // 5: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}

// prettier-ignore
enum Side {
    // 0: Items that can be spent
    OFFER,

    // 1: Items that must be received
    CONSIDERATION
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.2) (utils/introspection/ERC165Checker.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165Checker {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            _supportsERC165Interface(account, type(IERC165).interfaceId) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool[] memory)
    {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        // prepare call
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);

        // perform static call
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(30000, account, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }
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