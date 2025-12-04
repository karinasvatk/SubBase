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

    // V2 events
    event ChargeSuccessful(
        uint256 indexed subscriptionId,
        uint256 amount,
        uint256 nextBillingTime
    );

    event ChargeFailed(
        uint256 indexed subscriptionId,
        uint256 attempt,
        string reason
    );

    event SubscriptionPastDue(
        uint256 indexed subscriptionId,
        uint256 gracePeriodEnd
    );

    event SubscriptionSuspended(
        uint256 indexed subscriptionId
    );

    event SubscriptionReactivated(
        uint256 indexed subscriptionId
    );

    event GracePeriodUpdated(
        uint256 oldPeriod,
        uint256 newPeriod
    );

    event MaxRetryAttemptsUpdated(
        uint256 oldAttempts,
        uint256 newAttempts
    );
}
