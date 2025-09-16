// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubscriptionManager {
    enum SubscriptionStatus {
        Created,
        Active,
        Paused,
        Cancelled,
        Executed
    }

    struct Subscription {
        address owner;
        address recipient;
        uint256 amount;
        uint256 interval;
        uint256 nextChargeTime;
        SubscriptionStatus status;
        string description;
    }

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

    function createSubscription(
        address recipient,
        uint256 amount,
        uint256 interval,
        string calldata description
    ) external returns (uint256);

    function activateSubscription(uint256 subscriptionId) external;
    function pauseSubscription(uint256 subscriptionId) external;
    function cancelSubscription(uint256 subscriptionId) external;
    function executeSubscription(uint256 subscriptionId) external;

    function getSubscription(uint256 subscriptionId)
        external
        view
        returns (
            address owner,
            address recipient,
            uint256 amount,
            uint256 interval,
            uint256 nextChargeTime,
            SubscriptionStatus status
        );

    function isSubscriptionDue(uint256 subscriptionId)
        external
        view
        returns (bool);
}
