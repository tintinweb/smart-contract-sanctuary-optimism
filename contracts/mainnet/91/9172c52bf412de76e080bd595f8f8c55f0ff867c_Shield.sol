/**
 *Submitted for verification at optimistic.etherscan.io on 2022-07-14
*/

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

library Base64 {
  bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  /// @notice Encodes some bytes to the base64 representation
  function encode(bytes memory data) internal pure returns (string memory) {
    uint256 len = data.length;
    if (len == 0) return "";

    // multiply by 4/3 rounded up
    uint256 encodedLen = 4 * ((len + 2) / 3);

    // Add some extra buffer at the end
    bytes memory result = new bytes(encodedLen + 32);

    bytes memory table = TABLE;

    assembly {
      let tablePtr := add(table, 1)
      let resultPtr := add(result, 32)

      for {
          let i := 0
      } lt(i, len) {

      } {
        i := add(i, 3)
        let input := and(mload(add(data, i)), 0xffffff)

        let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
        out := shl(8, out)
        out := add(
            out,
            and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
        )
        out := shl(8, out)
        out := add(
            out,
            and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
        )
        out := shl(8, out)
        out := add(
            out,
            and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
        )
        out := shl(224, out)

        mstore(resultPtr, out)

        resultPtr := add(resultPtr, 4)
      }

      switch mod(len, 3)
      case 1 {
        mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
      }
      case 2 {
        mstore(sub(resultPtr, 1), shl(248, 0x3d))
      }

      mstore(result, encodedLen)
    }

    return string(result);
  }
}

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

/// @title IBadgeRenderer
/// @author Huff Language Core Team
/// @author Modified from Jonathan Becker <[email protected]> renoun <https://github.com/Jon-Becker/renoun>
interface IBadgeRenderer {
  function renderPullRequest(
    uint256 _pullRequestID,
    string calldata _pullRequestTitle,
    uint256 _additions,
    uint256 _deletions,
    string calldata _pullRequestCreatorPictureURL,
    string calldata _pullRequestCreatorUsername,
    string calldata _commitHash,
    string calldata _repositoryOwner,
    string calldata _repositoryName,
    uint256 _repositoryStars,
    uint256 _repositoryContributors
  ) external pure returns (string memory);
}

/// @title Shield
/// @author Huff Language Core Team
/// @notice A contribution badge for Huff Language GitHub Contributors
/// @author Modified from Jonathan Becker <[email protected]> renoun <https://github.com/Jon-Becker/renoun>
contract Shield is ERC721 {

  /// ----------------------------------------------------
  /// Custom Errors
  /// ----------------------------------------------------

  /// @notice The caller is not authorized on this func
  error Unauthorized(address caller);

  /// @notice The PR ID is zero
  error ZeroPullRequestID();

  /// @notice Attempt to transfer the token
  error NonTransferrable();

  /// @notice A non-existant token
  error TokenDoesNotExist();

  /// @notice Zero Address
  error ZeroAddress();

  /// ----------------------------------------------------
  /// Public Config
  /// ----------------------------------------------------

  /// @notice The repository owner
  string public constant REPO_OWNER = "huff-language";

  /// @notice The repository name
  string public constant REPO_NAME = "huff-rs";

  /// @notice The admin address
  address public immutable WARDEN;

  /// @notice The render contract address
  address public rendererContract;

  /// @notice The total suppy
  uint256 public totalSupply;

  /// @notice The number of repository stars
  uint256 public repositoryStars;

  /// @notice The number of repository contributors
  uint256 public repositoryContributors;

  /// @notice A contribution object
  struct Contribution {
    uint256 _pullRequestID;
    string _pullRequestTitle;
    uint256 _additions;
    uint256 _deletions;
    string _pullRequestCreatorPictureURL;
    string _pullRequestCreatorUsername;
    string _commitHash;
  }

  /// @notice Maps token id to a contribution
  mapping(uint256 => Contribution) public contribution;

  /// ----------------------------------------------------
  /// CONSTRUCTOR
  /// ----------------------------------------------------

  constructor(address renderer) ERC721("Huff Shield", "HUFF") {
    WARDEN = msg.sender;
    rendererContract = renderer;
  }

  /// ----------------------------------------------------
  /// MINTING LOGIC
  /// ----------------------------------------------------

  /// @notice Mints a new GitHub contribition badge
  /// @param _to The address to mint the badge to
  /// @param _pullRequestID The ID of the pull request
  /// @param _pullRequestTitle The title of the pull request
  /// @param _additions The number of additions in the pull request
  /// @param _deletions The number of deletions in the pull request
  /// @param _pullRequestCreatorPictureURL The URL of the pull request creator's profile picture
  /// @param _pullRequestCreatorUsername The username of the pull request creator
  /// @param _commitHash The hash of the commit
  /// @param _repositoryStars The number of stars the repository has
  /// @param _repositoryContributors The number of contributors to the repository
  function mint(
    address _to,
    uint256 _pullRequestID,
    string memory _pullRequestTitle,
    uint256 _additions,
    uint256 _deletions,
    string memory _pullRequestCreatorPictureURL,
    string memory _pullRequestCreatorUsername,
    string memory _commitHash,
    uint256 _repositoryStars,
    uint256 _repositoryContributors
  ) public virtual {
    // Validation Logic
    if (msg.sender != WARDEN) revert Unauthorized(msg.sender);
    if (_pullRequestID == 0) revert ZeroPullRequestID();

    // Update the repository stars and contributors
    repositoryStars = _repositoryStars;
    repositoryContributors = _repositoryContributors;

    // Create a contribution
    Contribution memory _contribution = Contribution(
      _pullRequestID,
      _pullRequestTitle,
      _additions,
      _deletions,
      _pullRequestCreatorPictureURL,
      _pullRequestCreatorUsername,
      _commitHash
    );

    // Increment the total supply
    totalSupply++;

    // Mint to the address
    _mint(_to, totalSupply);

    // Update the contribution object
    contribution[totalSupply] = _contribution;
  }

  /// ----------------------------------------------------
  /// NON TRANSFERRABILITY OVERRIDES
  /// ----------------------------------------------------

  /// @notice Overrides the transferFrom function to make this token non-transferrable
  function transferFrom(address, address, uint256) public override {
    revert NonTransferrable();
  }

  /// @notice Overrides the approvals since the token is non-transferrable
  function approve(address, uint256) public override {
    revert NonTransferrable();
  }

  /// @notice Overrides setting approvals since the token is non-transferrable
  function setApprovalForAll(address operator, bool approved) public override {
    revert NonTransferrable();
  }

  /// ----------------------------------------------------
  /// ADMIN FUNCTIONALITY
  /// ----------------------------------------------------

  /// @notice Switches the rendering contract
  /// @param _newRenderer The new rendering contract
  function changeRenderer(address _newRenderer) public {
    // Validation Logic
    if (msg.sender != WARDEN) revert Unauthorized(msg.sender);
    if (_newRenderer == address(0)) revert ZeroAddress();

    // Update the contract
    rendererContract = _newRenderer;
  }

  /// ----------------------------------------------------
  /// VISIBILITY
  /// ----------------------------------------------------

  /// @notice Switches the rendering contract
  /// @param _tokenId The token ID to render
  /// @return The token URI of the token ID
  function tokenURI(uint256 _tokenId) public override view virtual returns (string memory) {
    if (ownerOf(_tokenId) == address(0)) revert TokenDoesNotExist();

    Contribution memory _contribution = contribution[_tokenId];
    string memory json = Base64.encode(bytes(string(abi.encodePacked(
      '{',
      '"name": "Pull Request #',_integerToString(_contribution._pullRequestID),'",',
      '"description": "A shiny, non-transferrable badge to show off my GitHub contribution.",',
      '"tokenId": ',_integerToString(_tokenId),',',
      '"image": "data:image/svg+xml;base64,',Base64.encode(bytes(_renderSVG(_contribution))),'"',
      '}'
      ))));

    return string(abi.encodePacked('data:application/json;base64,', json));
  }

  /// ----------------------------------------------------
  /// HELPER FUNCTIONS
  /// ----------------------------------------------------

  /// @notice Converts an integer to a string
  /// @param  _i The integer to convert
  /// @return The string representation of the integer
  function _integerToString(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) return "0";

    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k-1;
      uint8 temp = (48 + uint8(_i - _i / 10 * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }

  function _renderSVG(Contribution memory _contribution) internal view returns (string memory){
    IBadgeRenderer renderer = IBadgeRenderer(rendererContract);
    return renderer.renderPullRequest(
      _contribution._pullRequestID,
      _contribution._pullRequestTitle,
      _contribution._additions,
      _contribution._deletions,
      _contribution._pullRequestCreatorPictureURL,
      _contribution._pullRequestCreatorUsername,
      _contribution._commitHash,
      REPO_OWNER,
      REPO_NAME,
      repositoryStars,
      repositoryContributors
    );
  }
}