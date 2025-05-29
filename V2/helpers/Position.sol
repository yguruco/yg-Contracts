// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import "../structs/PositionInfo.sol";
import "../structs/YieldStruct.sol";
import "../constants/Roles.sol";
import "../errors/CustomError.sol";
import "../interfaces/IPosition.sol";

/**
 * @title Position
 * @dev NFT representing an investor's position in a loan
 */
contract Position is ERC721Enumerable, AccessControl, IPosition {
    // Counter for position IDs
    uint256 private _tokenIdCounter = 0;

    // Mapping from token ID to position info
    mapping(uint256 => PositionInfo) private _positions;

    /**
     * @dev Constructor
     */
    constructor() ERC721("YieldGuru Position", "YGP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Roles.ADMIN_ROLE, msg.sender);
        
        // Start token IDs at 1
        _tokenIdCounter = 1;
    }

    /**
     * @dev Creates a new position
     * @param investor Address of the investor
     * @param tokenAddress Address of the token used
     * @param amount Amount invested
     * @param loanId ID of the loan
     * @param yieldParams Parameters for yield calculation
     * @return tokenId The ID of the newly created position
     */
    function createPosition(
        address investor,
        address tokenAddress,
        uint256 amount,
        uint256 loanId,
        YieldStruct memory yieldParams
    ) external override onlyRole(Roles.ADMIN_ROLE) returns (uint256) {
        if (investor == address(0)) revert ZeroAddress("investor");
        if (amount == 0) revert ZeroAmount();
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        
        _mint(investor, tokenId);
        
        _positions[tokenId] = PositionInfo({
            positionId: tokenId,
            loanId: loanId,
            investor: investor,
            amount: amount,
            timestamp: block.timestamp,
            withdrawn: false,
            yieldParams: yieldParams,
            tokenAddress: tokenAddress
        });
        
        return tokenId;
    }

    /**
     * @dev Gets position information
     * @param tokenId ID of the position
     * @return The position information
     */
    function getPosition(uint256 tokenId) external view override returns (PositionInfo memory) {
        require(_existsToken(tokenId), "Position: token does not exist");
        return _positions[tokenId];
    }

    /**
     * @dev Marks a position as withdrawn
     * @param tokenId ID of the position
     */
    function markWithdrawn(uint256 tokenId) external override onlyRole(Roles.ADMIN_ROLE) {
        require(_existsToken(tokenId), "Position: token does not exist");
        if (_positions[tokenId].withdrawn) revert PositionAlreadyWithdrawn();
        
        _positions[tokenId].withdrawn = true;
    }

    /**
     * @dev Gets the current token ID counter value
     * @return The current token ID
     */
    function getTokenId() external view override returns (uint256) {
        return _tokenIdCounter - 1;
    }

    /**
     * @dev Checks if a token exists
     * @param tokenId ID of the token
     * @return Whether the token exists
     */
    function exists(uint256 tokenId) external view override returns (bool) {
        return _existsToken(tokenId);
    }

    /**
     * @dev Internal function to check if a token exists
     * @param tokenId ID of the token
     * @return Whether the token exists
     */
    function _existsToken(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId < _tokenIdCounter;
    }

    // Required override for AccessControl + ERC721Enumerable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
