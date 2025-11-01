// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract SubscriptionStorage {
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

    mapping(uint256 => Subscription) internal _subscriptions;
    uint256 internal _subscriptionCount;

    uint256[48] private __gap;
}
