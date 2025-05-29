// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../Lending.sol";

/**
 * @title WithdrawalExample
 * @dev Example of how to use the withdrawal functionality
 */
contract WithdrawalExample {
    Lending public lendingContract;
    
    constructor(address lendingContractAddress) {
        lendingContract = Lending(lendingContractAddress);
    }
    
    /**
     * @dev Example of how an operator might manage the withdrawal process
     * @param loanId The ID of the loan to withdraw from
     * @param recipient The address to receive the withdrawn funds
     */
    function operatorWithdrawalProcess(uint256 loanId, address recipient) external {
        // Step 1: Check if the loan can have funds withdrawn
        bool canWithdraw = lendingContract.canWithdrawFunds(loanId);
        require(canWithdraw, "Loan is not eligible for withdrawal");
        
        // Step 2: Get the amount that can be withdrawn
        uint256 withdrawableAmount = lendingContract.getWithdrawableAmount(loanId);
        require(withdrawableAmount > 0, "No funds available for withdrawal");
        
        // Step 3: Authorize the recipient to receive the funds
        lendingContract.authorizeWithdrawalRecipient(loanId, recipient);
        
        // Step 4: Withdraw the funds to the recipient
        uint256 withdrawnAmount = lendingContract.withdrawFunds(loanId);
        
        // Step 5: Verify that the funds were withdrawn
        bool withdrawn = lendingContract.hasFundsWithdrawn(loanId);
        require(withdrawn, "Funds not withdrawn");
        
        // Step 6: Verify the recipient
        address withdrawalRecipient = lendingContract.getWithdrawalRecipient(loanId);
        require(withdrawalRecipient == recipient, "Recipient mismatch");
    }
} 