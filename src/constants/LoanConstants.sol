// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title LoanConstants
 * @dev Contains constants related to loans and funding
 */
library LoanConstants {
    // Funding threshold percentage (30%)
    uint256 public constant FUNDING_THRESHOLD_PERCENTAGE = 30;
    
    // Scaling factor for calculations
    uint256 public constant SCALE = 1e18;
} 