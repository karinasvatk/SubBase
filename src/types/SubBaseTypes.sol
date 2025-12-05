// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library SubBaseTypes {
    enum SubscriptionStatus {
        Active,
        Cancelled,
        PastDue,
        Suspended
    }

    struct Plan {
        uint256 id;
        address creator;
        uint256 price;
        uint256 billingPeriod;
        string metadata;
        bool active;
        uint256 createdAt;
    }

    struct Subscription {
        uint256 id;
        uint256 planId;
        address subscriber;
        uint256 nextBillingTime;
        SubscriptionStatus status;
        uint256 subscribedAt;
    }
}
