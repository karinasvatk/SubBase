// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract SubBaseEvents {
    event PlanCreated(
        uint256 indexed planId,
        address indexed creator,
        uint256 price,
        uint256 billingPeriod,
        string metadata
    );

    event Subscribed(
        uint256 indexed subscriptionId,
        uint256 indexed planId,
        address indexed subscriber,
        uint256 nextBillingTime
    );

    event SubscriptionCancelled(
        uint256 indexed subscriptionId,
        address indexed subscriber
    );
}
