// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/* Custom errors for the loan contract */

// General errors
error InvalidAmount();
error InvalidAddress();
error ZeroAddress(string parameter);

// Access control errors
error Unauthorized();
error OnlyAdmin();
error OnlyOperator();
error OnlyInvestor();

// Loan state errors
error LoanNotActive();
error LoanAlreadyFunded();
error LoanAlreadyRepaid();
error LoanExpired();
error LoanNotExpired();

// Position errors
error PositionNotFound();
error PositionAlreadyWithdrawn();
error AmountExceedsAvailable();
error PositionCannotBeWithdrawn();

// Token related errors
error TokenTransferFailed();
error InsufficientAllowance();
error InsufficientBalance();

// Withdrawal errors
error WithdrawalTooLarge();
error InsufficientLiquidity();
error WithdrawalFailed();
/// @dev Thrown when attempting to withdraw from a loan that hasn't reached the threshold
error WithdrawalThresholdNotReached();

/// @dev Thrown when attempting to withdraw from a loan that already had funds withdrawn
error WithdrawalAlreadyProcessed(); 

/// @dev Thrown when an invalid token address is provided
error InvalidToken(address token);

/// @dev Thrown when a zero amount is provided
error ZeroAmount();

/// @dev Thrown when trying to repay a loan that is not active
error InvalidLoanStatus();

/// @dev Thrown when trying to invest in a loan with invalid parameters
error InvalidLoanParameters();

/// @dev Thrown when an invalid interest rate is provided
error InvalidInterestRate();

/// @dev Thrown when an invalid compounding frequency is provided
error InvalidCompoundingFrequency();

/// @dev Thrown when an investment would exceed the total loan amount
error InvestmentExceedsTotal();

/// @dev Thrown when trying to interact with a loan that is not funded
error LoanNotFunded();

/// @dev Thrown when trying to withdraw from a loan that hasn't reached the funding threshold
error LoanNotReachedFundingThreshold();

/// @dev Thrown when trying to withdraw with an invalid amount
error InvalidWithdrawalAmount();

/// @dev Thrown when trying to withdraw to an unauthorized recipient
error UnauthorizedWithdrawalRecipient();

error UnsupportedToken(address token);
error ContractNotActive();
error InvalidRate();
error InvalidLoanDuration();
error WithdrawalToZeroAddress();