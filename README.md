# YieldGuru Contracts

This repository contains the smart contracts powering the YieldGuru protocol.

##  Project Structure

- `V1/`
  - Contains the original contract `LoanContract.sol` that is currently deployed and powering the live website.
  
- `V2/`
  - Represents the next iteration of the YieldGuru contracts.
  - Includes modular architecture broken into:
    - `constants/`: Project-wide constants (events, roles, addresses, etc.)
    - `errors/`: Custom error definitions
    - `examples/`: Demo contracts for understanding status and withdrawals
    - `helpers/`: Utility functions for positions, interest, withdrawals, etc.
    - `interfaces/`: Interfaces for contracts to promote modularity and upgradability
    - `modules/`: Core modules for managing investments, loans, repayments, and withdrawals
    - `structs/`: Shared data structures used across contracts
    - `utils/`: Placeholder for utility logic (currently empty)

## ⚠️ Disclaimer

- The `V2` contracts are **in active development**.
- **Code is not tested** and **should not be used in production**.
- Expect breaking changes and frequent updates as development progresses.
- For now ignore the examples folder 
##  Status

> The project is evolving rapidly. Contributions, suggestions, and feedback are welcome.

---

