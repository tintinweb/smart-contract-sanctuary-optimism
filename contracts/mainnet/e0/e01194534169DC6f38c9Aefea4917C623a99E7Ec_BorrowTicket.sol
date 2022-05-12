// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import './NFTLoanTicket.sol';
import {NFTLoanFacilitator} from './NFTLoanFacilitator.sol';
import {NFTLoansTicketDescriptor} from './descriptors/NFTLoansTicketDescriptor.sol';

contract BorrowTicket is NFTLoanTicket {

    /// See NFTLoanTicket
    constructor(
        NFTLoanFacilitator _nftLoanFacilitator,
        NFTLoansTicketDescriptor _descriptor
    ) 
        NFTLoanTicket("Backed Borrow Ticket", "BRWT", _nftLoanFacilitator, _descriptor)
    {}
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import {ERC721} from "./ERC721.sol";

import {NFTLoanFacilitator} from './NFTLoanFacilitator.sol';
import {NFTLoansTicketDescriptor} from './descriptors/NFTLoansTicketDescriptor.sol';
import {IERC721Mintable} from './interfaces/IERC721Mintable.sol';

contract NFTLoanTicket is ERC721, IERC721Mintable {
    NFTLoanFacilitator public immutable nftLoanFacilitator;
    NFTLoansTicketDescriptor public immutable descriptor;

    modifier loanFacilitatorOnly() { 
        require(msg.sender == address(nftLoanFacilitator), "NFTLoanTicket: only loan facilitator");
        _; 
    }

    /// @dev Sets the values for {name} and {symbol} and {nftLoanFacilitator} and {descriptor}.
    constructor(
        string memory name, 
        string memory symbol, 
        NFTLoanFacilitator _nftLoanFacilitator, 
        NFTLoansTicketDescriptor _descriptor
    ) 
        ERC721(name, symbol) 
    {
        nftLoanFacilitator = _nftLoanFacilitator;
        descriptor = _descriptor;
    }

    /// See {IERC721Mintable-mint}.
    function mint(address to, uint256 tokenId) external override loanFacilitatorOnly {
        _mint(to, tokenId);
    }

    /// @notice returns a base64 encoded data uri containing the token metadata in JSON format
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf[tokenId] != address(0), 'nonexistent token');
        
        return descriptor.uri(nftLoanFacilitator, tokenId);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeTransferLib, ERC20} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC1820Registry} from "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import {IERC777Recipient} from "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

import {INFTLoanFacilitator} from './interfaces/INFTLoanFacilitator.sol';
import {IERC721Mintable} from './interfaces/IERC721Mintable.sol';
import {ILendTicket} from './interfaces/ILendTicket.sol';

contract NFTLoanFacilitator is Ownable, INFTLoanFacilitator, IERC777Recipient {
    using SafeTransferLib for ERC20;

    // ==== constants ====

    /** 
     * See {INFTLoanFacilitator-INTEREST_RATE_DECIMALS}.     
     * @dev lowest non-zero APR possible = (1/10^3) = 0.001 = 0.1%
     */
    uint8 public constant override INTEREST_RATE_DECIMALS = 3;

    /// See {INFTLoanFacilitator-SCALAR}.
    uint256 public constant override SCALAR = 10 ** INTEREST_RATE_DECIMALS;

    
    // ==== state variables ====

    /// See {INFTLoanFacilitator-originationFeeRate}.
    /// @dev starts at 1%
    uint256 public override originationFeeRate = 10 ** (INTEREST_RATE_DECIMALS - 2);

    /// See {INFTLoanFacilitator-requiredImprovementRate}.
    /// @dev starts at 10%
    uint256 public override requiredImprovementRate = 10 ** (INTEREST_RATE_DECIMALS - 1);

    /// See {INFTLoanFacilitator-lendTicketContract}.
    address public override lendTicketContract;

    /// See {INFTLoanFacilitator-borrowTicketContract}.
    address public override borrowTicketContract;

    /// See {INFTLoanFacilitator-loanInfo}.
    mapping(uint256 => Loan) public loanInfo;

    /// @dev tracks loan count
    uint256 private _nonce = 1;

    
    // ==== modifiers ====

    modifier notClosed(uint256 loanId) { 
        require(!loanInfo[loanId].closed, "loan closed");
        _; 
    }


    // ==== constructor ====

    constructor(address _manager) {
        transferOwnership(_manager);

        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24).setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensRecipient"),
            address(this)
        );
    }

    
    // ==== state changing external functions ====

    /// See {INFTLoanFacilitator-createLoan}.
    function createLoan(
        uint256 collateralTokenId,
        address collateralContractAddress,
        uint16 maxPerAnnumInterest,
        bool allowLoanAmountIncrease,
        uint128 minLoanAmount,
        address loanAssetContractAddress,
        uint32 minDurationSeconds,
        address mintBorrowTicketTo
    )
        external
        override
        returns (uint256 id) 
    {
        require(minDurationSeconds != 0, '0 duration');
        require(minLoanAmount != 0, '0 loan amount');
        require(collateralContractAddress != lendTicketContract,
        'lend ticket collateral');
        require(collateralContractAddress != borrowTicketContract, 
        'borrow ticket collateral');
        
        IERC721(collateralContractAddress).transferFrom(msg.sender, address(this), collateralTokenId);

        unchecked {
            id = _nonce++;
        }

        Loan storage loan = loanInfo[id];
        loan.allowLoanAmountIncrease = allowLoanAmountIncrease;
        loan.originationFeeRate = uint88(originationFeeRate);
        loan.loanAssetContractAddress = loanAssetContractAddress;
        loan.loanAmount = minLoanAmount;
        loan.collateralTokenId = collateralTokenId;
        loan.collateralContractAddress = collateralContractAddress;
        loan.perAnnumInterestRate = maxPerAnnumInterest;
        loan.durationSeconds = minDurationSeconds;
        
        IERC721Mintable(borrowTicketContract).mint(mintBorrowTicketTo, id);
        emit CreateLoan(
            id,
            msg.sender,
            collateralTokenId,
            collateralContractAddress,
            maxPerAnnumInterest,
            loanAssetContractAddress,
            allowLoanAmountIncrease,
            minLoanAmount,
            minDurationSeconds
        );
    }

    /// See {INFTLoanFacilitator-closeLoan}.
    function closeLoan(uint256 loanId, address sendCollateralTo) external override notClosed(loanId) {
        require(IERC721(borrowTicketContract).ownerOf(loanId) == msg.sender,
        "borrow ticket holder only");

        Loan storage loan = loanInfo[loanId];
        require(loan.lastAccumulatedTimestamp == 0, "has lender");
        
        loan.closed = true;
        IERC721(loan.collateralContractAddress).transferFrom(address(this), sendCollateralTo, loan.collateralTokenId);
        emit Close(loanId);
    }

    /// See {INFTLoanFacilitator-lend}.
    function lend(
        uint256 loanId,
        uint16 interestRate,
        uint128 amount,
        uint32 durationSeconds,
        address sendLendTicketTo
    )
        external
        override
        notClosed(loanId)
    {
        Loan storage loan = loanInfo[loanId];
        
        if (loan.lastAccumulatedTimestamp == 0) {
            address loanAssetContractAddress = loan.loanAssetContractAddress;
            require(loanAssetContractAddress.code.length != 0, "invalid loan");

            require(interestRate <= loan.perAnnumInterestRate, 'rate too high');

            require(durationSeconds >= loan.durationSeconds, 'duration too low');

            if (loan.allowLoanAmountIncrease) {
                require(amount >= loan.loanAmount, 'amount too low');
            } else {
                require(amount == loan.loanAmount, 'invalid amount');
            }
        
            loan.perAnnumInterestRate = interestRate;
            loan.lastAccumulatedTimestamp = uint40(block.timestamp);
            loan.durationSeconds = durationSeconds;
            loan.loanAmount = amount;
            
            uint256 facilitatorTake = amount * uint256(loan.originationFeeRate) / SCALAR;
            ERC20(loanAssetContractAddress).safeTransferFrom(msg.sender, address(this), facilitatorTake);
            ERC20(loanAssetContractAddress).safeTransferFrom(
                msg.sender,
                IERC721(borrowTicketContract).ownerOf(loanId),
                amount - facilitatorTake
            );
            IERC721Mintable(lendTicketContract).mint(sendLendTicketTo, loanId);
        } else {
            uint256 previousLoanAmount = loan.loanAmount;
            // implicitly checks that amount >= loan.loanAmount
            // will underflow if amount < previousAmount
            uint256 amountIncrease = amount - previousLoanAmount;
            if (!loan.allowLoanAmountIncrease) {
                require(amountIncrease == 0, 'amount increase not allowed');
            }

            uint256 accumulatedInterest;

            {
                uint256 previousInterestRate = loan.perAnnumInterestRate;
                uint256 previousDurationSeconds = loan.durationSeconds;

                require(interestRate <= previousInterestRate, 'rate too high');

                require(durationSeconds >= previousDurationSeconds, 'duration too low');

                require(
                    Math.ceilDiv(previousLoanAmount * requiredImprovementRate, SCALAR) <= amountIncrease
                    || previousDurationSeconds + Math.ceilDiv(previousDurationSeconds * requiredImprovementRate, SCALAR) <= durationSeconds 
                    || (previousInterestRate != 0 // do not allow rate improvement if rate already 0
                        && previousInterestRate - Math.ceilDiv(previousInterestRate * requiredImprovementRate, SCALAR) >= interestRate), 
                    "insufficient improvement"
                );

                 accumulatedInterest = _interestOwed(
                    previousLoanAmount,
                    loan.lastAccumulatedTimestamp,
                    previousInterestRate,
                    loan.accumulatedInterest
                );
            }

            require(accumulatedInterest < 1 << 128, 
            "interest exceeds uint128");

            loan.perAnnumInterestRate = interestRate;
            loan.lastAccumulatedTimestamp = uint40(block.timestamp);
            loan.durationSeconds = durationSeconds;
            loan.loanAmount = amount;
            loan.accumulatedInterest = uint128(accumulatedInterest);

            address currentLoanOwner = IERC721(lendTicketContract).ownerOf(loanId);
            ILendTicket(lendTicketContract).loanFacilitatorTransfer(currentLoanOwner, sendLendTicketTo, loanId);
            
            if(amountIncrease > 0){
                handleAmountIncreaseBuyoutPayments(
                    loanId, 
                    loan.loanAssetContractAddress,
                    amountIncrease,
                    loan.originationFeeRate,
                    currentLoanOwner,
                    accumulatedInterest,
                    previousLoanAmount
                );
            } else {
                ERC20(loan.loanAssetContractAddress).safeTransferFrom(
                    msg.sender,
                    currentLoanOwner,
                    accumulatedInterest + previousLoanAmount
                );
            }
            
            emit BuyoutLender(loanId, msg.sender, currentLoanOwner, accumulatedInterest, previousLoanAmount);
        }

        emit Lend(loanId, msg.sender, interestRate, amount, durationSeconds);
    }

    /// See {INFTLoanFacilitator-repayAndCloseLoan}.
    function repayAndCloseLoan(uint256 loanId) external override notClosed(loanId) {
        Loan storage loan = loanInfo[loanId];

        uint256 loanAmount = loan.loanAmount;
        uint256 interest = _interestOwed(
            loanAmount,
            loan.lastAccumulatedTimestamp,
            loan.perAnnumInterestRate,
            loan.accumulatedInterest
        );
        address lender = IERC721(lendTicketContract).ownerOf(loanId);
        loan.closed = true;
        ERC20(loan.loanAssetContractAddress).safeTransferFrom(msg.sender, lender, interest + loanAmount);
        IERC721(loan.collateralContractAddress).transferFrom(
            address(this),
            IERC721(borrowTicketContract).ownerOf(loanId),
            loan.collateralTokenId
        );

        emit Repay(loanId, msg.sender, lender, interest, loanAmount);
        emit Close(loanId);
    }

    /// See {INFTLoanFacilitator-seizeCollateral}.
    function seizeCollateral(uint256 loanId, address sendCollateralTo) external override notClosed(loanId) {
        require(IERC721(lendTicketContract).ownerOf(loanId) == msg.sender, 
        "lend ticket holder only");

        Loan storage loan = loanInfo[loanId];
        require(block.timestamp > loan.durationSeconds + loan.lastAccumulatedTimestamp,
        "payment is not late");

        loan.closed = true;
        IERC721(loan.collateralContractAddress).transferFrom(
            address(this),
            sendCollateralTo,
            loan.collateralTokenId
        );

        emit SeizeCollateral(loanId);
        emit Close(loanId);
    }

    /// @dev If we allowed ERC777 tokens, 
    /// a malicious lender could revert in 
    /// tokensReceived and block buyouts or repayment.
    /// So we do not support ERC777 tokens.
    function tokensReceived(
        address,
        address,
        address,
        uint256,
        bytes calldata,
        bytes calldata
    ) external pure override {
        revert('ERC777 unsupported');
    }

    
    // === owner state changing ===

    /**
     * @notice Sets lendTicketContract to _contract
     * @dev cannot be set if lendTicketContract is already set
     */
    function setLendTicketContract(address _contract) external onlyOwner {
        require(lendTicketContract == address(0), 'already set');

        lendTicketContract = _contract;
    }

    /**
     * @notice Sets borrowTicketContract to _contract
     * @dev cannot be set if borrowTicketContract is already set
     */
    function setBorrowTicketContract(address _contract) external onlyOwner {
        require(borrowTicketContract == address(0), 'already set');

        borrowTicketContract = _contract;
    }

    /// @notice Transfers `amount` of loan origination fees for `asset` to `to`
    function withdrawOriginationFees(address asset, uint256 amount, address to) external onlyOwner {
        ERC20(asset).safeTransfer(to, amount);

        emit WithdrawOriginationFees(asset, amount, to);
    }

    /**
     * @notice Updates originationFeeRate the facilitator keeps of each loan amount
     * @dev Cannot be set higher than 5%
     */
    function updateOriginationFeeRate(uint32 _originationFeeRate) external onlyOwner {
        require(_originationFeeRate <= 5 * (10 ** (INTEREST_RATE_DECIMALS - 2)), "max fee 5%");
        
        originationFeeRate = _originationFeeRate;

        emit UpdateOriginationFeeRate(_originationFeeRate);
    }

    /**
     * @notice updates the percent improvement required of at least one loan term when buying out lender 
     * a loan that already has a lender. E.g. setting this value to 100 means duration or amount
     * must be 10% higher or interest rate must be 10% lower. 
     * @dev Cannot be 0.
     */
    function updateRequiredImprovementRate(uint256 _improvementRate) external onlyOwner {
        require(_improvementRate != 0, '0 improvement rate');

        requiredImprovementRate = _improvementRate;

        emit UpdateRequiredImprovementRate(_improvementRate);
    }

    
    // ==== external view ====

    /// See {INFTLoanFacilitator-loanInfoStruct}.
    function loanInfoStruct(uint256 loanId) external view override returns (Loan memory) {
        return loanInfo[loanId];
    }

    /// See {INFTLoanFacilitator-totalOwed}.
    function totalOwed(uint256 loanId) external view override returns (uint256) {
        Loan storage loan = loanInfo[loanId];
        uint256 lastAccumulated = loan.lastAccumulatedTimestamp;
        if (loan.closed || lastAccumulated == 0) return 0;

        return loanInfo[loanId].loanAmount + _interestOwed(
            loan.loanAmount,
            lastAccumulated,
            loan.perAnnumInterestRate,
            loan.accumulatedInterest
        );
    }

    /// See {INFTLoanFacilitator-interestOwed}.
    function interestOwed(uint256 loanId) external view override returns (uint256) {
        Loan storage loan = loanInfo[loanId];
        uint256 lastAccumulated = loan.lastAccumulatedTimestamp;
        if (loan.closed || lastAccumulated == 0) return 0;

        return _interestOwed(
            loan.loanAmount,
            lastAccumulated,
            loan.perAnnumInterestRate,
            loan.accumulatedInterest
        );
    }

    /// See {INFTLoanFacilitator-loanEndSeconds}.
    function loanEndSeconds(uint256 loanId) external view override returns (uint256) {
        Loan storage loan = loanInfo[loanId];
        uint256 lastAccumulated;
        require((lastAccumulated = loan.lastAccumulatedTimestamp) != 0, 'loan has no lender');
        
        return loan.durationSeconds + lastAccumulated;
    }

    
    // === internal & private ===

    /// @dev Returns the total interest owed on loan
    function _interestOwed(
        uint256 loanAmount,
        uint256 lastAccumulatedTimestamp,
        uint256 perAnnumInterestRate,
        uint256 accumulatedInterest
    ) 
        internal 
        view 
        returns (uint256) 
    {
        return loanAmount
            * (block.timestamp - lastAccumulatedTimestamp)
            * (perAnnumInterestRate * 1e18 / 365 days)
            / 1e21 // SCALAR * 1e18
            + accumulatedInterest;
    }

    /// @dev handles erc20 payments in case of lender buyout
    /// with increased loan amount
    function handleAmountIncreaseBuyoutPayments(
        uint256 loanId,
        address loanAssetContractAddress,
        uint256 amountIncrease,
        uint256 loanOriginationFeeRate,
        address currentLoanOwner,
        uint256 accumulatedInterest,
        uint256 previousLoanAmount
    ) 
        private 
    {
        uint256 facilitatorTake = (amountIncrease * loanOriginationFeeRate / SCALAR);

        ERC20(loanAssetContractAddress).safeTransferFrom(msg.sender, address(this), facilitatorTake);

        ERC20(loanAssetContractAddress).safeTransferFrom(
            msg.sender,
            currentLoanOwner,
            accumulatedInterest + previousLoanAmount
        );

        ERC20(loanAssetContractAddress).safeTransferFrom(
            msg.sender,
            IERC721(borrowTicketContract).ownerOf(loanId),
            amountIncrease - facilitatorTake
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import 'base64-sol/base64.sol';
import '../NFTLoanFacilitator.sol';
import './libraries/NFTLoanTicketSVG.sol';
import './libraries/PopulateSVGParams.sol';

contract NFTLoansTicketDescriptor {
    // Lend or Borrow 
    string public nftType;
    ITicketTypeSpecificSVGHelper immutable public svgHelper;

    /// @dev Initializes the contract by setting a `nftType` and `svgHelper`
    constructor(string memory _nftType, ITicketTypeSpecificSVGHelper _svgHelper) {
        nftType = _nftType;
        svgHelper = _svgHelper;
    }

    /**
     * @dev Returns a string which is a data uri of base64 encoded JSON,
     * the JSON contains the token metadata: name, description, image
     * which reflect information about `id` loan in `nftLoanFacilitator`
     */ 
    function uri(NFTLoanFacilitator nftLoanFacilitator, uint256 id)
        external
        view
        returns (string memory)
    {
        NFTLoanTicketSVG.SVGParams memory svgParams;
        svgParams.nftType = nftType;
        svgParams = PopulateSVGParams.populate(svgParams, nftLoanFacilitator, id);
        
        return generateDescriptor(svgParams);
    }

    /**
     * @dev Returns a string which is a data uri of base64 encoded JSON,
     * the JSON contains the token metadata: name, description, image.
     * The metadata values come from `svgParams`
     */ 
    function generateDescriptor(NFTLoanTicketSVG.SVGParams memory svgParams)
        private
        view
        returns (string memory)
    {
        return string.concat(
            'data:application/json;base64,',
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name":"',
                        svgParams.nftType,
                        ' ticket',
                        ' #',
                        svgParams.id,
                        '", "description":"',
                        generateDescription(svgParams.id),
                        generateDescriptionDetails(
                            svgParams.loanAssetContract,
                            svgParams.loanAssetSymbol,
                            svgParams.collateralContract, 
                            svgParams.collateralAssetSymbol,
                            svgParams.collateralId),
                        '", "image": "',
                        'data:image/svg+xml;base64,',
                        Base64.encode(bytes(NFTLoanTicketSVG.generateSVG(svgParams, svgHelper))),
                        '"}'
                    )
                )
            )
        );
    }

    /// @dev Returns string, ticket type (borrow or lend) specific description      
    function generateDescription(string memory loanId) internal pure virtual returns (string memory) {}

    /// @dev Returns string, important info about the loan that this ticket is related to 
    function generateDescriptionDetails(
        string memory loanAsset,
        string memory loanAssetSymbol,
        string memory collateralAsset,
        string memory collateralAssetSymbol,
        string memory collateralAssetId
    ) 
        private 
        pure 
        returns (string memory) 
    {
        return string.concat(
            '\\n\\nCollateral Address: ',
            collateralAsset,
            ' (',
            collateralAssetSymbol,
            ')\\n\\n',
            'Collateral ID: ',
            collateralAssetId,
            '\\n\\n',
            'Loan Asset Address: ',
            loanAsset,
            ' (',
            loanAssetSymbol,
            ')\\n\\n',
            'WARNING: Do your own research to verify the legitimacy of the assets related to this ticket'
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IERC721Mintable {
    /**
     * @notice mints an ERC721 token of tokenId to the to address
     * @dev only callable by nft loan facilitator
     * @param to The address to send the token to
     * @param tokenId The id of the token to mint
     */
    function mint(address to, uint256 tokenId) external;
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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Gnosis (https://github.com/gnosis/gp-v2-contracts/blob/main/src/contracts/libraries/GPv2SafeERC20.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
library SafeTransferLib {
    /*///////////////////////////////////////////////////////////////
                            ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(callStatus, "ETH_TRANSFER_FAILED");
    }

    /*///////////////////////////////////////////////////////////////
                           ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000) // Begin with the function selector.
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 100 because the calldata length is 4 + 32 * 3.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 100, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // Begin with the function selector.
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 68 because the calldata length is 4 + 32 * 2.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000) // Begin with the function selector.
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 68 because the calldata length is 4 + 32 * 2.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), "APPROVE_FAILED");
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HELPER LOGIC
    //////////////////////////////////////////////////////////////*/

    function didLastOptionalReturnCallSucceed(bool callStatus) private pure returns (bool success) {
        assembly {
            // Get how many bytes the call returned.
            let returnDataSize := returndatasize()

            // If the call reverted:
            if iszero(callStatus) {
                // Copy the revert message into memory.
                returndatacopy(0, 0, returnDataSize)

                // Revert with the same message.
                revert(0, returnDataSize)
            }

            switch returnDataSize
            case 32 {
                // Copy the return data into memory.
                returndatacopy(0, 0, returnDataSize)

                // Set success to whether it returned true.
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // There was no return data.
                success := 1
            }
            default {
                // It returned some malformed input.
                success := 0
            }
        }
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC1820Registry.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the global ERC1820 Registry, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1820[EIP]. Accounts may register
 * implementers for interfaces in this registry, as well as query support.
 *
 * Implementers may be shared by multiple accounts, and can also implement more
 * than a single interface for each account. Contracts can implement interfaces
 * for themselves, but externally-owned accounts (EOA) must delegate this to a
 * contract.
 *
 * {IERC165} interfaces can also be queried via the registry.
 *
 * For an in-depth explanation and source code analysis, see the EIP text.
 */
interface IERC1820Registry {
    /**
     * @dev Sets `newManager` as the manager for `account`. A manager of an
     * account is able to set interface implementers for it.
     *
     * By default, each account is its own manager. Passing a value of `0x0` in
     * `newManager` will reset the manager to this initial state.
     *
     * Emits a {ManagerChanged} event.
     *
     * Requirements:
     *
     * - the caller must be the current manager for `account`.
     */
    function setManager(address account, address newManager) external;

    /**
     * @dev Returns the manager for `account`.
     *
     * See {setManager}.
     */
    function getManager(address account) external view returns (address);

    /**
     * @dev Sets the `implementer` contract as ``account``'s implementer for
     * `interfaceHash`.
     *
     * `account` being the zero address is an alias for the caller's address.
     * The zero address can also be used in `implementer` to remove an old one.
     *
     * See {interfaceHash} to learn how these are created.
     *
     * Emits an {InterfaceImplementerSet} event.
     *
     * Requirements:
     *
     * - the caller must be the current manager for `account`.
     * - `interfaceHash` must not be an {IERC165} interface id (i.e. it must not
     * end in 28 zeroes).
     * - `implementer` must implement {IERC1820Implementer} and return true when
     * queried for support, unless `implementer` is the caller. See
     * {IERC1820Implementer-canImplementInterfaceForAddress}.
     */
    function setInterfaceImplementer(
        address account,
        bytes32 _interfaceHash,
        address implementer
    ) external;

    /**
     * @dev Returns the implementer of `interfaceHash` for `account`. If no such
     * implementer is registered, returns the zero address.
     *
     * If `interfaceHash` is an {IERC165} interface id (i.e. it ends with 28
     * zeroes), `account` will be queried for support of it.
     *
     * `account` being the zero address is an alias for the caller's address.
     */
    function getInterfaceImplementer(address account, bytes32 _interfaceHash) external view returns (address);

    /**
     * @dev Returns the interface hash for an `interfaceName`, as defined in the
     * corresponding
     * https://eips.ethereum.org/EIPS/eip-1820#interface-name[section of the EIP].
     */
    function interfaceHash(string calldata interfaceName) external pure returns (bytes32);

    /**
     * @notice Updates the cache with whether the contract implements an ERC165 interface or not.
     * @param account Address of the contract for which to update the cache.
     * @param interfaceId ERC165 interface for which to update the cache.
     */
    function updateERC165Cache(address account, bytes4 interfaceId) external;

    /**
     * @notice Checks whether a contract implements an ERC165 interface or not.
     * If the result is not cached a direct lookup on the contract address is performed.
     * If the result is not cached or the cached value is out-of-date, the cache MUST be updated manually by calling
     * {updateERC165Cache} with the contract address.
     * @param account Address of the contract to check.
     * @param interfaceId ERC165 interface to check.
     * @return True if `account` implements `interfaceId`, false otherwise.
     */
    function implementsERC165Interface(address account, bytes4 interfaceId) external view returns (bool);

    /**
     * @notice Checks whether a contract implements an ERC165 interface or not without using nor updating the cache.
     * @param account Address of the contract to check.
     * @param interfaceId ERC165 interface to check.
     * @return True if `account` implements `interfaceId`, false otherwise.
     */
    function implementsERC165InterfaceNoCache(address account, bytes4 interfaceId) external view returns (bool);

    event InterfaceImplementerSet(address indexed account, bytes32 indexed interfaceHash, address indexed implementer);

    event ManagerChanged(address indexed account, address indexed newManager);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC777/IERC777Recipient.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC777TokensRecipient standard as defined in the EIP.
 *
 * Accounts can be notified of {IERC777} tokens being sent to them by having a
 * contract implement this interface (contract holders can be their own
 * implementer) and registering it on the
 * https://eips.ethereum.org/EIPS/eip-1820[ERC1820 global registry].
 *
 * See {IERC1820Registry} and {ERC1820Implementer}.
 */
interface IERC777Recipient {
    /**
     * @dev Called by an {IERC777} token contract whenever tokens are being
     * moved or created into a registered account (`to`). The type of operation
     * is conveyed by `from` being the zero address or not.
     *
     * This call occurs _after_ the token contract's state is updated, so
     * {IERC777-balanceOf}, etc., can be used to query the post-operation state.
     *
     * This function may revert to prevent the operation from being executed.
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface INFTLoanFacilitator {
    /// @notice See loanInfo
    struct Loan {
        bool closed;
        uint16 perAnnumInterestRate;
        uint32 durationSeconds;
        uint40 lastAccumulatedTimestamp;
        address collateralContractAddress;
        bool allowLoanAmountIncrease;
        uint88 originationFeeRate;
        address loanAssetContractAddress;
        uint128 accumulatedInterest;
        uint128 loanAmount;
        uint256 collateralTokenId;
    }

    /**
     * @notice The magnitude of SCALAR
     * @dev 10^INTEREST_RATE_DECIMALS = 1 = 100%
     */
    function INTEREST_RATE_DECIMALS() external view returns (uint8);

    /**
     * @notice The SCALAR for all percentages in the loan facilitator contract
     * @dev Any interest rate passed to a function should already been multiplied by SCALAR
     */
    function SCALAR() external view returns (uint256);

    /**
     * @notice The percent of the loan amount that the facilitator will take as a fee, scaled by SCALAR
     * @dev Starts set to 1%. Can only be set to 0 - 5%. 
     */
    function originationFeeRate() external view returns (uint256);

    /**
     * @notice The lend ticket contract associated with this loan facilitator
     * @dev Once set, cannot be modified
     */
    function lendTicketContract() external view returns (address);

    /**
     * @notice The borrow ticket contract associated with this loan facilitator
     * @dev Once set, cannot be modified
     */
    function borrowTicketContract() external view returns (address);

    /**
     * @notice The percent improvement required of at least one loan term when buying out current lender 
     * a loan that already has a lender, scaled by SCALAR. 
     * E.g. setting this value to 100 (10%) means, when replacing a lender, the new loan terms must have
     * at least 10% greater duration or loan amount or at least 10% lower interest rate. 
     * @dev Starts at 100 = 10%. Only owner can set. Cannot be set to 0.
     */
    function requiredImprovementRate() external view returns (uint256);
    
    /**
     * @notice Emitted when the loan is created
     * @param id The id of the new loan, matches the token id of the borrow ticket minted in the same transaction
     * @param minter msg.sender
     * @param collateralTokenId The token id of the collateral NFT
     * @param collateralContract The contract address of the collateral NFT
     * @param maxInterestRate The max per anum interest rate, scaled by SCALAR
     * @param loanAssetContract The contract address of the loan asset
     * @param minLoanAmount mimimum loan amount
     * @param minDurationSeconds minimum loan duration in seconds
    */
    event CreateLoan(
        uint256 indexed id,
        address indexed minter,
        uint256 collateralTokenId,
        address collateralContract,
        uint256 maxInterestRate,
        address loanAssetContract,
        bool allowLoanAmountIncrease,
        uint256 minLoanAmount,
        uint256 minDurationSeconds
        );

    /** 
     * @notice Emitted when ticket is closed
     * @param id The id of the ticket which has been closed
     */
    event Close(uint256 indexed id);

    /** 
     * @notice Emitted when the loan is lent to
     * @param id The id of the loan which is being lent to
     * @param lender msg.sender
     * @param interestRate The per anum interest rate, scaled by SCALAR, for the loan
     * @param loanAmount The loan amount
     * @param durationSeconds The loan duration in seconds 
     */
    event Lend(
        uint256 indexed id,
        address indexed lender,
        uint256 interestRate,
        uint256 loanAmount,
        uint256 durationSeconds
    );

    /**
     * @notice Emitted when a lender is being bought out: 
     * the current loan ticket holder is being replaced by a new lender offering better terms
     * @param lender msg.sender
     * @param replacedLoanOwner The current loan ticket holder
     * @param interestEarned The amount of interest the loan has accrued from first lender to this buyout
     * @param replacedAmount The loan amount prior to buyout
     */    
    event BuyoutLender(
        uint256 indexed id,
        address indexed lender,
        address indexed replacedLoanOwner,
        uint256 interestEarned,
        uint256 replacedAmount
    );
    
    /**
     * @notice Emitted when loan is repaid
     * @param id The loan id
     * @param repayer msg.sender
     * @param loanOwner The current holder of the lend ticket for this loan, token id matching the loan id
     * @param interestEarned The total interest accumulated on the loan
     * @param loanAmount The loan amount
     */
    event Repay(
        uint256 indexed id,
        address indexed repayer,
        address indexed loanOwner,
        uint256 interestEarned,
        uint256 loanAmount
    );

    /**
     * @notice Emitted when loan NFT collateral is seized 
     * @param id The ticket id
     */
    event SeizeCollateral(uint256 indexed id);

     /**
      * @notice Emitted when origination fees are withdrawn
      * @dev only owner can call
      * @param asset the ERC20 asset withdrawn
      * @param amount the amount withdrawn
      * @param to the address the withdrawn amount was sent to
      */
     event WithdrawOriginationFees(address asset, uint256 amount, address to);

      /**
      * @notice Emitted when originationFeeRate is updated
      * @dev only owner can call, value is scaled by SCALAR, 100% = SCALAR
      * @param feeRate the new origination fee rate
      */
     event UpdateOriginationFeeRate(uint32 feeRate);

     /**
      * @notice Emitted when requiredImprovementRate is updated
      * @dev only owner can call, value is scaled by SCALAR, 100% = SCALAR
      * @param improvementRate the new required improvementRate
      */
     event UpdateRequiredImprovementRate(uint256 improvementRate);

    /**
     * @notice (1) transfers the collateral NFT to the loan facilitator contract 
     * (2) creates the loan, populating loanInfo in the facilitator contract,
     * and (3) mints a Borrow Ticket to mintBorrowTicketTo
     * @dev loan duration or loan amount cannot be 0, 
     * this is done to protect borrowers from accidentally passing a default value
     * and also because it creates odd lending and buyout behavior: possible to lend
     * for 0 value or 0 duration, and possible to buyout with no improvement because, for example
     * previousDurationSeconds + (previousDurationSeconds * requiredImprovementRate / SCALAR) <= durationSeconds
     * evaluates to true if previousDurationSeconds is 0 and durationSeconds is 0.
     * loanAssetContractAddress cannot be address(0), we check this because Solmate SafeTransferLib
     * does not revert with address(0) and this could cause odd behavior.
     * collateralContractAddress cannot be address(borrowTicket) or address(lendTicket).
     * @param collateralTokenId The token id of the collateral NFT 
     * @param collateralContractAddress The contract address of the collateral NFT
     * @param maxPerAnnumInterest The maximum per anum interest rate for this loan, scaled by SCALAR
     * @param allowLoanAmountIncrease Whether the borrower is open to lenders offerring greater than minLoanAmount
     * @param minLoanAmount The minimum acceptable loan amount for this loan
     * @param loanAssetContractAddress The address of the loan asset
     * @param minDurationSeconds The minimum duration for this loan
     * @param mintBorrowTicketTo An address to mint the Borrow Ticket corresponding to this loan to
     * @return id of the created loan
     */
    function createLoan(
            uint256 collateralTokenId,
            address collateralContractAddress,
            uint16 maxPerAnnumInterest,
            bool allowLoanAmountIncrease,
            uint128 minLoanAmount,
            address loanAssetContractAddress,
            uint32 minDurationSeconds,
            address mintBorrowTicketTo
    ) external returns (uint256 id);

    /**
     * @notice Closes the loan, sends the NFT collateral to sendCollateralTo
     * @dev Can only be called by the holder of the Borrow Ticket with tokenId
     * matching the loanId. Can only be called if loan has no lender,
     * i.e. lastAccumulatedInterestTimestamp = 0
     * @param loanId The loan id
     * @param sendCollateralTo The address to send the collateral NFT to
     */
    function closeLoan(uint256 loanId, address sendCollateralTo) external;

    /**
     * @notice Lends, meeting or beating the proposed loan terms, 
     * transferring `amount` of the loan asset 
     * to the facilitator contract. If the loan has not yet been lent to, 
     * a Lend Ticket is minted to `sendLendTicketTo`. If the loan has already been 
     * lent to, then this is a buyout, and the Lend Ticket will be transferred
     * from the current holder to `sendLendTicketTo`. Also in the case of a buyout, interestOwed()
     * is transferred from the caller to the facilitator contract, in addition to `amount`, and
     * totalOwed() is paid to the current Lend Ticket holder.
     * @dev Loan terms must meet or beat loan terms. If a buyout, at least one loan term
     * must be improved by at least 10%. E.g. 10% longer duration, 10% lower interest, 
     * 10% higher amount
     * @param loanId The loan id
     * @param interestRate The per anum interest rate, scaled by SCALAR
     * @param amount The loan amount
     * @param durationSeconds The loan duration in seconds
     * @param sendLendTicketTo The address to send the Lend Ticket to
     */
    function lend(
            uint256 loanId,
            uint16 interestRate,
            uint128 amount,
            uint32 durationSeconds,
            address sendLendTicketTo
    ) external;

    /**
     * @notice repays and closes the loan, transferring totalOwed() to the current Lend Ticket holder
     * and transferring the collateral NFT to the Borrow Ticket holder.
     * @param loanId The loan id
     */
    function repayAndCloseLoan(uint256 loanId) external;

    /**
     * @notice Transfers the collateral NFT to `sendCollateralTo` and closes the loan.
     * @dev Can only be called by Lend Ticket holder. Can only be called 
     * if block.timestamp > loanEndSeconds()
     * @param loanId The loan id
     * @param sendCollateralTo The address to send the collateral NFT to
     */
    function seizeCollateral(uint256 loanId, address sendCollateralTo) external;

    /**
     * @notice returns the info for this loan
     * @param loanId The id of the loan
     * @return closed Whether or not the ticket is closed
     * @return perAnnumInterestRate The per anum interest rate, scaled by SCALAR
     * @return durationSeconds The loan duration in seconds
     
     * @return lastAccumulatedTimestamp The timestamp (in seconds) when interest was last accumulated, 
     * i.e. the timestamp of the most recent lend
     * @return collateralContractAddress The contract address of the NFT collateral 
     * @return allowLoanAmountIncrease
     * @return originationFeeRate
     * @return loanAssetContractAddress The contract address of the loan asset.
     * @return accumulatedInterest The amount of interest accumulated on the loan prior to the current lender
     * @return loanAmount The loan amount
     * @return collateralTokenId The token ID of the NFT collateral
     */
    function loanInfo(uint256 loanId)
        external 
        view 
        returns (
            bool closed,
            uint16 perAnnumInterestRate,
            uint32 durationSeconds,
            uint40 lastAccumulatedTimestamp,
            address collateralContractAddress,
            bool allowLoanAmountIncrease,
            uint88 originationFeeRate,
            address loanAssetContractAddress,
            uint128 accumulatedInterest,
            uint128 loanAmount,
            uint256 collateralTokenId
        );

    /**
     * @notice returns the info for this loan
     * @dev this is a convenience method for other contracts that would prefer to have the 
     * Loan object not decomposed. 
     * @param loanId The id of the loan
     * @return Loan struct corresponding to loanId
     */
    function loanInfoStruct(uint256 loanId) external view returns (Loan memory);

    /**
     * @notice returns the total amount owed for the loan, i.e. principal + interest
     * @param loanId The loan id
     * @return amount required to repay and close the loan corresponding to loanId
     */
    function totalOwed(uint256 loanId) view external returns (uint256);

    /**
     * @notice returns the interest owed on the loan, in loan asset units
     * @param loanId The loan id
     * @return amount of interest owed on loan corresonding to loanId
     */
    function interestOwed(uint256 loanId) view external returns (uint256);

    /**
     * @notice returns the unix timestamp (seconds) of the loan end
     * @param loanId The loan id
     * @return timestamp at which loan payment is due, after which lend ticket holder
     * can seize collateral
     */
    function loanEndSeconds(uint256 loanId) view external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface ILendTicket {
    /**
     * @notice Transfers a lend ticket
     * @dev can only be called by nft loan facilitator
     * @param from The current holder of the lend ticket
     * @param to Address to send the lend ticket to
     * @param loanId The lend ticket token id, which is also the loan id in the facilitator contract
     */
    function loanFacilitatorTransfer(address from, address to, uint256 loanId) external;
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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*///////////////////////////////////////////////////////////////
                             EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                              EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
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

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides a function for encoding some bytes in base64
library Base64 {
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
        
        // load the table into memory
        string memory table = TABLE;

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
               dataPtr := add(dataPtr, 3)
               
               // read 3 bytes
               let input := mload(dataPtr)
               
               // write 4 characters
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
               resultPtr := add(resultPtr, 1)
            }
            
            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }
        
        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import 'base64-sol/base64.sol';
import '../../interfaces/ITicketTypeSpecificSVGHelper.sol';


library NFTLoanTicketSVG {

    struct SVGParams{
        // "Borrow" or "Lend"
        string nftType;
        // The Token Id, which is also the Id of the associated loan in NFTLoanFacilitator
        string id;
        // Human readable status, see {PopulateSVGParams-loanStatus}
        string status;
        // The approximate APR loan interest rate
        string interestRate;
        // The contract address of the ERC20 loan asset
        string loanAssetContract;
        // The symbol of the ERC20 loan asset
        string loanAssetSymbol;
        // The contract address of the ERC721 collateral asset
        string collateralContract;
        // The contract address of the ERC721 collateral asset, shortened for display
        string collateralContractPartial;
        // Symbol of the ERC721 collateral asset
        string collateralAssetSymbol;
        // TokenId of the ERC721 collateral asset
        string collateralId;
        // The loan amount, in loan asset units
        string loanAmount;
        // The interest accrued so far on the loan, in loan asset units
        string interestAccrued;
        // The loan duration in days, 0 if duration is less than 1 day
        string durationDays;
        // The UTC end date and time of the loan, 'n/a' if loan does not have lender
        string endDateTime;
    }

    /// @notice returns an SVG image as a string. The SVG image is specific to the SVGParams
    function generateSVG(SVGParams memory params, ITicketTypeSpecificSVGHelper typeSpecificHelper) 
    internal 
    pure 
    returns (string memory svg) 
    {
        return string.concat(
            '<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" ',
            'xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" ',
            'viewBox="0 0 300 300" style="enable-background:new 0 0 300 300;" xml:space="preserve">',
            stylesAndBackground(
                typeSpecificHelper,
                params.id,
                params.loanAssetContract,
                params.collateralContract
            ),
            staticValues(params.nftType, typeSpecificHelper),
            dynamicValues(params, typeSpecificHelper),
            dynamicValues2(params),
            '</svg>'
        );
    }

    function stylesAndBackground(
        ITicketTypeSpecificSVGHelper typeSpecificHelper,
        string memory id, 
        string memory loanAsset,
        string memory collateralAsset
    ) 
        private 
        pure
        returns (string memory) 
    {
        return string.concat(
            '<style type="text/css">',
                '.st0{fill:url(#wash);}',
                '.st1{width: 171px; height: 23px; opacity:0.65; fill:#FFFFFF;}',
                '.st2{width: 171px; height: 23px; opacity:0.45; fill:#FFFFFF;}',
                '.st3{width: 98px; height: 23px; opacity:0.2; fill:#FFFFFF;}',
                '.st4{width: 98px; height: 23px; opacity:0.35; fill:#FFFFFF;}',
                '.st5{font-family: monospace, monospace; font-size: 28px;}',
                '.st7{font-family: monospace, monospace; font-size:10px; fill:#000000; opacity: .9;}',
                '.st8{width: 98px; height: 54px; opacity:0.35; fill:#FFFFFF;}',
                '.st9{width: 171px; height: 54px; opacity:0.65; fill:#FFFFFF;}',
                '.right{text-anchor: end;}',
                '.left{text-anchor: start;}',
                typeSpecificHelper.backgroundColorsStyles(loanAsset, collateralAsset),
            '</style>',
            '<defs>',
                '<radialGradient id="wash" cx="120" cy="40" r="140" gradientTransform="skewY(5)" ',
                'gradientUnits="userSpaceOnUse">',
                    '<stop  offset="0%" class="highlight-hue"/>',
                    '<stop  offset="100%" class="highlight-offset"/>',
                    '<animate attributeName="r" values="300;520;320;420;300" dur="25s" repeatCount="indefinite"/>',
                    '<animate attributeName="cx" values="120;420;260;120;60;120" dur="25s" repeatCount="indefinite"/>',
                    '<animate attributeName="cy" values="40;300;40;250;390;40" dur="25s" repeatCount="indefinite"/>',
                '</radialGradient>',
            '</defs>',
            '<rect x="0" class="st0" width="300" height="300"/>',
            '<rect y="31" x="',
            typeSpecificHelper.backgroundValueRectsXTranslate(),
            '" width="171" height="54" style="opacity:0.65; fill:#FFFFFF;"/>',
            '<text x="',
            typeSpecificHelper.ticketIdXCoordinate(),
            '" y="69" class="st5 ',
            typeSpecificHelper.alignmentClass(),
            '" fill="black">',
            id,
            '</text>'
        );
    }

    function staticValues(
        string memory ticketType,
        ITicketTypeSpecificSVGHelper typeSpecificHelper
    )
        private
        pure
        returns (string memory) 
    {
        return string.concat(
            '<g transform="translate(',
            typeSpecificHelper.backgroundTitleRectsXTranslate(),
            ',0)">',
                '<rect y="31" class="st8"/>',
                '<rect y="85" class="st3"/>',
                '<rect y="108" class="st4"/>',
                '<rect y="131" class="st3"/>',
                '<rect y="154" class="st4"/>',
                '<rect y="177" class="st3"/>',
                '<rect y="200" class="st4"/>',
                '<rect y="223" class="st3"/>',
                '<rect y="246" class="st4"/>',
            '</g>',
            '<g class="st7 ',
            typeSpecificHelper.titlesPositionClass(),
            '" transform="translate(',
            typeSpecificHelper.titlesXTranslate(),
            ',0)">',
                '<text y="56">',
                ticketType,
                'er</text>',
                '<text y="70">Ticket</text>',
                '<text y="99">Loan Amount</text>',
                '<text y="122">Interest Rate</text>',
                '<text y="145">Status</text>',
                '<text y="168">Accrued</text>',
                '<text y="191">Collateral NFT</text>',
                '<text y="214">Collateral ID</text>',
                '<text y="237">Duration</text>',
                '<text y="260">End Date</text>',
            '</g>',
            '<g transform="translate(',
            typeSpecificHelper.backgroundValueRectsXTranslate(),
            ',0)">',
                '<rect y="246" class="st1"/>',
                '<rect y="223" class="st2"/>',
                '<rect y="200" class="st1"/>',
                '<rect y="177" class="st2"/>',
                '<rect y="154" class="st1"/>',
                '<rect y="131" class="st2"/>',
                '<rect y="108" class="st1"/>',
                '<rect y="85" class="st2"/>',
            '</g>'
        );
    }

    function dynamicValues(
        SVGParams memory params, 
        ITicketTypeSpecificSVGHelper typeSpecificHelper
    ) 
        private
        pure
        returns (string memory) 
    {
        return string.concat(
            '<g class="st7 ',
            typeSpecificHelper.alignmentClass(),
            '" transform="translate(',
            typeSpecificHelper.valuesXTranslate(),
            ',0)">',
            '<text y="99">',
            params.loanAmount, 
            ' ',
            params.loanAssetSymbol,
            '</text>',
            '<text y="122">',
            params.interestRate,
            '</text>',
            '<text y="145">',
            params.status,
            '</text>',
            '<text y="168">'
        );
    }

    function dynamicValues2(
        SVGParams memory params
    ) 
        private 
        pure 
        returns (string memory) 
    {
        return string.concat(
            params.interestAccrued,
            ' ',
            params.loanAssetSymbol,
            '</text>',
            '<text y="191">(',
            params.collateralAssetSymbol,
            ') ',
            params.collateralContractPartial,
            '</text>',
            '<text y="214">',
            params.collateralId,
            '</text>',
            '<text y="237">',
            params.durationDays,
            ' days </text>',
            '<text y="260">',
            params.endDateTime,
            '</text>',
            '</g>'
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import './BokkyPooBahsDateTimeLibrary.sol';
import './UintStrings.sol';
import '../../interfaces/INFTLoanFacilitator.sol';
import '../../interfaces/IERC20Metadata.sol';
import './HexStrings.sol';
import './NFTLoanTicketSVG.sol';


library PopulateSVGParams{
    /**
     * @notice Populates and returns the passed `svgParams` with loan info retrieved from
     * `nftLoanFacilitator` for `id`, the loan id
     * @param svgParams The svg params to populate, which already has `nftType` populated from NFTLoansTicketDescriptor
     * @param nftLoanFacilitator The loan facilitator contract to get loan info from for loan `id`
     * @param id The id of the loan
     * @return `svgParams`, with all values now populated
     */
    function populate(NFTLoanTicketSVG.SVGParams memory svgParams, INFTLoanFacilitator nftLoanFacilitator, uint256 id)
        internal
        view
        returns (NFTLoanTicketSVG.SVGParams memory)
    {
        INFTLoanFacilitator.Loan memory loan = nftLoanFacilitator.loanInfoStruct(id);

        svgParams.id = Strings.toString(id);
        svgParams.status = loanStatus(loan.lastAccumulatedTimestamp, loan.durationSeconds, loan.closed);
        svgParams.interestRate = interestRateString(nftLoanFacilitator, loan.perAnnumInterestRate); 
        svgParams.loanAssetContract = HexStrings.toHexString(uint160(loan.loanAssetContractAddress), 20);
        svgParams.loanAssetSymbol = loanAssetSymbol(loan.loanAssetContractAddress);
        svgParams.collateralContract = HexStrings.toHexString(uint160(loan.collateralContractAddress), 20);
        svgParams.collateralContractPartial = HexStrings.partialHexString(uint160(loan.collateralContractAddress), 10, 40);
        svgParams.collateralAssetSymbol = collateralAssetSymbol(loan.collateralContractAddress);
        svgParams.collateralId = Strings.toString(loan.collateralTokenId);
        svgParams.loanAmount = loanAmountString(loan.loanAmount, loan.loanAssetContractAddress);
        svgParams.interestAccrued = accruedInterest(nftLoanFacilitator, id, loan.loanAssetContractAddress);
        svgParams.durationDays = Strings.toString(loan.durationSeconds / (24 * 60 * 60));
        svgParams.endDateTime = loan.lastAccumulatedTimestamp == 0 ? "n/a" 
        : endDateTime(loan.lastAccumulatedTimestamp + loan.durationSeconds);
        
        return svgParams;
    }

    function interestRateString(INFTLoanFacilitator nftLoanFacilitator, uint256 perAnnumInterestRate) 
        private 
        view 
        returns (string memory)
    {
        return UintStrings.decimalString(
            perAnnumInterestRate,
            nftLoanFacilitator.INTEREST_RATE_DECIMALS() - 2,
            true
            );
    }

    function loanAmountString(uint256 amount, address asset) private view returns (string memory) {
        return UintStrings.decimalString(amount, IERC20Metadata(asset).decimals(), false);
    }

    function loanAssetSymbol(address asset) private view returns (string memory) {
        return IERC20Metadata(asset).symbol();
    }

    function collateralAssetSymbol(address asset) private view returns (string memory) {
        return ERC721(asset).symbol();
    }

    function accruedInterest(INFTLoanFacilitator nftLoanFacilitator, uint256 loanId, address loanAsset) 
        private 
        view 
        returns (string memory)
    {
        return UintStrings.decimalString(
            nftLoanFacilitator.interestOwed(loanId),
            IERC20Metadata(loanAsset).decimals(),
            false);
    }

    function loanStatus(uint256 lastAccumulatedTimestamp, uint256 durationSeconds, bool closed) 
        view 
        private 
        returns (string memory)
    {
        if (lastAccumulatedTimestamp == 0) return "awaiting lender";

        if (closed) return "closed";

        if (block.timestamp > (lastAccumulatedTimestamp + durationSeconds)) return "past due";

        return "accruing interest";
    }

    /** 
     * @param endDateSeconds The unix seconds timestamp of the loan end date
     * @return a string representation of the UTC end date and time of the loan,
     * in format YYYY-MM-DD HH:MM:SS
     */
    function endDateTime(uint256 endDateSeconds) private pure returns (string memory) {
        (uint year, uint month, 
        uint day, uint hour, 
        uint minute, uint second) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(endDateSeconds);
        return string.concat(
                Strings.toString(year),
                '-',
                Strings.toString(month),
                '-',
                Strings.toString(day),
                ' ',
                Strings.toString(hour),
                ':',
                Strings.toString(minute),
                ':',
                Strings.toString(second),
                ' UTC'
        );
    } 
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface ITicketTypeSpecificSVGHelper {
    /**
     * @notice returns a string of styles for use within an SVG
     * @param collateralAsset A string of the collateral asset address
     * @param loanAsset A string of the loan asset address
     */
    function backgroundColorsStyles(
        string memory collateralAsset,
        string memory loanAsset
        ) 
        external pure 
        returns (string memory);

    /**
     * @dev All the below methods return ticket-type-specific values
     * used in building the ticket svg image. See NFTLoanTicketSVG for usage.
     */

    function ticketIdXCoordinate() external pure returns (string memory);

    function backgroundTitleRectsXTranslate() external pure returns (string memory);

    function titlesPositionClass() external pure returns (string memory);

    function titlesXTranslate() external pure returns (string memory);

    function backgroundValueRectsXTranslate() external pure returns (string memory);

    function alignmentClass() external pure returns (string memory);

    function valuesXTranslate() external pure returns (string memory);
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/ERC721.sol)

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

        _afterTokenTransfer(address(0), to, tokenId);
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

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
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

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// ----------------------------------------------------------------------------
// BokkyPooBah's DateTime Library v1.01
//
// A gas-efficient Solidity date and time library
//
// https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
//
// Tested date range 1970/01/01 to 2345/12/31
//
// Conventions:
// Unit      | Range         | Notes
// :-------- |:-------------:|:-----
// timestamp | >= 0          | Unix timestamp, number of seconds since 1970/01/01 00:00:00 UTC
// year      | 1970 ... 2345 |
// month     | 1 ... 12      |
// day       | 1 ... 31      |
// hour      | 0 ... 23      |
// minute    | 0 ... 59      |
// second    | 0 ... 59      |
// dayOfWeek | 1 ... 7       | 1 = Monday, ..., 7 = Sunday
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018-2019. The MIT Licence.
// ----------------------------------------------------------------------------

library BokkyPooBahsDateTimeLibrary {

    uint constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint constant SECONDS_PER_HOUR = 60 * 60;
    uint constant SECONDS_PER_MINUTE = 60;
    int constant OFFSET19700101 = 2440588;

    uint constant DOW_MON = 1;
    uint constant DOW_TUE = 2;
    uint constant DOW_WED = 3;
    uint constant DOW_THU = 4;
    uint constant DOW_FRI = 5;
    uint constant DOW_SAT = 6;
    uint constant DOW_SUN = 7;

    // ------------------------------------------------------------------------
    // Calculate the number of days from 1970/01/01 to year/month/day using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and subtracting the offset 2440588 so that 1970/01/01 is day 0
    //
    // days = day
    //      - 32075
    //      + 1461 * (year + 4800 + (month - 14) / 12) / 4
    //      + 367 * (month - 2 - (month - 14) / 12 * 12) / 12
    //      - 3 * ((year + 4900 + (month - 14) / 12) / 100) / 4
    //      - offset
    // ------------------------------------------------------------------------
    function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
          - OFFSET19700101;

        _days = uint(__days);
    }

    // ------------------------------------------------------------------------
    // Calculate year/month/day from the number of days since 1970/01/01 using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and adding the offset 2440588 so that 1970/01/01 is day 0
    //
    // int L = days + 68569 + offset
    // int N = 4 * L / 146097
    // L = L - (146097 * N + 3) / 4
    // year = 4000 * (L + 1) / 1461001
    // L = L - 1461 * year / 4 + 31
    // month = 80 * L / 2447
    // dd = L - 2447 * month / 80
    // L = month / 11
    // month = month + 2 - 12 * L
    // year = 100 * (N - 49) + year + L
    // ------------------------------------------------------------------------
    function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + OFFSET19700101;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }

    function timestampFromDate(uint year, uint month, uint day) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY;
    }
    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
    }
    function timestampToDate(uint timestamp) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function timestampToDateTime(uint timestamp) internal pure returns (uint year, uint month, uint day, uint hour, uint minute, uint second) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
        secs = secs % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
        second = secs % SECONDS_PER_MINUTE;
    }

    function isValidDate(uint year, uint month, uint day) internal pure returns (bool valid) {
        if (year >= 1970 && month > 0 && month <= 12) {
            uint daysInMonth = _getDaysInMonth(year, month);
            if (day > 0 && day <= daysInMonth) {
                valid = true;
            }
        }
    }
    function isValidDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (bool valid) {
        if (isValidDate(year, month, day)) {
            if (hour < 24 && minute < 60 && second < 60) {
                valid = true;
            }
        }
    }
    function isLeapYear(uint timestamp) internal pure returns (bool leapYear) {
        (uint year,,) = _daysToDate(timestamp / SECONDS_PER_DAY);
        leapYear = _isLeapYear(year);
    }
    function _isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }
    function isWeekDay(uint timestamp) internal pure returns (bool weekDay) {
        weekDay = getDayOfWeek(timestamp) <= DOW_FRI;
    }
    function isWeekEnd(uint timestamp) internal pure returns (bool weekEnd) {
        weekEnd = getDayOfWeek(timestamp) >= DOW_SAT;
    }
    function getDaysInMonth(uint timestamp) internal pure returns (uint daysInMonth) {
        (uint year, uint month,) = _daysToDate(timestamp / SECONDS_PER_DAY);
        daysInMonth = _getDaysInMonth(year, month);
    }
    function _getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = _isLeapYear(year) ? 29 : 28;
        }
    }
    // 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint timestamp) internal pure returns (uint dayOfWeek) {
        uint _days = timestamp / SECONDS_PER_DAY;
        dayOfWeek = (_days + 3) % 7 + 1;
    }

    function getYear(uint timestamp) internal pure returns (uint year) {
        (year,,) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getMonth(uint timestamp) internal pure returns (uint month) {
        (,month,) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getDay(uint timestamp) internal pure returns (uint day) {
        (,,day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getHour(uint timestamp) internal pure returns (uint hour) {
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
    }
    function getMinute(uint timestamp) internal pure returns (uint minute) {
        uint secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }
    function getSecond(uint timestamp) internal pure returns (uint second) {
        second = timestamp % SECONDS_PER_MINUTE;
    }

    function addYears(uint timestamp, uint _years) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        year += _years;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addMonths(uint timestamp, uint _months) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        month += _months;
        year += (month - 1) / 12;
        month = (month - 1) % 12 + 1;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addDays(uint timestamp, uint _days) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _days * SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addHours(uint timestamp, uint _hours) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _hours * SECONDS_PER_HOUR;
        require(newTimestamp >= timestamp);
    }
    function addMinutes(uint timestamp, uint _minutes) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp >= timestamp);
    }
    function addSeconds(uint timestamp, uint _seconds) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _seconds;
        require(newTimestamp >= timestamp);
    }

    function subYears(uint timestamp, uint _years) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        year -= _years;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subMonths(uint timestamp, uint _months) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint yearMonth = year * 12 + (month - 1) - _months;
        year = yearMonth / 12;
        month = yearMonth % 12 + 1;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + timestamp % SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subDays(uint timestamp, uint _days) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _days * SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subHours(uint timestamp, uint _hours) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _hours * SECONDS_PER_HOUR;
        require(newTimestamp <= timestamp);
    }
    function subMinutes(uint timestamp, uint _minutes) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp <= timestamp);
    }
    function subSeconds(uint timestamp, uint _seconds) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _seconds;
        require(newTimestamp <= timestamp);
    }

    function diffYears(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _years) {
        require(fromTimestamp <= toTimestamp);
        (uint fromYear,,) = _daysToDate(fromTimestamp / SECONDS_PER_DAY);
        (uint toYear,,) = _daysToDate(toTimestamp / SECONDS_PER_DAY);
        _years = toYear - fromYear;
    }
    function diffMonths(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _months) {
        require(fromTimestamp <= toTimestamp);
        (uint fromYear, uint fromMonth,) = _daysToDate(fromTimestamp / SECONDS_PER_DAY);
        (uint toYear, uint toMonth,) = _daysToDate(toTimestamp / SECONDS_PER_DAY);
        _months = toYear * 12 + toMonth - fromYear * 12 - fromMonth;
    }
    function diffDays(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _days) {
        require(fromTimestamp <= toTimestamp);
        _days = (toTimestamp - fromTimestamp) / SECONDS_PER_DAY;
    }
    function diffHours(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _hours) {
        require(fromTimestamp <= toTimestamp);
        _hours = (toTimestamp - fromTimestamp) / SECONDS_PER_HOUR;
    }
    function diffMinutes(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _minutes) {
        require(fromTimestamp <= toTimestamp);
        _minutes = (toTimestamp - fromTimestamp) / SECONDS_PER_MINUTE;
    }
    function diffSeconds(uint fromTimestamp, uint toTimestamp) internal pure returns (uint _seconds) {
        require(fromTimestamp <= toTimestamp);
        _seconds = toTimestamp - fromTimestamp;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.12;


library UintStrings {
    /** 
     * @notice Converts `number` into a decimal string, with '%' is `isPercent` = true
     * @param number The number to convert to a string
     * @param decimals The number of decimals `number` should have when converted to a string
     * for example, number = 15 and decimals = 0 would yield "15", 
     * whereas number = 15 and decimals = 1 would yield "1.5"
     * @param isPercent Whether the string returned should include '%' at the end
     * @return string
     */
    function decimalString(uint256 number, uint8 decimals, bool isPercent) internal pure returns (string memory) {
        if (number == 0) return isPercent ? "0%" : "0";
        
        uint8 percentBufferOffset = isPercent ? 1 : 0;
        uint256 tenPowDecimals = 10 ** decimals;

        uint256 temp = number;
        uint8 digits;
        uint8 numSigfigs;
        while (temp != 0) {
            if (numSigfigs > 0) {
                // count all digits preceding least significant figure
                numSigfigs++;
            } else if (temp % 10 != 0) {
                numSigfigs++;
            }
            digits++;
            temp /= 10;
        }

        DecimalStringParams memory params;
        params.isPercent = isPercent;
        if ((digits - numSigfigs) >= decimals) {
            // no decimals, ensure we preserve all trailing zeros
            params.sigfigs = number / tenPowDecimals;
            params.sigfigIndex = digits - decimals;
            params.bufferLength = params.sigfigIndex + percentBufferOffset;
        } else {
            // chop all trailing zeros for numbers with decimals
            params.sigfigs = number / (10 ** (digits - numSigfigs));
            if (tenPowDecimals > number) {
                // number is less than one
                // in this case, there may be leading zeros after the decimal place 
                // that need to be added

                // offset leading zeros by two to account for leading '0.'
                params.zerosStartIndex = 2;
                params.zerosEndIndex = decimals - digits + 2;
                params.sigfigIndex = numSigfigs + params.zerosEndIndex;
                params.bufferLength = params.sigfigIndex + percentBufferOffset;
                params.isLessThanOne = true;
            } else {
                // In this case, there are digits before and
                // after the decimal place
                params.sigfigIndex = numSigfigs + 1;
                params.decimalIndex = digits - decimals + 1;
            }
        }
        params.bufferLength = params.sigfigIndex + percentBufferOffset;
        return generateDecimalString(params);
    }

    /// @dev the below is from
    /// https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/libraries/NFTDescriptor.sol#L189-L231
    // with modifications

    struct DecimalStringParams {
        // significant figures of decimal
        uint256 sigfigs;
        // length of decimal string
        uint8 bufferLength;
        // ending index for significant figures (funtion works backwards when copying sigfigs)
        uint8 sigfigIndex;
        // index of decimal place (0 if no decimal)
        uint8 decimalIndex;
        // start index for trailing/leading 0's for very small/large numbers
        uint8 zerosStartIndex;
        // end index for trailing/leading 0's for very small/large numbers
        uint8 zerosEndIndex;
        // true if decimal number is less than one
        bool isLessThanOne;
        // true if string should include "%"
        bool isPercent;
    }

    function generateDecimalString(DecimalStringParams memory params) private pure returns (string memory) {
        bytes memory buffer = new bytes(params.bufferLength);
        if (params.isPercent) {
            buffer[buffer.length - 1] = '%';
        }
        if (params.isLessThanOne) {
            buffer[0] = '0';
            buffer[1] = '.';
        }

        // add leading/trailing 0's
        for (uint256 zerosCursor = params.zerosStartIndex; zerosCursor < params.zerosEndIndex; zerosCursor++) {
            buffer[zerosCursor] = bytes1(uint8(48));
        }
        // add sigfigs
        while (params.sigfigs > 0) {
            if (params.decimalIndex > 0 && params.sigfigIndex == params.decimalIndex) {
                buffer[--params.sigfigIndex] = '.';
            }
            buffer[--params.sigfigIndex] = bytes1(uint8(uint256(48) + (params.sigfigs % 10)));
            params.sigfigs /= 10;
        }
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

library HexStrings {
    bytes16 internal constant ALPHABET = '0123456789abcdef';

    // @notice returns value as a hex string of desiredPartialStringLength length,
    // adding '0x' to the start and '...' to the end. 
    // Designed to be used for shortening addresses for display purposes.
    // @param value The value to return as a hex string
    // @param desiredPartialStringLength How many hex characters of `value` to return in the string
    // @param valueLengthAsHexString The length of `value` as a hex string
    function partialHexString(
        uint160 value,
        uint8 desiredPartialStringLength,
        uint8 valueLengthAsHexString
    ) 
        internal 
        pure 
        returns (string memory) 
    {
        bytes memory buffer = new bytes(desiredPartialStringLength + 5);
        buffer[0] = '0';
        buffer[1] = 'x';
        uint8 offset = desiredPartialStringLength + 1;
        // remove values not in partial length, four bytes for every hex character
        value >>= 4 * (valueLengthAsHexString - desiredPartialStringLength);
        for (uint8 i = offset; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        require(value == 0, 'HexStrings: hex length insufficient');
        // uint8 offset 
        buffer[offset + 1] = '.';
        buffer[offset + 2] = '.';
        buffer[offset + 3] = '.';
        return string(buffer);
    }

    /// @notice Converts a `uint160` to its ASCII `string` hexadecimal representation with fixed length.
    /// @dev Credit to Open Zeppelin under MIT license 
    /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/243adff49ce1700e0ecb99fe522fb16cff1d1ddc/contracts/utils/Strings.sol#L55
    function toHexString(uint160 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        require(value == 0, 'HexStrings: hex length insufficient');
        return string(buffer);
    }
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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