// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../structs/LoanDetails.sol";
import "../structs/LoanState.sol";
import "../constants/Roles.sol";
import "../constants/Events.sol";
import "../errors/CustomError.sol";

/**
 * @title LoanManager
 * @dev Module for managing loan creation and lifecycle
 */
contract LoanManager is AccessControl {
    using SafeERC20 for IERC20;
    
    // Counter for loan IDs
    uint256 private _loanIdCounter = 0;
    
    // Loan details mapping
    mapping(uint256 => LoanDetails) public loans;
    
    // Supported tokens
    mapping(address => bool) public supportedTokens;
    
    // Default funding threshold (percentage)
    uint256 public defaultFundingThreshold;
    
    /**
     * @dev Constructor
     * @param admin The admin address
     * @param operator The operator address
     * @param initialFundingThreshold The initial funding threshold percentage
     */
    constructor(
        address admin,
        address operator,
        uint256 initialFundingThreshold
    ) {
        require(admin != address(0), "LoanManager: admin cannot be zero address");
        require(operator != address(0), "LoanManager: operator cannot be zero address");
        require(
            initialFundingThreshold > 0 && initialFundingThreshold <= 100,
            "LoanManager: invalid funding threshold"
        );
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Roles.ADMIN_ROLE, admin);
        _grantRole(Roles.OPERATOR_ROLE, operator);
        
        defaultFundingThreshold = initialFundingThreshold;
        
        // Start loan IDs at 1
        _loanIdCounter = 1;
    }
    
    /**
     * @dev Creates a new loan
     * @param tokenAddress The address of the token to be loaned
     * @param amount The total amount of the loan
     * @param interestRate The annual interest rate (in basis points, e.g., 500 = 5%)
     * @param compoundingFrequency The number of times interest compounds per year
     * @param loanDuration The duration of the loan in seconds
     * @param customFundingThreshold Optional custom funding threshold (0 to use default)
     * @return loanId The ID of the newly created loan
     */
    function createLoan(
        address tokenAddress,
        uint256 amount,
        uint256 interestRate,
        uint256 compoundingFrequency,
        uint256 loanDuration,
        uint256 customFundingThreshold
    )
        external
        onlyRole(Roles.OPERATOR_ROLE)
        returns (uint256 loanId)
    {
        // Validate parameters
        if (!supportedTokens[tokenAddress]) revert UnsupportedToken(tokenAddress);
        if (amount == 0) revert ZeroAmount();
        if (interestRate == 0) revert InvalidInterestRate();
        if (compoundingFrequency == 0) revert InvalidCompoundingFrequency();
        if (loanDuration == 0) revert InvalidLoanParameters();
        
        // Get the next loan ID
        loanId = _loanIdCounter;
        _loanIdCounter += 1;
        
        // Use default funding threshold if custom is 0
        uint256 fundingThresholdToUse = customFundingThreshold > 0 ?
            customFundingThreshold : defaultFundingThreshold;
        
        // Create and store the loan details
        loans[loanId] = LoanDetails({
            loanId: loanId,
            tokenAddress: tokenAddress,
            totalAmount: amount,
            currentAmount: 0,
            interestRate: interestRate,
            compoundingFrequency: compoundingFrequency,
            loanDuration: loanDuration,
            startTime: block.timestamp,
            endTime: 0, // Will be set when loan is funded
            state: LoanState.Created,
            fundsWithdrawn: false,
            withdrawalRecipient: address(0),
            withdrawnAmount: 0,
            totalInvested: 0,
            lastUpdateTime: block.timestamp
        });
        
        // Emit loan creation event
        emit Events.LoanCreated(
            loanId,
            tokenAddress,
            amount,
            interestRate,
            compoundingFrequency,
            loanDuration,
            block.timestamp,
            0 // End time not set yet
        );
        
        return loanId;
    }
    
    /**
     * @dev Marks a loan as defaulted if it has expired and not been repaid
     * @param loanId The ID of the loan
     */
    function markLoanAsDefaulted(uint256 loanId)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        LoanDetails storage loan = loans[loanId];
        
        // Check loan state
        if (loan.state != LoanState.Funded) revert LoanNotFunded();
        if (block.timestamp <= loan.endTime) revert LoanNotExpired();
        
        // Mark as defaulted
        loan.state = LoanState.Defaulted;
        loan.lastUpdateTime = block.timestamp;
        
        // Emit events
        emit Events.LoanDefaulted(loanId, block.timestamp);
        emit Events.LoanSettlementStatusChanged(loanId, uint8(LoanState.Defaulted), true);
    }
    
    /**
     * @dev Cancels a loan that hasn't been funded yet
     * @param loanId The ID of the loan
     */
    function cancelLoan(uint256 loanId)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        LoanDetails storage loan = loans[loanId];
        
        // Check loan state
        if (loan.state != LoanState.Created) revert InvalidLoanStatus();
        
        // Mark as cancelled
        loan.state = LoanState.Cancelled;
        loan.lastUpdateTime = block.timestamp;
        
        // Emit event
        emit Events.LoanCancelled(loanId, block.timestamp);
    }
    
    /**
     * @dev Updates a loan's funding status once threshold is reached
     * @param loanId The ID of the loan
     */
    function updateLoanFundingStatus(uint256 loanId)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        LoanDetails storage loan = loans[loanId];
        
        // Check loan state
        if (loan.state != LoanState.Created) revert InvalidLoanStatus();
        
        // Calculate funding percentage
        uint256 fundingPercentage = (loan.currentAmount * 100) / loan.totalAmount;
        
        // Check if loan has reached the funding threshold
        if (fundingPercentage >= defaultFundingThreshold) {
            // Update loan state to funded
            loan.state = LoanState.Funded;
            loan.startTime = block.timestamp;
            loan.endTime = block.timestamp + loan.loanDuration;
            loan.lastUpdateTime = block.timestamp;
            
            // Emit event
            emit Events.LoanFunded(loanId, loan.currentAmount, block.timestamp);
        }
    }
    
    /**
     * @dev Add a supported token
     * @param tokenAddress The address of the token to support
     */
    function addSupportedToken(address tokenAddress)
        external
        onlyRole(Roles.ADMIN_ROLE)
    {
        if (tokenAddress == address(0)) revert ZeroAddress("tokenAddress");
        supportedTokens[tokenAddress] = true;
    }
    
    /**
     * @dev Remove a supported token
     * @param tokenAddress The address of the token to remove support for
     */
    function removeSupportedToken(address tokenAddress)
        external
        onlyRole(Roles.ADMIN_ROLE)
    {
        supportedTokens[tokenAddress] = false;
    }
    
    /**
     * @dev Update the default funding threshold
     * @param newThreshold The new funding threshold percentage
     */
    function updateDefaultFundingThreshold(uint256 newThreshold)
        external
        onlyRole(Roles.ADMIN_ROLE)
    {
        require(
            newThreshold > 0 && newThreshold <= 100,
            "LoanManager: invalid funding threshold"
        );
        
        defaultFundingThreshold = newThreshold;
    }
    
    /**
     * @dev Get loan details
     * @param loanId The ID of the loan
     * @return The loan details
     */
    function getLoanDetails(uint256 loanId)
        external
        view
        returns (LoanDetails memory)
    {
        return loans[loanId];
    }
    
    /**
     * @dev Get the total number of loans created
     * @return The total number of loans
     */
    function getTotalLoans() external view returns (uint256) {
        return _loanIdCounter - 1;
    }
} 