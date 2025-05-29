// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../structs/LoanDetails.sol";
import "../structs/YieldStruct.sol";
import "../structs/LoanState.sol";
import "../helpers/Position.sol";
import "../constants/Events.sol";
import "../errors/CustomError.sol";

/**
 * @title InvestmentManager
 * @dev Module for managing investments in loans
 */
contract InvestmentManager is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Reference to the loan details mapping (will be populated by the main contract)
    mapping(uint256 => LoanDetails) internal loans;
    
    // Position NFT contract
    Position public immutable positionNFT;
    
    /**
     * @dev Constructor
     * @param positionNFTAddress The address of the Position NFT contract
     */
    constructor(address positionNFTAddress) {
        require(positionNFTAddress != address(0), "InvestmentManager: position NFT cannot be zero address");
        positionNFT = Position(positionNFTAddress);
    }
    
    /**
     * @dev Allows an investor to invest in a loan
     * @param loanId The ID of the loan to invest in
     * @param amount The amount to invest
     * @return positionId The ID of the created position
     */
    function invest(uint256 loanId, uint256 amount)
        external
        nonReentrant
        returns (uint256 positionId)
    {
        LoanDetails storage loan = loans[loanId];
        
        // Check loan state
        if (loan.state != LoanState.Created) revert LoanNotActive();
        
        // Check investment amount
        if (amount == 0) revert ZeroAmount();
        
        // Check if the investment would exceed the loan total
        uint256 newTotal = loan.currentAmount + amount;
        if (newTotal > loan.totalAmount) {
            revert InvestmentExceedsTotal();
        }
        
        // Transfer tokens from investor to this contract
        IERC20(loan.tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        
        // Update loan state
        loan.currentAmount = newTotal;
        loan.lastUpdateTime = block.timestamp;
        
        // Calculate funding percentage
        uint256 fundingPercentage = (newTotal * 100) / loan.totalAmount;
        
        // Check if loan is now fully funded
        if (newTotal == loan.totalAmount) {
            loan.state = LoanState.Funded;
            emit Events.LoanFunded(loanId, newTotal, block.timestamp);
        }
        
        // Create YieldStruct for this position
        YieldStruct memory posYield = YieldStruct({
            principal: amount,
            rate: loan.interestRate,
            timesComounded: loan.compoundingFrequency,
            time: loan.loanDuration / (365 days) // Convert to years
        });
        
        // Create position NFT
        positionId = positionNFT.createPosition(
            msg.sender,
            loan.tokenAddress,
            amount,
            loanId,
            posYield
        );
        
        // Emit events
        emit Events.InvestmentMade(loanId, msg.sender, amount, positionId);
        emit Events.PositionCreated(positionId, loanId, msg.sender, amount, block.timestamp);
        
        return positionId;
    }
    
    /**
     * @dev Get the current investment status for a loan
     * @param loanId The ID of the loan
     * @return currentAmount The current invested amount
     * @return totalAmount The total loan amount
     * @return percentage The funding percentage (0-100)
     */
    function getInvestmentStatus(uint256 loanId)
        external
        view
        returns (
            uint256 currentAmount,
            uint256 totalAmount,
            uint256 percentage
        )
    {
        LoanDetails storage loan = loans[loanId];
        
        currentAmount = loan.currentAmount;
        totalAmount = loan.totalAmount;
        percentage = totalAmount > 0 ? (currentAmount * 100) / totalAmount : 0;
    }
    
    /**
     * @dev Get all investment positions for an investor
     * @param investor The address of the investor
     * @return An array of position IDs belonging to the investor
     */
    function getInvestorPositions(address investor)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = positionNFT.getTokenId();
        uint256[] memory investorPositions = new uint256[](tokenCount);
        uint256 posCount = 0;
        
        for (uint256 i = 1; i <= tokenCount; i++) {
            if (positionNFT.ownerOf(i) == investor) {
                investorPositions[posCount] = i;
                posCount++;
            }
        }
        
        // Resize array to fit the actual number of positions
        uint256[] memory result = new uint256[](posCount);
        for (uint256 i = 0; i < posCount; i++) {
            result[i] = investorPositions[i];
        }
        
        return result;
    }
} 