// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../structs/YieldStruct.sol";
import "../constants/LoanConstants.sol";

/**
 * @title YieldGuruInterest
 * @dev Library for calculating compound interest
 */
library YieldGuruInterest {
    // Step 1: Calculate rate per compounding period (scaled)
    function ratePerPeriod(uint256 rateInBasisPoints, uint256 n) internal pure returns (uint256) {
        uint256 scaledRate = (rateInBasisPoints * LoanConstants.SCALE) / 10000;
        return scaledRate / n;
    }

    // Step 2: Return (1 + r/n), scaled
    function base(uint256 ratePerPeriodScaled) internal pure returns (uint256) {
        return LoanConstants.SCALE + ratePerPeriodScaled;
    }

    // Step 3: Exponentiation for compound growth (scaled)
    function pow(uint256 baseScaled, uint256 exponent) internal pure returns (uint256) {
        uint256 result = LoanConstants.SCALE;
        for (uint256 i = 0; i < exponent; i++) {
            result = (result * baseScaled) / LoanConstants.SCALE;
        }
        return result;
    }

    // Step 4: Main function using YieldStruct
    function calculateCompoundInterest(YieldStruct memory yield) public pure returns (uint256) {
        uint256 rpn = ratePerPeriod(yield.rate, yield.timesComounded);             // r/n
        uint256 baseWithRate = base(rpn);                                          // (1 + r/n)
        uint256 exponent = yield.timesComounded * yield.time;                      // nt
        uint256 compoundFactor = pow(baseWithRate, exponent);                      // (1 + r/n)^nt

        return (yield.principal * compoundFactor) / LoanConstants.SCALE;           // A = P * factor
    }
}
