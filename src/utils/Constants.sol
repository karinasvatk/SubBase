// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Constants {
    uint256 public constant MIN_INTERVAL = 1 days;
    uint256 public constant MAX_INTERVAL = 365 days;
    uint256 public constant MIN_AMOUNT = 1e6;
    uint256 public constant MAX_AMOUNT = 1000000e6;

    address public constant USDC_BASE_MAINNET =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant USDC_BASE_SEPOLIA =
        0x036CbD53842c5426634e7929541eC2318f3dCF7e;
}
