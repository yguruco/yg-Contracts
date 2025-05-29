// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title YieldStruct
 * @dev Struct containing parameters needed for interest calculations
 */
struct YieldStruct {
    uint256 principal;        // The principal amount
    uint256 rate;             // Annual interest rate (in basis points, e.g., 500 = 5%)
    uint256 timesComounded;   // Number of times interest compounds per year (e.g., 12 for monthly)
    uint256 time;             // Time period in years (can be fractional, e.g., 0.5 for 6 months)
} 