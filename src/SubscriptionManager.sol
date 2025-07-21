// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SubscriptionManager {
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
    }

    mapping(uint256 => Subscription) public subscriptions;
    uint256 public subscriptionCount;

    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed owner,
        address indexed recipient,
        uint256 amount,
        uint256 interval
    );

    function createSubscription(
        address recipient,
        uint256 amount,
        uint256 interval
    ) external returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(interval > 0, "Invalid interval");

        uint256 subscriptionId = subscriptionCount++;

        subscriptions[subscriptionId] = Subscription({
            owner: msg.sender,
            recipient: recipient,
            amount: amount,
            interval: interval,
            nextChargeTime: block.timestamp + interval,
            status: SubscriptionStatus.Created
        });

        emit SubscriptionCreated(
            subscriptionId,
            msg.sender,
            recipient,
            amount,
            interval
        );

        return subscriptionId;
    }
}
