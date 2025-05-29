// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {SafeTransferLib} from "https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Loan {

    struct Investor {
        address payable investorAddress;
        uint256 amountInvested;
        uint256 amountToBePaid;
        bool usedUsdc;
    }

    address public admin;
    address public borrower;
    uint256 public amountBorrowed;
    uint256 public repaymentAmount;
    address public constant  usdcToken = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    Investor[] public investors;

    event LoanFunded(address lender, uint256 amount, uint256 time, bool usedUsdc);
    event LoanWithdrawn(address borrower, uint256 amount, uint256 time, bool usedUsdc);
    event LoanRepaid(address[] lender, uint256 amount, uint256 time, bool usedUsdc);

    constructor(
        address _borrower,
        uint256 _amount,
        uint256 _repaymentAmount,
        address _admin
    ) {
        require(_borrower != address(0), "Invalid borrower");
        borrower = _borrower;
        amountBorrowed = _amount;
        repaymentAmount = _repaymentAmount;
        admin = _admin;
    }

    // Original ETH version
    function investLoan() public payable {
        require(msg.value > 0, "Investment must be > 0");
        investors.push(Investor(payable(msg.sender), msg.value, 0, false));
        emit LoanFunded(msg.sender, msg.value, block.timestamp, false);
    }

    // New USDC version
    function investLoanWithUsdc(uint256 amount) public {
        require(amount > 0, "Investment must be > 0");
        require(IERC20(usdcToken).transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
        
        investors.push(Investor(payable(msg.sender), amount, 0, true));
        emit LoanFunded(msg.sender, amount, block.timestamp, true);
    }

    // Original ETH version
    function withdrawLoan() public {
        require(msg.sender == borrower || msg.sender == admin, "Unauthorized");
        uint256 amount = address(this).balance;
        SafeTransferLib.safeTransferAllETH(borrower);
        emit LoanWithdrawn(borrower, amount, block.timestamp, false);
    }

    // New USDC version
    function withdrawLoanUsdc() public {
        require(msg.sender == borrower || msg.sender == admin, "Unauthorized");
        uint256 usdcBalance = IERC20(usdcToken).balanceOf(address(this));
        require(usdcBalance > 0, "No USDC balance to withdraw");
        
        require(IERC20(usdcToken).transfer(borrower, usdcBalance), "USDC transfer failed");
        emit LoanWithdrawn(borrower, usdcBalance, block.timestamp, true);
    }

    // Original ETH version
    function repayLoanwithEth() public payable {
        require(msg.sender == borrower || msg.sender == admin, "Unauthorized");
        require(investors.length > 0, "No investors");

        uint256 totalInvested;
        uint256 ethInvestorCount = 0;
        
        // Count only ETH investors
        for (uint256 i = 0; i < investors.length; i++) {
            if (!investors[i].usedUsdc) {
                totalInvested += investors[i].amountInvested;
                ethInvestorCount++;
            }
        }
        
        require(ethInvestorCount > 0, "No ETH investors");

        for (uint256 i = 0; i < investors.length; i++) {
            Investor storage inv = investors[i];
            // Only process ETH investors
            if (!inv.usedUsdc) {
                uint256 share = (msg.value * inv.amountInvested) / totalInvested;
                inv.investorAddress.transfer(share);
                inv.amountToBePaid += share;
            }
        }

        emit LoanRepaid(getInvestorAddresses(false), msg.value, block.timestamp, false);
    }

    // New USDC version
    function repayLoanWithUsdc(uint256 amount) public {
        require(msg.sender == borrower || msg.sender == admin, "Unauthorized");
        require(investors.length > 0, "No investors");
        require(IERC20(usdcToken).transferFrom(msg.sender, address(this), amount), "USDC transfer failed");

        uint256 totalInvested;
        uint256 usdcInvestorCount = 0;
        
        // Count only USDC investors
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i].usedUsdc) {
                totalInvested += investors[i].amountInvested;
                usdcInvestorCount++;
            }
        }
        
        require(usdcInvestorCount > 0, "No USDC investors");

        for (uint256 i = 0; i < investors.length; i++) {
            Investor storage inv = investors[i];
            // Only process USDC investors
            if (inv.usedUsdc) {
                uint256 share = (amount * inv.amountInvested) / totalInvested;
                require(IERC20(usdcToken).transfer(inv.investorAddress, share), "USDC transfer failed");
                inv.amountToBePaid += share;
            }
        }

        emit LoanRepaid(getInvestorAddresses(true), amount, block.timestamp, true);
    }

    function getInvestorAddresses(bool usdcOnly) internal view returns (address[] memory) {
        uint256 count = 0;
        
        // Count matching investors
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i].usedUsdc == usdcOnly) {
                count++;
            }
        }
        
        address[] memory addresses = new address[](count);
        uint256 index = 0;
        
        // Fill array with matching investors
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i].usedUsdc == usdcOnly) {
                addresses[index] = investors[i].investorAddress;
                index++;
            }
        }
        
        return addresses;
    }

    function getInvestors()
        external
        view
        returns (
            address[] memory addresses,
            uint256[] memory investedAmounts,
            uint256[] memory repaidAmounts,
            bool[] memory usedUsdc
        )
    {
        addresses = new address[](investors.length);
        investedAmounts = new uint256[](investors.length);
        repaidAmounts = new uint256[](investors.length);
        usedUsdc = new bool[](investors.length);
        
        for (uint256 i = 0; i < investors.length; i++) {
            addresses[i] = investors[i].investorAddress;
            investedAmounts[i] = investors[i].amountInvested;
            repaidAmounts[i] = investors[i].amountToBePaid;
            usedUsdc[i] = investors[i].usedUsdc;
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getUsdcBalance() external view returns (uint256) {
        return IERC20(usdcToken).balanceOf(address(this));
    }
}