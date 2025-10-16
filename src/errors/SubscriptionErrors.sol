// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface SubscriptionErrors {
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidInterval();
    error InvalidUSDCAddress();
    error NotSubscriptionOwner();
    error CannotActivate();
    error NotActive();
    error TooEarlyToCharge();
    error TransferFailed();
    error AlreadyFinalized();
    error SubscriptionNotFound();
}
