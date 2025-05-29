// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../structs/LoanDetails.sol";
import "../helpers/WithdrawalHelper.sol";
import "../constants/Roles.sol";
import "../constants/Events.sol";
import "../errors/CustomError.sol";

/**
 * @title WithdrawalManager
 * @dev Module for managing withdrawals from loans
 */
contract WithdrawalManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using WithdrawalHelper for LoanDetails;
    
    // Reference to the loan details mapping (will be populated by the main contract)
    mapping(uint256 => LoanDetails) internal loans;
    
    /**
     * @dev Constructor
     * @param admin The admin address
     * @param operator The operator address
     */
    constructor(address admin, address operator) {
        require(admin != address(0), "WithdrawalManager: admin cannot be zero address");
        require(operator != address(0), "WithdrawalManager: operator cannot be zero address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Roles.ADMIN_ROLE, admin);
        _grantRole(Roles.OPERATOR_ROLE, operator);
    }
    
    /**
     * @dev Authorize a withdrawal recipient for a loan
     * @param loanId The ID of the loan
     * @param recipient The address to receive the withdrawn funds
     */
    function authorizeWithdrawalRecipient(uint256 loanId, address recipient)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        if (recipient == address(0)) revert ZeroAddress("recipient");
        
        LoanDetails storage loan = loans[loanId];
        if (!loan.canWithdraw()) revert WithdrawalThresholdNotReached();
        
        loan.withdrawalRecipient = recipient;
        loan.lastUpdateTime = block.timestamp;
        
        emit Events.WithdrawalAuthorized(loanId, msg.sender, recipient , block.timestamp);
    }
    
    /**
     * @dev Withdraw funds from a loan to the authorized recipient
     * @param loanId The ID of the loan to withdraw from
     * @return The amount withdrawn
     */
    function withdrawFunds(uint256 loanId)
        external
        nonReentrant
        onlyRole(Roles.OPERATOR_ROLE)
        returns (uint256)
    {
        LoanDetails storage loan = loans[loanId];
        
        // Check if loan is eligible for withdrawal
        if (!loan.canWithdraw()) revert WithdrawalThresholdNotReached();
        
        // Check if funds have already been withdrawn
        if (loan.fundsWithdrawn) revert WithdrawalAlreadyProcessed();
        
        // Check if withdrawal recipient is set
        if (loan.withdrawalRecipient == address(0)) revert ZeroAddress("withdrawalRecipient");
        
        // Calculate the amount to withdraw
        uint256 withdrawAmount = loan.withdrawableAmount();
        if (withdrawAmount == 0) revert ZeroAmount();
        
        // Mark as withdrawn and record amount
        loan.fundsWithdrawn = true;
        loan.withdrawnAmount = withdrawAmount;
        loan.lastUpdateTime = block.timestamp;
        
        // Transfer funds to the recipient
        IERC20(loan.tokenAddress).safeTransfer(loan.withdrawalRecipient, withdrawAmount);
        
        emit Events.FundsWithdrawn(loanId, loan.withdrawalRecipient, withdrawAmount);
        
        return withdrawAmount;
    }
    
    /**
     * @dev Check if a loan can have its funds withdrawn
     * @param loanId The ID of the loan to check
     * @return Whether the loan can be withdrawn from
     */
    function canWithdrawFunds(uint256 loanId) external view returns (bool) {
        return loans[loanId].canWithdraw() && !loans[loanId].fundsWithdrawn;
    }
    
    /**
     * @dev Get the authorized withdrawal recipient for a loan
     * @param loanId The ID of the loan
     * @return The authorized recipient address
     */
    function getWithdrawalRecipient(uint256 loanId) external view returns (address) {
        return loans[loanId].withdrawalRecipient;
    }
    
    /**
     * @dev Check if funds have been withdrawn for a loan
     * @param loanId The ID of the loan
     * @return Whether funds have been withdrawn
     */
    function hasFundsWithdrawn(uint256 loanId) external view returns (bool) {
        return loans[loanId].fundsWithdrawn;
    }
    
    /**
     * @dev Get the amount that can be withdrawn from a loan
     * @param loanId The ID of the loan
     * @return The withdrawable amount
     */
    function getWithdrawableAmount(uint256 loanId) external view returns (uint256) {
        return loans[loanId].withdrawableAmount();
    }
} 