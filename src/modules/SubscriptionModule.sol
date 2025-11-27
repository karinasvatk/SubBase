// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SubBaseStorage} from "../storage/SubBaseStorage.sol";
import {SubBaseEvents} from "../events/SubBaseEvents.sol";
import {SubBaseErrors} from "../errors/SubBaseErrors.sol";
import {SubBaseTypes} from "../types/SubBaseTypes.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

abstract contract SubscriptionModule is SubBaseStorage, SubBaseEvents, SubBaseErrors {
    function subscribe(uint256 planId) external returns (uint256) {
        if (planId >= _planCount) revert PlanNotFound();

        SubBaseTypes.Plan storage plan = _plans[planId];
        if (!plan.active) revert PlanNotActive();

        require(
            IERC20(_usdc).transferFrom(msg.sender, plan.creator, plan.price),
            "Transfer failed"
        );

        uint256 subscriptionId = _subscriptionCount++;

        _subscriptions[subscriptionId] = SubBaseTypes.Subscription({
            id: subscriptionId,
            planId: planId,
            subscriber: msg.sender,
            nextBillingTime: block.timestamp + plan.billingPeriod,
            status: SubBaseTypes.SubscriptionStatus.Active,
            subscribedAt: block.timestamp
        });

        _userSubscriptions[msg.sender].push(subscriptionId);

        emit Subscribed(
            subscriptionId,
            planId,
            msg.sender,
            block.timestamp + plan.billingPeriod
        );

        return subscriptionId;
    }

    function cancel(uint256 subscriptionId) external {
        if (subscriptionId >= _subscriptionCount) revert SubscriptionNotFound();

        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];
        if (sub.subscriber != msg.sender) revert NotSubscriber();
        if (sub.status == SubBaseTypes.SubscriptionStatus.Cancelled) revert AlreadyCancelled();

        sub.status = SubBaseTypes.SubscriptionStatus.Cancelled;

        emit SubscriptionCancelled(subscriptionId, msg.sender);
    }

    function getSubscription(uint256 subscriptionId)
        external
        view
        returns (SubBaseTypes.Subscription memory)
    {
        if (subscriptionId >= _subscriptionCount) revert SubscriptionNotFound();
        return _subscriptions[subscriptionId];
    }

    function getUserSubscriptions(address user)
        external
        view
        returns (uint256[] memory)
    {
        return _userSubscriptions[user];
    }
}
