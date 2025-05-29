// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../Lending.sol";
import "../structs/LoanState.sol";
import "../constants/Events.sol";

/**
 * @title LoanStatusExample
 * @dev Example of how to use the loan status tracking functionality
 */
contract LoanStatusExample {
    Lending public lendingContract;
    

    
    constructor(address lendingContractAddress) {
        lendingContract = Lending(lendingContractAddress);
    }
    
    /**
     * @dev Example of how to track a loan's funding status
     * @param loanId The ID of the loan to check
     */
    function checkLoanFundingStatus(uint256 loanId) external {
        // Get the loan funding status
        (
            uint256 totalAmount,
            uint256 currentAmount,
            uint256 remainingAmount,
            uint256 percentageFunded,
            bool fundsWithdrawn,
            address withdrawnToAddress
        ) = lendingContract.getLoanFundingStatus(loanId);
        
        // Log the funding summary
        emit Events.FundingSummaryLogged(
            loanId,
            totalAmount,
            currentAmount,
            remainingAmount,
            percentageFunded
        );
        
        // Check if the loan can accept more investment
        bool canAcceptMore = lendingContract.canAcceptInvestment(loanId);
        
        // If investment is still possible, get the remaining capacity
        if (canAcceptMore) {
            uint256 remainingCapacity = lendingContract.getRemainingInvestmentCapacity(loanId);
            // Here you could update UI to show remaining investment capacity
        }
        
        // Check if funds have been withdrawn and where they went
        if (fundsWithdrawn) {
            // Here you could update UI to show withdrawal recipient
            // withdrawnToAddress contains the recipient
        }
    }
    
    /**
     * @dev Example of how to track a loan's settlement status
     * @param loanId The ID of the loan to check
     */
    function checkLoanSettlementStatus(uint256 loanId) external {
        // Get the loan settlement status
        (
            LoanState state,
            bool isSettled,
            bool canBeWithdrawn,
            bool hasBeenWithdrawn
        ) = lendingContract.getLoanSettlementStatus(loanId);
        
        // Log the settlement status
        emit Events.SettlementStatusLogged(
            loanId,
            state,
            isSettled,
            canBeWithdrawn,
            hasBeenWithdrawn
        );
        
        // Take actions based on the loan's state
        if (state == LoanState.Active) {
            // Loan is still accepting investments
            // Here you could update UI to show investment opportunities
        } else if (state == LoanState.Funded) {
            if (canBeWithdrawn && !hasBeenWithdrawn) {
                // Loan can be withdrawn but hasn't been yet
                // Here you could notify operators about withdrawal opportunity
            }
        } else if (isSettled) {
            // Loan is either repaid or defaulted
            // Here you could update UI to show settlement status
        }
    }
    
    /**
     * @dev Example of how to track a loan's funding history
     * @param loanId The ID of the loan to check
     */
    function checkLoanFundingHistory(uint256 loanId) external {
        // Get the loan funding history
        (
            uint256 totalInvested,
            uint256 currentAmount,
            uint256 withdrawnAmount,
            uint256 lastUpdateTime
        ) = lendingContract.getLoanFundingHistory(loanId);
        
        // Log the funding history
        emit Events.FundingHistoryLogged(
            loanId,
            totalInvested,
            currentAmount,
            withdrawnAmount,
            lastUpdateTime
        );
        
        // Calculate how much of the original investment is still in the contract
        uint256 withdrawalPercentage = 0;
        if (totalInvested > 0) {
            withdrawalPercentage = (withdrawnAmount * 100) / totalInvested;
        }
        
        // Here you could update UI to show withdrawal percentage and history
    }
    
    /**
     * @dev Example of how to track investment opportunities for an investor
     * @param loanIds Array of loan IDs to check
     * @return availableLoans Array of loan IDs that can still accept investment
     * @return capacities Array of remaining investment capacities for each loan
     */
    function findInvestmentOpportunities(uint256[] calldata loanIds) 
        external 
        view 
        returns (
            uint256[] memory availableLoans, 
            uint256[] memory capacities
        ) 
    {
        // Count available loans first
        uint256 availableCount = 0;
        for (uint256 i = 0; i < loanIds.length; i++) {
            if (lendingContract.canAcceptInvestment(loanIds[i])) {
                availableCount++;
            }
        }
        
        // Create arrays of the right size
        availableLoans = new uint256[](availableCount);
        capacities = new uint256[](availableCount);
        
        // Fill arrays with data
        uint256 index = 0;
        for (uint256 i = 0; i < loanIds.length; i++) {
            if (lendingContract.canAcceptInvestment(loanIds[i])) {
                availableLoans[index] = loanIds[i];
                capacities[index] = lendingContract.getRemainingInvestmentCapacity(loanIds[i]);
                index++;
            }
        }
        
        return (availableLoans, capacities);
    }
} 