// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./LoanState.sol";

/**
 * @title LoanDetails
 * @dev Structure containing all details about a loan
 */
struct LoanDetails {
    uint256 loanId;                // Unique identifier for the loan
    address tokenAddress;          // Address of the token used for the loan
    uint256 totalAmount;           // Total amount of the loan
    uint256 currentAmount;         // Current amount invested in the loan
    uint256 interestRate;          // Interest rate in basis points (e.g., 500 = 5%)
    uint256 loanDuration;          // Duration of the loan in seconds
    uint256 startTime;             // Timestamp when the loan was funded
    uint256 endTime;               // Timestamp when the loan expires
    LoanState state;               // Current state of the loan
    uint256 compoundingFrequency;  // Times compounded per year
    bool fundsWithdrawn;           // Whether funds have been withdrawn
    address withdrawalRecipient;   // Address to receive withdrawn funds
    uint256 withdrawnAmount;       // Amount of funds that have been withdrawn
    uint256 totalInvested;         // Total amount that has been invested (including any withdrawn)
    uint256 lastUpdateTime;        // Timestamp of the last update to the loan
} 