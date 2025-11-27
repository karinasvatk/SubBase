// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface SubBaseErrors {
    error InvalidPrice();
    error InvalidBillingPeriod();
    error InvalidUSDCAddress();
    error PlanNotFound();
    error PlanNotActive();
    error SubscriptionNotFound();
    error NotSubscriber();
    error AlreadyCancelled();
    error Unauthorized();
}
