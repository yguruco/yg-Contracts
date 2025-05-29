// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../structs/LoanDetails.sol";
import "../constants/LoanConstants.sol";

/**
 * @title LoanStatusHelper
 * @dev Library to track and calculate loan funding status
 */
library LoanStatusHelper {
    /**
     * @dev Calculate the amount still needed to fully fund a loan
     * @param loan The loan details
     * @return The amount needed to reach 100% funding
     */
    function amountNeededForFullFunding(LoanDetails storage loan) public view returns (uint256) {
        if (loan.totalAmount <= loan.currentAmount) {
            return 0;
        }
        return loan.totalAmount - loan.currentAmount;
    }
    
    /**
     * @dev Calculate the current funding percentage of a loan
     * @param loan The loan details
     * @return The funding percentage (0-100)
     */
    function fundingPercentage(LoanDetails storage loan) public view returns (uint256) {
        if (loan.totalAmount == 0) {
            return 0;
        }
        return (loan.currentAmount * 100) / loan.totalAmount;
    }
    
    /**
     * @dev Check if a loan has reached the minimum funding threshold
     * @param loan The loan details
     * @return True if the loan has reached the threshold
     */
    function hasReachedFundingThreshold(LoanDetails storage loan) public view returns (bool) {
        return fundingPercentage(loan) >= LoanConstants.FUNDING_THRESHOLD_PERCENTAGE;
    }
    
    /**
     * @dev Check if a loan is fully funded
     * @param loan The loan details
     * @return True if the loan is fully funded
     */
    function isFullyFunded(LoanDetails storage loan) public view returns (bool) {
        return loan.currentAmount >= loan.totalAmount;
    }
    
    /**
     * @dev Calculate the remaining amount that can be invested in a loan
     * @param loan The loan details
     * @return The amount that can still be invested
     */
    function remainingInvestmentCapacity(LoanDetails storage loan) public view returns (uint256) {
        return amountNeededForFullFunding(loan);
    }
    
    /**
     * @dev Get the summary of a loan's funding status
     * @param loan The loan details
     * @return totalAmount The total amount of the loan
     * @return currentAmount The current amount invested in the loan
     * @return remainingAmount The amount needed for full funding
     * @return percentageFunded The percentage of the loan that is funded
     * @return fundsWithdrawn Whether funds have been withdrawn
     * @return withdrawnToAddress The address funds were withdrawn to (zero if not withdrawn)
     */
    function getLoanFundingSummary(LoanDetails storage loan) public view returns (
        uint256 totalAmount,
        uint256 currentAmount,
        uint256 remainingAmount,
        uint256 percentageFunded,
        bool fundsWithdrawn,
        address withdrawnToAddress
    ) {
        totalAmount = loan.totalAmount;
        currentAmount = loan.currentAmount;
        remainingAmount = amountNeededForFullFunding(loan);
        percentageFunded = fundingPercentage(loan);
        fundsWithdrawn = loan.fundsWithdrawn;
        withdrawnToAddress = loan.withdrawalRecipient;
    }
    
    /**
     * @dev Get the settlement status of a loan
     * @param loan The loan details
     * @return state The current state of the loan
     * @return isSettled True if the loan is repaid or defaulted
     * @return canBeWithdrawn True if the loan can have funds withdrawn
     * @return hasBeenWithdrawn True if funds have already been withdrawn
     */
    function getLoanSettlementStatus(LoanDetails storage loan) public view returns (
        LoanState state,
        bool isSettled,
        bool canBeWithdrawn,
        bool hasBeenWithdrawn
    ) {
        state = loan.state;
        isSettled = (loan.state == LoanState.Repaid || loan.state == LoanState.Defaulted);
        canBeWithdrawn = (loan.state == LoanState.Funded && !loan.fundsWithdrawn);
        hasBeenWithdrawn = loan.fundsWithdrawn;
    }
    
    /**
     * @dev Calculate amount invested after a withdrawal
     * @param loan The loan details
     * @return The effective amount still considered invested
     */
    function effectiveInvestedAmount(LoanDetails storage loan) public view returns (uint256) {
        // If funds have been withdrawn, the effective invested amount is 0
        if (loan.fundsWithdrawn) {
            return 0;
        }
        return loan.currentAmount;
    }
    
    /**
     * @dev Check if a loan is available for additional investment
     * @param loan The loan details
     * @return True if the loan can accept more investment
     */
    function canAcceptInvestment(LoanDetails storage loan) public view returns (bool) {
        // Loan must be active and not fully funded
        if (loan.state != LoanState.Active) {
            return false;
        }
        
        // If already fully funded, no more investment allowed
        if (isFullyFunded(loan)) {
            return false;
        }
        
        return true;
    }
} 