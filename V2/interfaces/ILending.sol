// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../structs/LoanDetails.sol";
import "../structs/LoanState.sol";
import "../structs/PositionInfo.sol";

/**
 * @title ILending
 * @dev Interface for the Lending contract
 */
interface ILending {
    // Core functions
    function createLoan(
        address tokenAddress,
        uint256 totalAmount,
        uint256 interestRate,
        uint256 loanDuration,
        uint256 compoundingFrequency
    ) external returns (uint256);
    
    function invest(uint256 loanId, uint256 amount) external returns (uint256);
    
    function authorizeWithdrawalRecipient(uint256 loanId, address recipient) external;
    
    function withdrawFunds(uint256 loanId) external returns (uint256);
    
    function repayLoan(uint256 loanId) external;
    
    function markLoanAsDefaulted(uint256 loanId) external;
    
    // View functions
    function getLoanDetails(uint256 loanId) external view returns (LoanDetails memory);
    
    function getExpectedReturn(uint256 positionId) external view returns (uint256);
    
    function isTokenSupported(address tokenAddress) external view returns (bool);
    
    function getLoanFundingStatus(uint256 loanId) external view returns (
        uint256 totalAmount,
        uint256 currentAmount,
        uint256 remainingAmount,
        uint256 percentageFunded,
        bool fundsWithdrawn,
        address withdrawnToAddress
    );
    
    function getLoanSettlementStatus(uint256 loanId) external view returns (
        LoanState state,
        bool isSettled,
        bool canBeWithdrawn,
        bool hasBeenWithdrawn
    );
    
    function canAcceptInvestment(uint256 loanId) external view returns (bool);
    
    function getRemainingInvestmentCapacity(uint256 loanId) external view returns (uint256);
    
    function getLoanFundingHistory(uint256 loanId) external view returns (
        uint256 totalInvested,
        uint256 currentAmount,
        uint256 withdrawnAmount,
        uint256 lastUpdateTime
    );
    
    function canWithdrawFunds(uint256 loanId) external view returns (bool);
    
    function getWithdrawalRecipient(uint256 loanId) external view returns (address);
    
    function hasFundsWithdrawn(uint256 loanId) external view returns (bool);
    
    function getWithdrawableAmount(uint256 loanId) external view returns (uint256);
    
    function checkLoanPositions(uint256 loanId) external view returns (bool hasPositions, uint256 positionCount);
} 