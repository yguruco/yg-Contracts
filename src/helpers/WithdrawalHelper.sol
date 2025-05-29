// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../structs/LoanDetails.sol";
import "../constants/LoanConstants.sol";

/**
 * @title WithdrawalHelper
 * @dev Library to assist with withdrawal operations
 */
library WithdrawalHelper {
    /**
     * @dev Check if a loan has reached the minimum funding threshold for withdrawal
     * @param loan The loan details
     * @return True if the loan can be withdrawn, false otherwise
     */
    function canWithdraw(LoanDetails storage loan) public view returns (bool) {
        // Check if loan has reached funding threshold
        if (loan.state != LoanState.Funded) {
            return false;
        }
        
        // Check if we have at least 30% of the total loan amount
        if (loan.currentAmount < (loan.totalAmount * LoanConstants.FUNDING_THRESHOLD_PERCENTAGE) / 100) {
            return false;
        }
        
        return true;
    }

    /**
     * @dev Calculate the withdrawable amount from a loan
     * @param loan The loan details
     * @return The amount that can be withdrawn
     */
    function withdrawableAmount(LoanDetails storage loan) public view returns (uint256) {
        if (!canWithdraw(loan)) {
            return 0;
        }
        
        // Return the current amount that has been funded
        return loan.currentAmount;
    }
} 