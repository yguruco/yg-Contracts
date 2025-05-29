// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../structs/PositionInfo.sol";
import "../structs/YieldStruct.sol";

/**
 * @title IPosition
 * @dev Interface for the Position NFT contract
 */
interface IPosition {
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
    ) external returns (uint256);

    /**
     * @dev Gets position information
     * @param tokenId ID of the position
     * @return The position information
     */
    function getPosition(uint256 tokenId) external view returns (PositionInfo memory);

    /**
     * @dev Marks a position as withdrawn
     * @param tokenId ID of the position
     */
    function markWithdrawn(uint256 tokenId) external;

    /**
     * @dev Gets the current token ID counter value
     * @return The current token ID
     */
    function getTokenId() external view returns (uint256);

    /**
     * @dev Checks if a token exists
     * @param tokenId ID of the token
     * @return Whether the token exists
     */
    function exists(uint256 tokenId) external view returns (bool);
} 