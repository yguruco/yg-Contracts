// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title LoanState
 * @dev Enum representing the possible states of a loan
 */
enum LoanState {
    Created,    // Loan has been created but not funded yet
    Funded,     // Loan has reached funding threshold and is active
    Repaid,     // Loan has been repaid with interest
    Defaulted,  // Loan has expired without being repaid
    Cancelled   // Loan was cancelled before funding completed
} 