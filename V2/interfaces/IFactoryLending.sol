// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IFactoryLending
 * @dev Interface for the FactoryLending contract
 */
interface IFactoryLending {
    /**
     * @dev Creates a new lending contract
     * @param admin The admin address for the new lending contract
     * @param operator The operator address for the new lending contract
     * @return The address of the newly created lending contract
     */
    function createLendingContract(address admin, address operator) external returns (address);

    /**
     * @dev Deactivates a lending contract
     * @param lendingContract The address of the lending contract to deactivate
     */
    function deactivateLendingContract(address lendingContract) external;

    /**
     * @dev Checks if a lending contract is active
     * @param lendingContract The address of the lending contract to check
     * @return True if the lending contract is active, false otherwise
     */
    function isLendingContractActive(address lendingContract) external view returns (bool);

    /**
     * @dev Gets the total number of lending contracts created
     * @return The total number of lending contracts
     */
    function getLendingContractCount() external view returns (uint256);

    /**
     * @dev Gets all active lending contracts
     * @return An array of active lending contract addresses
     */
    function getActiveLendingContracts() external view returns (address[] memory);
} 