// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./YieldStruct.sol";

/**
 * @title PositionInfo
 * @dev Struct representing an investor's position in a loan
 */
struct PositionInfo {
    uint256 positionId;     // Position ID (same as NFT token ID)
    uint256 loanId;         // ID of the loan this position belongs to
    address investor;       // Address of the investor
    uint256 amount;         // Amount invested
    uint256 timestamp;      // When the position was created
    bool withdrawn;         // Whether the position has been withdrawn
    YieldStruct yieldParams; // Parameters for yield calculation
    address tokenAddress;    // Address of the token used   
} 