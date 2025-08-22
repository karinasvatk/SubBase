// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./AccessControl.sol";

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract SubscriptionManagerUpgradeable is
    Initializable,
    UUPSUpgradeable,
    AccessControl
{
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidInterval();
    error InvalidUSDCAddress();
    error NotSubscriptionOwner();
    error CannotActivate();
    error NotActive();
    error TooEarlyToCharge();
    error TransferFailed();
    error AlreadyFinalized();

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

    IERC20 public usdc;

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
    event SubscriptionCharged(
        uint256 indexed subscriptionId,
        uint256 amount,
        uint256 nextChargeTime
    );

    function initialize(address _usdc) public initializer {
        if (_usdc == address(0)) revert InvalidUSDCAddress();
        __UUPSUpgradeable_init();
        usdc = IERC20(_usdc);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    modifier onlyOwner(uint256 subscriptionId) {
        if (subscriptions[subscriptionId].owner != msg.sender)
            revert NotSubscriptionOwner();
        _;
    }

    function createSubscription(
        address recipient,
        uint256 amount,
        uint256 interval
    ) external returns (uint256) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (interval == 0) revert InvalidInterval();

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
        if (
            sub.status != SubscriptionStatus.Created &&
            sub.status != SubscriptionStatus.Paused
        ) revert CannotActivate();

        sub.status = SubscriptionStatus.Active;
        emit SubscriptionActivated(subscriptionId);
    }

    function pauseSubscription(uint256 subscriptionId)
        external
        onlyOwner(subscriptionId)
    {
        Subscription storage sub = subscriptions[subscriptionId];
        if (sub.status != SubscriptionStatus.Active) revert NotActive();

        sub.status = SubscriptionStatus.Paused;
        emit SubscriptionPaused(subscriptionId);
    }

    function cancelSubscription(uint256 subscriptionId)
        external
        onlyOwner(subscriptionId)
    {
        Subscription storage sub = subscriptions[subscriptionId];
        if (
            sub.status == SubscriptionStatus.Cancelled ||
            sub.status == SubscriptionStatus.Executed
        ) revert AlreadyFinalized();

        sub.status = SubscriptionStatus.Cancelled;
        emit SubscriptionCancelled(subscriptionId);
    }

    function executeSubscription(uint256 subscriptionId)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        Subscription storage sub = subscriptions[subscriptionId];

        if (sub.status != SubscriptionStatus.Active) revert NotActive();
        if (block.timestamp < sub.nextChargeTime) revert TooEarlyToCharge();

        if (!usdc.transferFrom(sub.owner, sub.recipient, sub.amount))
            revert TransferFailed();

        sub.nextChargeTime = block.timestamp + sub.interval;

        emit SubscriptionCharged(
            subscriptionId,
            sub.amount,
            sub.nextChargeTime
        );
    }

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
        )
    {
        Subscription storage sub = subscriptions[subscriptionId];
        return (
            sub.owner,
            sub.recipient,
            sub.amount,
            sub.interval,
            sub.nextChargeTime,
            sub.status
        );
    }

    function isSubscriptionDue(uint256 subscriptionId)
        external
        view
        returns (bool)
    {
        Subscription storage sub = subscriptions[subscriptionId];
        return
            sub.status == SubscriptionStatus.Active &&
            block.timestamp >= sub.nextChargeTime;
    }

    function batchExecuteSubscriptions(uint256[] calldata subscriptionIds)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        for (uint256 i = 0; i < subscriptionIds.length; i++) {
            uint256 subId = subscriptionIds[i];
            Subscription storage sub = subscriptions[subId];

            if (
                sub.status == SubscriptionStatus.Active &&
                block.timestamp >= sub.nextChargeTime
            ) {
                if (usdc.transferFrom(sub.owner, sub.recipient, sub.amount)) {
                    sub.nextChargeTime = block.timestamp + sub.interval;
                    emit SubscriptionCharged(
                        subId,
                        sub.amount,
                        sub.nextChargeTime
                    );
                }
            }
        }
    }
}
