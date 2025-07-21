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

    event SubscriptionActivated(uint256 indexed subscriptionId);
    event SubscriptionPaused(uint256 indexed subscriptionId);
    event SubscriptionCancelled(uint256 indexed subscriptionId);

    modifier onlyOwner(uint256 subscriptionId) {
        require(
            subscriptions[subscriptionId].owner == msg.sender,
            "Not subscription owner"
        );
        _;
    }

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

    function activateSubscription(uint256 subscriptionId)
        external
        onlyOwner(subscriptionId)
    {
        Subscription storage sub = subscriptions[subscriptionId];
        require(
            sub.status == SubscriptionStatus.Created ||
                sub.status == SubscriptionStatus.Paused,
            "Cannot activate"
        );

        sub.status = SubscriptionStatus.Active;
        emit SubscriptionActivated(subscriptionId);
    }

    function pauseSubscription(uint256 subscriptionId)
        external
        onlyOwner(subscriptionId)
    {
        Subscription storage sub = subscriptions[subscriptionId];
        require(sub.status == SubscriptionStatus.Active, "Not active");

        sub.status = SubscriptionStatus.Paused;
        emit SubscriptionPaused(subscriptionId);
    }

    function cancelSubscription(uint256 subscriptionId)
        external
        onlyOwner(subscriptionId)
    {
        Subscription storage sub = subscriptions[subscriptionId];
        require(
            sub.status != SubscriptionStatus.Cancelled &&
                sub.status != SubscriptionStatus.Executed,
            "Already finalized"
        );

        sub.status = SubscriptionStatus.Cancelled;
        emit SubscriptionCancelled(subscriptionId);
    }
}
