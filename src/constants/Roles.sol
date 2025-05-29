// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title Roles
 * @dev Role definitions for access control
 */
library Roles {
    // keccak256("ADMIN_ROLE")
    bytes32 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;
    
    // keccak256("OPERATOR_ROLE")
    bytes32 public constant OPERATOR_ROLE = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    
    // keccak256("INVESTOR_ROLE")
    bytes32 public constant INVESTOR_ROLE = 0x09853d3ed6c4a7c4e606150108229e618e8a2a9f564a9eb4a5c85daeaa9a416d;
} 