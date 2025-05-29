// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title Events
 * @dev Events emitted by the loan contract
 */
library Events {
    // Loan lifecycle events
    event LoanCreated(
        uint256 indexed loanId,
        address indexed tokenAddress,
        uint256 amount,
        uint256 interestRate,
        uint256 compoundingFrequency,
        uint256 loanDuration,
        uint256 startTime
    );

    event LoanFunded(
        uint256 indexed loanId,
        uint256 amount,
        uint256 timestamp
    );

    event LoanRepaid(
        uint256 indexed loanId,
        uint256 totalRepayment,
        uint256 timestamp
    );

    event LoanDefaulted(
        uint256 indexed loanId,
        uint256 timestamp
    );

    event LoanCancelled(
        uint256 indexed loanId,
        uint256 timestamp
    );

    // Investment events
    event InvestmentMade(
        uint256 indexed loanId,
        address indexed investor,
        uint256 amount,
        uint256 positionId
    );

    event PositionCreated(
        uint256 indexed positionId,
        uint256 indexed loanId,
        address indexed investor,
        uint256 amount,
        uint256 timestamp
    );

    event InterestDistributed(
        uint256 indexed loanId,
        address indexed investor,
        uint256 amount
    );

    // Admin events
    event AdminAdded(
        address indexed admin,
        uint256 timestamp
    );

    event AdminRemoved(
        address indexed admin,
        uint256 timestamp
    );

    event OperatorAdded(
        address indexed operator,
        uint256 timestamp
    );

    event OperatorRemoved(
        address indexed operator,
        uint256 timestamp
    );

    // Withdrawal events
    event WithdrawalRequested(
        uint256 indexed loanId,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalProcessed(
        uint256 indexed loanId,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    // Status tracking events
    event LoanSettlementStatusChanged(
        uint256 indexed loanId,
        uint8 status,
        bool settled
    );
    event WithdrawalAuthorized(
        uint256 indexed loanId,
        address indexed sender,
        address recipient,
        uint256 timestamp
    );
} 