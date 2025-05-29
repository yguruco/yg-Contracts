// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./helpers/Position.sol";
import "./helpers/YieldGuruInterest.sol";
import "./helpers/WithdrawalHelper.sol";
import "./helpers/LoanStatusHelper.sol";
import "./structs/YieldStruct.sol";
import "./structs/LoanDetails.sol";
import "./structs/LoanState.sol";
import "./structs/PositionInfo.sol";
import "./constants/Roles.sol";
import "./constants/TokenAddresses.sol";
import "./constants/LoanConstants.sol";
import "./constants/Events.sol";
import "./errors/CustomError.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IPosition.sol";

/**
 * @title Lending
 * @dev Manages a loan pool with investment and repayment functionality
 */
contract Lending is AccessControl, ReentrancyGuard, ILending {
    using YieldGuruInterest for YieldStruct;
    using WithdrawalHelper for LoanDetails;
    using LoanStatusHelper for LoanDetails;
    using SafeERC20 for IERC20;

    // State variables
    IPosition public positionNFT;
    mapping(uint256 => LoanDetails) public loans;
    uint256 public loanIdCounter;

    // Supported tokens
    address public immutable USDC;
    address public immutable GWANDALAND;

    /**
     * @dev Constructor
     * @param admin The admin address
     * @param operator The operator address
     * @param usdcAddress The USDC token address
     * @param gwandalandAddress The Gwandaland token address
     */
    constructor(
        address admin,
        address operator,
        address usdcAddress,
        address gwandalandAddress
    ) {
        if (admin == address(0)) revert ZeroAddress("admin");
        if (operator == address(0)) revert ZeroAddress("operator");
        if (usdcAddress == address(0)) revert ZeroAddress("USDC");
        if (gwandalandAddress == address(0)) revert ZeroAddress("Gwandaland");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Roles.ADMIN_ROLE, admin);
        _grantRole(Roles.OPERATOR_ROLE, operator);

        USDC = usdcAddress;
        GWANDALAND = gwandalandAddress;

        // Create Position NFT contract
        positionNFT = IPosition(address(new Position()));
    }

    /**
     * @dev Creates a new loan
     * @param tokenAddress The address of the token for the loan
     * @param totalAmount The total amount of the loan
     * @param interestRate The interest rate in basis points
     * @param loanDuration The duration of the loan in seconds
     * @param compoundingFrequency The frequency of compounding per year
     * @return The ID of the newly created loan
     */
    function createLoan(
        address tokenAddress,
        uint256 totalAmount,
        uint256 interestRate,
        uint256 loanDuration,
        uint256 compoundingFrequency
    ) external override onlyRole(Roles.ADMIN_ROLE) returns (uint256) {
        if (tokenAddress != USDC && tokenAddress != GWANDALAND)
            revert InvalidToken();
        if (totalAmount == 0) revert ZeroAmount();
        if (interestRate == 0) revert InvalidRate();
        if (loanDuration == 0) revert InvalidLoanDuration();
        if (compoundingFrequency == 0) revert InvalidCompoundingFrequency();

        uint256 loanId = loanIdCounter++;

        loans[loanId] = LoanDetails({
            loanId: loanId,
            tokenAddress: tokenAddress,
            totalAmount: totalAmount,
            currentAmount: 0,
            interestRate: interestRate,
            loanDuration: loanDuration,
            startTime: 0,
            endTime: 0,
            state: LoanState.Active,
            compoundingFrequency: compoundingFrequency,
            fundsWithdrawn: false,
            withdrawalRecipient: address(0),
            withdrawnAmount: 0,
            totalInvested: 0,
            lastUpdateTime: block.timestamp
        });

        emit Events.LoanCreated(
            loanId,
            tokenAddress,
            totalAmount,
            interestRate,
            loanDuration
        );
        
        // Emit initial funding status
        emit Events.LoanFundingUpdated(
            loanId,
            0,
            totalAmount,
            0
        );
        
        return loanId;
    }

    /**
     * @dev Allows an investor to invest in a loan
     * @param loanId The ID of the loan to invest in
     * @param amount The amount to invest
     * @return The position ID created for this investment
     */
    function invest(uint256 loanId, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256)
    {
        LoanDetails storage loan = loans[loanId];

        // Check if loan can accept investments
        if (!loan.canAcceptInvestment()) revert LoanNotActive();
        if (amount == 0) revert ZeroAmount();
        
        // Check if investment would exceed the total needed amount
        uint256 remainingCapacity = loan.remainingInvestmentCapacity();
        if (amount > remainingCapacity) {
            // Adjust the amount to not exceed the remaining capacity
            amount = remainingCapacity;
        }

        // Transfer tokens from investor to this contract
        IERC20(loan.tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Update loan current amount and track total investments
        loan.currentAmount += amount;
        loan.totalInvested += amount;
        loan.lastUpdateTime = block.timestamp;

        // Calculate funding percentage
        uint256 fundingPercentage = loan.fundingPercentage();

        // Emit funding status update
        emit Events.LoanFundingUpdated(
            loanId,
            loan.currentAmount,
            loan.totalAmount,
            fundingPercentage
        );

        // Check if funding threshold reached
        if (loan.hasReachedFundingThreshold() && loan.state == LoanState.Active) {
            loan.state = LoanState.Funded;
            loan.startTime = block.timestamp;
            loan.endTime = block.timestamp + loan.loanDuration;
            
            emit Events.LoanFunded(loanId, loan.currentAmount);
        }
        
        // Check if loan is now fully funded
        if (loan.isFullyFunded() && fundingPercentage == 100) {
            emit Events.LoanFullyFunded(loanId, loan.currentAmount, block.timestamp);
        }

        // Calculate expected interest by creating YieldStruct
        YieldStruct memory yieldParams = YieldStruct({
            principal: amount,
            rate: loan.interestRate,
            timesComounded: loan.compoundingFrequency,
            time: loan.loanDuration / (365 days) // Convert to years
        });

        // Create position NFT for the investor
        uint256 positionId = positionNFT.createPosition(
            msg.sender,
            loan.tokenAddress,
            amount,
            loanId,
            yieldParams
        );

        emit Events.InvestmentMade(loanId, msg.sender, amount, positionId);
        return positionId;
    }

    /**
     * @dev Authorize a withdrawal recipient for a loan
     * @param loanId The ID of the loan
     * @param recipient The address to receive the withdrawn funds
     */
    function authorizeWithdrawalRecipient(uint256 loanId, address recipient)
        external
        override
        onlyRole(Roles.OPERATOR_ROLE)
    {
        if (recipient == address(0)) revert WithdrawalToZeroAddress();
        
        LoanDetails storage loan = loans[loanId];
        if (!loan.canWithdraw()) revert WithdrawalThresholdNotReached();
        
        loan.withdrawalRecipient = recipient;
        
        emit Events.WithdrawalAuthorized(loanId, msg.sender, recipient);
    }

    /**
     * @dev Withdraw funds from a loan to the authorized recipient
     * @param loanId The ID of the loan to withdraw from
     * @return The amount withdrawn
     */
    function withdrawFunds(uint256 loanId)
        external
        override
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
        if (loan.withdrawalRecipient == address(0)) revert WithdrawalToZeroAddress();
        
        // Calculate the amount to withdraw
        uint256 withdrawAmount = loan.withdrawableAmount();
        if (withdrawAmount == 0) revert InvalidWithdrawalAmount();
        
        // Mark as withdrawn and record amount
        loan.fundsWithdrawn = true;
        loan.withdrawnAmount = withdrawAmount;
        loan.lastUpdateTime = block.timestamp;
        
        // Transfer funds to the recipient
        IERC20(loan.tokenAddress).safeTransfer(loan.withdrawalRecipient, withdrawAmount);
        
        // Update loan status
        emit Events.LoanFundingUpdated(
            loanId,
            loan.currentAmount,
            loan.totalAmount,
            loan.fundingPercentage()
        );
        
        emit Events.FundsWithdrawn(loanId, loan.withdrawalRecipient, withdrawAmount);
        
        return withdrawAmount;
    }

    /**
     * @dev Allows the operator to repay a loan
     * @param loanId The ID of the loan to repay
     */
    function repayLoan(uint256 loanId)
        external
        override
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

        emit Events.LoanRepaid(loanId, totalRepayment);
        
        // Emit settlement status update
        emit Events.LoanSettlementStatusChanged(
            loanId, 
            uint8(LoanState.Repaid), 
            true
        );

        // Distribute funds to position holders
        _distributeRepayment(loanId);
    }

    /**
     * @dev Marks a loan as defaulted
     * @param loanId The ID of the loan to mark as defaulted
     */
    function markLoanAsDefaulted(uint256 loanId)
        external
        override
        onlyRole(Roles.ADMIN_ROLE)
    {
        LoanDetails storage loan = loans[loanId];

        if (loan.state != LoanState.Funded) revert LoanNotFunded();
        if (block.timestamp <= loan.endTime) revert LoanNotExpired();

        loan.state = LoanState.Defaulted;
        loan.lastUpdateTime = block.timestamp;

        emit Events.LoanDefaulted(loanId);
        
        // Emit settlement status update
        emit Events.LoanSettlementStatusChanged(
            loanId, 
            uint8(LoanState.Defaulted), 
            true
        );
    }

    /**
     * @dev Get loan details
     * @param loanId The ID of the loan
     * @return The loan details
     */
    function getLoanDetails(uint256 loanId)
        external
        view
        override
        returns (LoanDetails memory)
    {
        return loans[loanId];
    }

    /**
     * @dev Get the expected return for a position
     * @param positionId The ID of the position
     * @return The expected return amount
     */
    function getExpectedReturn(uint256 positionId)
        external
        view
        override
        returns (uint256)
    {
        PositionInfo memory position = positionNFT.getPosition(positionId);
        
        // Calculate interest using the position's yield parameters
        return
            YieldGuruInterest.calculateCompoundInterest(position.yieldParams);
    }

    /**
     * @dev Check if a token is supported
     * @param tokenAddress The address of the token to check
     * @return True if the token is supported, false otherwise
     */
    function isTokenSupported(address tokenAddress)
        external
        view
        override
        returns (bool)
    {
        return tokenAddress == USDC || tokenAddress == GWANDALAND;
    }

    /**
     * @dev Get the funding status summary for a loan
     * @param loanId The ID of the loan
     * @return totalAmount The total amount of the loan
     * @return currentAmount The current amount invested
     * @return remainingAmount The amount needed for full funding
     * @return percentageFunded The percentage of funding reached
     * @return fundsWithdrawn Whether funds have been withdrawn
     * @return withdrawnToAddress The recipient of withdrawn funds
     */
    function getLoanFundingStatus(uint256 loanId) 
        external 
        view 
        override
        returns (
            uint256 totalAmount,
            uint256 currentAmount,
            uint256 remainingAmount,
            uint256 percentageFunded,
            bool fundsWithdrawn,
            address withdrawnToAddress
        ) 
    {
        return loans[loanId].getLoanFundingSummary();
    }
    
    /**
     * @dev Get the settlement status of a loan
     * @param loanId The ID of the loan
     * @return state The current state of the loan
     * @return isSettled True if the loan is repaid or defaulted
     * @return canBeWithdrawn True if the loan can have funds withdrawn
     * @return hasBeenWithdrawn True if funds have already been withdrawn
     */
    function getLoanSettlementStatus(uint256 loanId)
        external
        view
        override
        returns (
            LoanState state,
            bool isSettled,
            bool canBeWithdrawn,
            bool hasBeenWithdrawn
        )
    {
        return loans[loanId].getLoanSettlementStatus();
    }
    
    /**
     * @dev Check if a loan can accept more investment
     * @param loanId The ID of the loan
     * @return True if the loan can accept investment
     */
    function canAcceptInvestment(uint256 loanId) 
        external 
        view 
        override
        returns (bool) 
    {
        return loans[loanId].canAcceptInvestment();
    }
    
    /**
     * @dev Get the remaining investment capacity of a loan
     * @param loanId The ID of the loan
     * @return The amount that can still be invested
     */
    function getRemainingInvestmentCapacity(uint256 loanId) 
        external 
        view 
        override
        returns (uint256) 
    {
        return loans[loanId].remainingInvestmentCapacity();
    }
    
    /**
     * @dev Get a detailed funding history of a loan
     * @param loanId The ID of the loan
     * @return totalInvested Total amount that has been invested
     * @return currentAmount Current amount in the contract
     * @return withdrawnAmount Amount that has been withdrawn
     * @return lastUpdateTime Timestamp of the last update
     */
    function getLoanFundingHistory(uint256 loanId) 
        external 
        view 
        override
        returns (
            uint256 totalInvested,
            uint256 currentAmount,
            uint256 withdrawnAmount,
            uint256 lastUpdateTime
        ) 
    {
        LoanDetails storage loan = loans[loanId];
        return (
            loan.totalInvested,
            loan.currentAmount,
            loan.withdrawnAmount,
            loan.lastUpdateTime
        );
    }

    // Internal functions
    
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
        return YieldGuruInterest.calculateCompoundInterest(yieldParams);
    }

    /**
     * @dev Distributes repayment to position holders
     * @param loanId The ID of the loan
     */
    function _distributeRepayment(uint256 loanId) internal {
        LoanDetails storage loan = loans[loanId];
        
        // Calculate total repayment amount
        uint256 totalRepayment = _calculateTotalRepayment(loanId);
        
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
     * @dev Check if a loan can have its funds withdrawn
     * @param loanId The ID of the loan to check
     * @return Whether the loan can be withdrawn from
     */
    function canWithdrawFunds(uint256 loanId) 
        external 
        view 
        override
        returns (bool) 
    {
        return loans[loanId].canWithdraw() && !loans[loanId].fundsWithdrawn;
    }
    
    /**
     * @dev Get the authorized withdrawal recipient for a loan
     * @param loanId The ID of the loan
     * @return The authorized recipient address
     */
    function getWithdrawalRecipient(uint256 loanId) 
        external 
        view 
        override
        returns (address) 
    {
        return loans[loanId].withdrawalRecipient;
    }
    
    /**
     * @dev Check if funds have been withdrawn for a loan
     * @param loanId The ID of the loan
     * @return Whether funds have been withdrawn
     */
    function hasFundsWithdrawn(uint256 loanId) 
        external 
        view 
        override
        returns (bool) 
    {
        return loans[loanId].fundsWithdrawn;
    }

    /**
     * @dev Get the amount that can be withdrawn from a loan
     * @param loanId The ID of the loan
     * @return The withdrawable amount
     */
    function getWithdrawableAmount(uint256 loanId) 
        external 
        view 
        override
        returns (uint256) 
    {
        return loans[loanId].withdrawableAmount();
    }
    
    /**
     * @dev Check if any positions (investors) exist for a specific loan
     * @param loanId The ID of the loan to check
     * @return hasPositions True if at least one position exists
     * @return positionCount The number of positions for this loan
     */
    function checkLoanPositions(uint256 loanId) 
        external 
        view 
        override
        returns (bool hasPositions, uint256 positionCount) 
    {
        uint256 tokenCount = positionNFT.getTokenId();
        
        // If no tokens have been minted, there are no positions
        if (tokenCount == 0) {
            return (false, 0);
        }
        
        // Count positions for this specific loan
        uint256 count = 0;
        for (uint256 i = 1; i <= tokenCount; i++) {
            try positionNFT.getPosition(i) returns (PositionInfo memory position) {
                if (position.loanId == loanId) {
                    count++;
                }
            } catch {
                // Skip if token doesn't exist or there's any other error
                continue;
            }
        }
        
        return (count > 0, count);
    }
}
