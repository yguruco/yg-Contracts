// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../structs/LoanDetails.sol";
import "../structs/YieldStruct.sol";
import "../structs/PositionInfo.sol";
import "../structs/LoanState.sol";
import "../helpers/Position.sol";
import "../constants/Roles.sol";
import "../constants/Events.sol";
import "../errors/CustomError.sol";

/**
 * @title InterestCalculator
 * @dev Interface for interest calculation functions
 */
interface InterestCalculator {
    function calculateCompoundInterest(YieldStruct memory yield) external pure returns (uint256);
}

/**
 * @title RepaymentManager
 * @dev Module for managing loan repayments and interest distribution
 */
contract RepaymentManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Reference to the loan details mapping (will be populated by the main contract)
    mapping(uint256 => LoanDetails) internal loans;
    
    // Position NFT contract
    Position public immutable positionNFT;
    
    // Address of the interest calculator contract
    address public immutable interestCalculator;
    
    /**
     * @dev Constructor
     * @param admin The admin address
     * @param operator The operator address
     * @param positionNFTAddress The address of the Position NFT contract
     * @param interestCalculatorAddress The address of the interest calculator contract
     */
    constructor(
        address admin,
        address operator,
        address positionNFTAddress,
        address interestCalculatorAddress
    ) {
        require(admin != address(0), "RepaymentManager: admin cannot be zero address");
        require(operator != address(0), "RepaymentManager: operator cannot be zero address");
        require(positionNFTAddress != address(0), "RepaymentManager: position NFT cannot be zero address");
        require(interestCalculatorAddress != address(0), "RepaymentManager: interest calculator cannot be zero address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Roles.ADMIN_ROLE, admin);
        _grantRole(Roles.OPERATOR_ROLE, operator);
        
        positionNFT = Position(positionNFTAddress);
        interestCalculator = interestCalculatorAddress;
    }
    
    /**
     * @dev Allows the operator to repay a loan
     * @param loanId The ID of the loan to repay
     */
    function repayLoan(uint256 loanId)
        external
        nonReentrant
        onlyRole(Roles.OPERATOR_ROLE)
    {
        LoanDetails storage loan = loans[loanId];

        if (loan.state != LoanState.Funded) revert LoanNotFunded();
        if (block.timestamp > loan.endTime) revert LoanExpired();

        // Calculate total repayment amount including interest
        uint256 totalRepayment = _calculateTotalRepayment(loanId);

        // Transfer repayment from operator to this contract
        IERC20(loan.tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            totalRepayment
        );

        // Mark loan as repaid
        loan.state = LoanState.Repaid;
        loan.lastUpdateTime = block.timestamp;

        emit Events.LoanRepaid(loanId, totalRepayment, block.timestamp);
        
        // Emit settlement status update
        emit Events.LoanSettlementStatusChanged(
            loanId, 
            uint8(LoanState.Repaid), 
            true
        );

        // Distribute funds to position holders
        _distributeRepayment(loanId, totalRepayment);
    }
    
    /**
     * @dev Calculates the total repayment amount for a loan
     * @param loanId The ID of the loan
     * @return The total repayment amount
     */
    function _calculateTotalRepayment(uint256 loanId)
        internal
        view
        returns (uint256)
    {
        LoanDetails storage loan = loans[loanId];
        
        // Create YieldStruct for the total loan amount
        YieldStruct memory yieldParams = YieldStruct({
            principal: loan.currentAmount,
            rate: loan.interestRate,
            timesComounded: loan.compoundingFrequency,
            time: loan.loanDuration / (365 days) // Convert to years
        });
        
        // Calculate total repayment using the interest calculator
        return InterestCalculator(interestCalculator).calculateCompoundInterest(yieldParams);
    }
    
    /**
     * @dev Distributes repayment to position holders
     * @param loanId The ID of the loan
     * @param totalRepayment The total repayment amount
     */
    function _distributeRepayment(uint256 loanId, uint256 totalRepayment) internal {
        LoanDetails storage loan = loans[loanId];
        
        // Get the total number of position NFTs
        uint256 tokenCount = positionNFT.getTokenId();
        
        // Distribute to each position holder
        for (uint256 i = 1; i <= tokenCount; i++) {
            try positionNFT.getPosition(i) returns (
                PositionInfo memory position
            ) {
                // Check if position belongs to this loan and hasn't been withdrawn
                if (position.loanId == loanId && !position.withdrawn) {
                    // Calculate this position's share of the repayment
                    uint256 positionShare = (totalRepayment * position.amount) /
                        loan.currentAmount;
                    
                    // Transfer tokens to position holder
                    IERC20(loan.tokenAddress).safeTransfer(
                        position.investor,
                        positionShare
                    );
                    
                    // Mark position as withdrawn
                    positionNFT.markWithdrawn(i);
                    
                    emit Events.InterestDistributed(
                        loanId,
                        position.investor,
                        positionShare
                    );
                }
            } catch {
                // Skip if token doesn't exist or there's any other error
                continue;
            }
        }
    }
    
    /**
     * @dev Get the expected return for a position
     * @param positionId The ID of the position
     * @return The expected return amount
     */
    function getExpectedReturn(uint256 positionId)
        external
        view
        returns (uint256)
    {
        PositionInfo memory position = positionNFT.getPosition(positionId);
        
        // Calculate interest using the position's yield parameters
        return InterestCalculator(interestCalculator).calculateCompoundInterest(position.yieldParams);
    }
} 