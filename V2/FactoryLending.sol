// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Lending.sol";
import "./constants/TokenAddresses.sol";
import "./constants/Events.sol";
import "./interfaces/IFactoryLending.sol";

/**
 * @title FactoryLending
 * @dev Factory contract to deploy and manage multiple lending contracts
 */
contract FactoryLending is Ownable, IFactoryLending {
    // Constants for token addresses
    address public immutable USDC;
    address public immutable GWANDALAND;

    // Mapping of active lending contracts
    mapping(address => bool) public activeLendingContracts;

    // Array to keep track of all lending contracts
    address[] public lendingContracts;

    /**
     * @dev Constructor
     * @param usdcAddress The USDC token address
     * @param gwandalandAddress The Gwandaland token address
     */
    constructor(address usdcAddress, address gwandalandAddress) Ownable(msg.sender) {
        require(usdcAddress != address(0), "FactoryLending: USDC cannot be zero address");
        require(gwandalandAddress != address(0), "FactoryLending: Gwandaland cannot be zero address");

        USDC = usdcAddress;
        GWANDALAND = gwandalandAddress;
    }

    /**
     * @dev Creates a new lending contract
     * @param admin The admin address for the new lending contract
     * @param operator The operator address for the new lending contract
     * @return The address of the newly created lending contract
     */
    function createLendingContract(address admin, address operator) external override onlyOwner returns (address) {
        require(admin != address(0), "FactoryLending: admin cannot be zero address");
        require(operator != address(0), "FactoryLending: operator cannot be zero address");

        Lending newLendingContract = new Lending(
            admin,
            operator,
            USDC,
            GWANDALAND
        );

        address lendingContractAddress = address(newLendingContract);
        activeLendingContracts[lendingContractAddress] = true;
        lendingContracts.push(lendingContractAddress);

        emit Events.LendingContractCreated(lendingContractAddress, admin, operator);

        return lendingContractAddress;
    }

    /**
     * @dev Deactivates a lending contract
     * @param lendingContract The address of the lending contract to deactivate
     */
    function deactivateLendingContract(address lendingContract) external override onlyOwner {
        require(activeLendingContracts[lendingContract], "FactoryLending: contract not active");

        activeLendingContracts[lendingContract] = false;

        emit Events.LendingContractDeactivated(lendingContract);
    }

    /**
     * @dev Checks if a lending contract is active
     * @param lendingContract The address of the lending contract to check
     * @return True if the lending contract is active, false otherwise
     */
    function isLendingContractActive(address lendingContract) external view override returns (bool) {
        return activeLendingContracts[lendingContract];
    }

    /**
     * @dev Gets the total number of lending contracts created
     * @return The total number of lending contracts
     */
    function getLendingContractCount() external view override returns (uint256) {
        return lendingContracts.length;
    }

    /**
     * @dev Gets all active lending contracts
     * @return An array of active lending contract addresses
     */
    function getActiveLendingContracts() external view override returns (address[] memory) {
        uint256 activeCount = 0;

        // Count active contracts
        for (uint256 i = 0; i < lendingContracts.length; i++) {
            if (activeLendingContracts[lendingContracts[i]]) {
                activeCount++;
            }
        }

        // Create array of active contracts
        address[] memory activeContracts = new address[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < lendingContracts.length; i++) {
            if (activeLendingContracts[lendingContracts[i]]) {
                activeContracts[index] = lendingContracts[i];
                index++;
            }
        }

        return activeContracts;
    }
}
