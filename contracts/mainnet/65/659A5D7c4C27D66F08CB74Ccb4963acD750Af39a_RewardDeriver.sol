// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { RewardInfo, Campaign } from "./RewardStructs.sol";
import { ICampaignTracker } from "./ICampaignTracker.sol";
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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title RewardDeriver
 * @notice RewardDeriver calculates the OP token reward that a buyer will receive for placing an
 *         order on Quixotic via Seaport. It uses Chainlink to calculate the price conversion from
 *         the buyer's ETH payment to their reward in OP tokens.
 */
contract RewardDeriver is TwoStepOwnable, IRewardDeriver {
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
     * @notice Emitted when the RewardWrapper is set.
     */
    event RewardWrapperSet(address indexed rewardWrapper);

    /**
     * @notice Emitted when the CampaignTracker is set.
     */
    event CampaignTrackerSet(address indexed campaignTracker);

    /**
     * @notice Address of the OP token ERC20 contract.
     */
    // slither-disable-next-line too-many-digits
    IERC20 internal constant OP_TOKEN = IERC20(0x4200000000000000000000000000000000000042);

    string public constant BASELINE_CAMPAIGN_STRING = "BASELINE";
    
    string public constant OPTIMISM_OG_CAMPAIGN_STRING = "OPOG";

    string public constant COLLECTION_BOOST_PREFIX = "COLLECTION_BOOST_";

    /**
     * @notice Address of the RewardWrapper.
     */
    address public rewardWrapper;

    /**
     * @notice Address of the CampaignTracker.
     */
    ICampaignTracker public campaignTracker;

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
     * @notice Marketplace fee per mille.
     */
    uint256 public marketplaceFeePerMille;

    /**
     * @notice Boolean indicating if rewards are turned on.
     */
    bool public rewardsTurnedOn;

    /**
     * @param _marketplaceOwner        Owner of this contract.
     * @param _rewardWrapper           Address of the RewardWrapper.
     * @param _campaignTracker         Address of the CampaignTracker.
     * @param _marketplaceFeeRecipient Address to receive the marketplace fee.
     * @param _marketplaceFeePerMille  Marketplace fee out of 1000.
     */
    constructor(
        address _marketplaceOwner,
        address _rewardWrapper,
        address _campaignTracker,
        address _marketplaceFeeRecipient,
        uint256 _marketplaceFeePerMille
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

        turnRewardsOn();
        setRewardWrapper(_rewardWrapper);
        setCampaignTracker(ICampaignTracker(_campaignTracker));
        setMarketplaceFeeRecipient(_marketplaceFeeRecipient);
        setMarketplaceFeePerMille(_marketplaceFeePerMille);

        _transferOwnership(_marketplaceOwner);
    }

    /**
     * @notice Gets the buyer's reward amount in OP for a given order. A reward is only given for
     *         orders that:
     *         - Are paid completely in ETH.
     *         - Have an equal starting and ending price (i.e. no dutch auctions).
     *         - Pay the marketplace fee.
     *         - Have an active campaign with a sufficient allowance.
     *         If any of these conditions are not met, the reward amount is zero.
     *
     * @param _order     Seaport order struct.
     * @param _recipient Address to receive the reward.
     *
     * @return OP token reward amount.
     */
    function getRewardInOP(Order memory _order, address _recipient)
        external
        view
        override
        returns (RewardInfo[] memory)
    {
        if (!rewardsTurnedOn) {
            return new RewardInfo[](0);
        }

        if (
            _order.parameters.consideration.length !=
            _order.parameters.totalOriginalConsiderationItems
        ) {
            return new RewardInfo[](0);
        }

        string memory collectionBoostCampaignString = string.concat(
            COLLECTION_BOOST_PREFIX,
            Strings.toHexString(uint160(_order.parameters.offer[0].token), 20)
        );
        Campaign memory campaign = campaignTracker.getCampaign(collectionBoostCampaignString);

        uint256 considerationAmount = 0;
        uint256 marketplacePayment = 0;
        uint256 royaltyPayment = 0;
        for (uint256 i = 0; i < _order.parameters.totalOriginalConsiderationItems; i++) {
            ConsiderationItem memory considerationItem = _order.parameters.consideration[i];
            if (considerationItem.startAmount != considerationItem.endAmount) {
                return new RewardInfo[](0);
            } else if (considerationItem.itemType != ItemType.NATIVE) {
                return new RewardInfo[](0);
            } else if (considerationItem.recipient == marketplaceFeeRecipient) {
                marketplacePayment += considerationItem.startAmount;
            } else if (considerationItem.recipient == campaign.royaltyReceiver) {
                royaltyPayment += considerationItem.startAmount;
            }
            considerationAmount += considerationItem.startAmount;
        }

        uint256 expectedMarketplacePayment = (marketplaceFeePerMille * considerationAmount) / 1000;
        if (expectedMarketplacePayment > marketplacePayment) {
            return new RewardInfo[](0);
        }

        uint256 expectedRoyaltyPayment = (campaign.royaltyPerMille * considerationAmount) / 1000;
        if (campaign.royaltyReceiver != address(0) && expectedRoyaltyPayment > royaltyPayment) {
            return new RewardInfo[](0);
        }

        (, int256 usdPerOP, , , ) = opUsdPriceFeed.latestRoundData();
        (, int256 usdPerETH, , , ) = ethUsdPriceFeed.latestRoundData();

        // Note that `usdPerOP` and `usdPerETH` are integers, not unsigned integers, meaning that
        // their values could theoretically be negative. Although this is highly unlikely, we check
        // that these values are positive anyways to avoid an underflow. See here for the reason
        // Chainlink made these values integers and not unsigned integers:
        // https://stackoverflow.com/questions/67094903/anybody-knows-why-chainlinks-pricefeed-return-price-value-with-int-type-while
        if (usdPerOP <= 0 || usdPerETH <= 0) {
            return new RewardInfo[](0);
        }

        // Converts the supplied amount from ETH to OP. We perform a division before multiplication
        // here for code clarity. This won't lead to truncation errors unless `usdPerOP` exceeds
        // `usdPerETH`, which won't happen anytime soon.
        // slither-disable-next-line divide-before-multiply
        uint256 considerationAmountInOP = (considerationAmount * uint256(usdPerETH)) /
            uint256(usdPerOP);

        uint256 totalRewardAmountInOP = 0;
        RewardInfo[] memory rewardInfoArray = new RewardInfo[](3);
        if (campaignTracker.isOptimismOGHolder(_recipient)) {
            uint256 rewardAmountInOP = campaignTracker.getRewardAmountInOP(OPTIMISM_OG_CAMPAIGN_STRING, considerationAmountInOP);
            rewardInfoArray[0] = 
                RewardInfo({
                    campaignString: OPTIMISM_OG_CAMPAIGN_STRING,
                    rewardAmountInOP: rewardAmountInOP
                });
            totalRewardAmountInOP += rewardAmountInOP;
        }

        uint256 baselineRewardAmountInOP = campaignTracker.getRewardAmountInOP(BASELINE_CAMPAIGN_STRING, considerationAmountInOP);
        rewardInfoArray[1] = 
            RewardInfo({
                campaignString: BASELINE_CAMPAIGN_STRING,
                rewardAmountInOP: baselineRewardAmountInOP
            });
        totalRewardAmountInOP += baselineRewardAmountInOP;

        uint256 collectionBoostRewardAmountInOP = campaignTracker.getRewardAmountInOP(collectionBoostCampaignString, considerationAmountInOP);
        rewardInfoArray[2] =
            RewardInfo({
                campaignString: collectionBoostCampaignString,
                rewardAmountInOP: collectionBoostRewardAmountInOP
            });
        totalRewardAmountInOP += collectionBoostRewardAmountInOP;

        // Check that the owner of the RewardWrapper has a sufficient balance of OP token
        // and that the RewardWrapper has a sufficient allowance.
        address rewardWrapperOwner = TwoStepOwnable(rewardWrapper).owner();
        if (totalRewardAmountInOP > OP_TOKEN.balanceOf(rewardWrapperOwner)) {
            return new RewardInfo[](0);
        } else if (totalRewardAmountInOP > OP_TOKEN.allowance(rewardWrapperOwner, rewardWrapper)) {
            return new RewardInfo[](0);
        }

        return rewardInfoArray;
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
     * @notice Allows the owner to set a new RewardWrapper contract.
     * 
     * @param _rewardWrapper New RewardWrapper contract.
     */
    function setRewardWrapper(address _rewardWrapper) public onlyOwner {
        rewardWrapper = _rewardWrapper;
        emit RewardWrapperSet(_rewardWrapper);
    }

    /**
     * @notice Allows the owner to set a new CampaignTracker contract.
     * 
     * @param _campaignTracker New CampaignTracker contract.
     */
    function setCampaignTracker(ICampaignTracker _campaignTracker) public onlyOwner {
        campaignTracker = _campaignTracker;
        emit CampaignTrackerSet(address(_campaignTracker));
    }
        
    /**
     * @notice Allows the contract owner to set a new marketplace fee per mille. The new marketplace
     *         fee per mille must be greater than the reward per mille for the baseline campaign
     *         plus the reward per mille for the OP OG campaign. This helps ensure that someone
     *         malicious cannot purchase their own NFT to profitably drain rewards.
     *
     * @param _marketplaceFeePerMille New marketplace fee per mille.
     */
    function setMarketplaceFeePerMille(uint256 _marketplaceFeePerMille) public onlyOwner {
        Campaign memory baselineCampaign = campaignTracker.getCampaign(BASELINE_CAMPAIGN_STRING);
        Campaign memory optimismOGCampaign = campaignTracker.getCampaign(OPTIMISM_OG_CAMPAIGN_STRING);
        require(_marketplaceFeePerMille > baselineCampaign.rewardPerMille + optimismOGCampaign.rewardPerMille, "RewardDeriver: new marketplace fee per mille is too low");

        marketplaceFeePerMille = _marketplaceFeePerMille;
        emit MarketplaceFeePerMilleSet(_marketplaceFeePerMille);
    }

    /**
     * @notice Allows the owner to turn rewards off.
     */
    function turnRewardsOff() external onlyOwner {
        rewardsTurnedOn = false;
    }

    /**
     * @notice Allows the owner to turn rewards on.
     */
    function turnRewardsOn() public onlyOwner {
        rewardsTurnedOn = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Order } from "../lib/seaport/lib/ConsiderationStructs.sol";
import { RewardInfo } from "./RewardStructs.sol";

/**
 * @title IRewardDeriver
 * @notice RewardDeriver interface.
 */
interface IRewardDeriver {
    /**
     * @notice The address to receive marketplace fees.
     */
    function marketplaceFeeRecipient() external returns (address);

    /**
     * @notice Marketplace fee per mille.
     */
    function marketplaceFeePerMille() external returns (uint256);

    /**
     * @notice Boolean indicating if rewards are turned on.
     */
    function rewardsTurnedOn() external returns (bool);

    /**
     * @notice Gets the buyer's reward amount in OP for a given order. A reward is only given for
     *
     * @param _order Seaport order struct.
     * @param _buyer Buyer of the order.
     *
     * @return OP token reward amount.
     */
    function getRewardInOP(Order memory _order, address _buyer) external view returns (RewardInfo[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct Campaign {
    string campaignString;
    uint256 rewardPerMille;
    address manager;
    address royaltyReceiver;
    uint256 royaltyPerMille;
    uint256 maxAllowanceInOP;
    bool isActive;
}

/**
 * @notice The campaign ID and OP token reward amount for a given order.
 */
struct RewardInfo {
    string campaignString;
    uint256 rewardAmountInOP;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Campaign } from  "./RewardStructs.sol";

interface ICampaignTracker {
    function getRewardAmountInOP(string memory _campaignString, uint256 _considerationAmountInOP) external view returns (uint256);

    function getCampaign(string memory _campaignString) external view returns (Campaign memory);

    function isOptimismOGHolder(address _address) external view returns (bool);

    function getOptimismOGERC721s() external view returns (address[] memory);
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
    // slither-disable-next-line external-function
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
    // slither-disable-next-line external-function
    function acceptOwnershipTransfer() public virtual onlyPotentialOwner {
        _transferOwnership(msg.sender);
    }

    /**
     * @notice Cancels the ownership transfer to the new account, keeping the current owner as is. The current
     *         owner should call this function if the transfer is initiated to the wrong address. Can only be
     *         called by the current owner.
     */
    // slither-disable-next-line external-function
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
    // slither-disable-next-line external-function
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
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
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