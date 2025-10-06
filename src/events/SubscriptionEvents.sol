// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract SubscriptionEvents {
    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed owner,
        address indexed recipient,
        uint256 amount,
        uint256 interval,
        string description
    );

    event SubscriptionActivated(uint256 indexed subscriptionId);
    event SubscriptionPaused(uint256 indexed subscriptionId);
    event SubscriptionCancelled(uint256 indexed subscriptionId);

    event SubscriptionCharged(
        uint256 indexed subscriptionId,
        uint256 amount,
        uint256 nextChargeTime
    );

    event SubscriptionUpdated(
        uint256 indexed subscriptionId,
        uint256 newAmount,
        uint256 newInterval
    );
}
