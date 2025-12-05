// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SubBaseStorage} from "../storage/SubBaseStorage.sol";
import {SubBaseEvents} from "../events/SubBaseEvents.sol";
import {SubBaseErrors} from "../errors/SubBaseErrors.sol";
import {SubBaseTypes} from "../types/SubBaseTypes.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

abstract contract ChargeModule is SubBaseStorage, SubBaseEvents, SubBaseErrors {
    /**
     * @notice Charge a subscription if due for billing
     * @param subscriptionId The ID of the subscription to charge
     * @return success True if charge was successful
     */
    function charge(uint256 subscriptionId) public returns (bool success) {
        if (subscriptionId >= _subscriptionCount) revert SubscriptionNotFound();

        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];
        SubBaseTypes.Plan storage plan = _plans[sub.planId];

        // Check if subscription is in a chargeable state
        if (
            sub.status != SubBaseTypes.SubscriptionStatus.Active
                && sub.status != SubBaseTypes.SubscriptionStatus.PastDue
        ) {
            revert SubscriptionNotActive();
        }

        // Check if due for charge
        if (block.timestamp < sub.nextBillingTime) {
            revert NotDueForCharge();
        }

        // Attempt the charge
        try IERC20(_usdc).transferFrom(sub.subscriber, plan.creator, plan.price) returns (bool result) {
            if (!result) {
                return _handleFailedCharge(subscriptionId, "Transfer failed");
            }

            // Charge successful - reset failed attempts and update billing time
            _failedAttempts[subscriptionId] = 0;
            _lastChargeAttempt[subscriptionId] = block.timestamp;
            _gracePeriodEnd[subscriptionId] = 0;
            sub.nextBillingTime = block.timestamp + plan.billingPeriod;

            // If subscription was PastDue, reactivate it
            if (sub.status == SubBaseTypes.SubscriptionStatus.PastDue) {
                sub.status = SubBaseTypes.SubscriptionStatus.Active;
            }

            emit ChargeSuccessful(subscriptionId, plan.price, sub.nextBillingTime);
            return true;
        } catch {
            return _handleFailedCharge(subscriptionId, "Insufficient balance");
        }
    }

    /**
     * @notice Batch charge multiple subscriptions
     * @param subscriptionIds Array of subscription IDs to charge
     * @return successCount Number of successful charges
     * @return failCount Number of failed charges
     */
    function batchCharge(uint256[] calldata subscriptionIds)
        external
        returns (uint256 successCount, uint256 failCount)
    {
        for (uint256 i = 0; i < subscriptionIds.length; i++) {
            try this.charge(subscriptionIds[i]) returns (bool success) {
                if (success) {
                    successCount++;
                } else {
                    failCount++;
                }
            } catch {
                failCount++;
            }
        }
    }

    /**
     * @notice Get subscriptions that are due for charging
     * @param limit Maximum number of subscriptions to return
     * @return chargeableIds Array of subscription IDs ready to be charged
     */
    function getChargeableSubscriptions(uint256 limit)
        external
        view
        returns (uint256[] memory chargeableIds)
    {
        uint256[] memory tempIds = new uint256[](_subscriptionCount);
        uint256 count = 0;

        for (uint256 i = 0; i < _subscriptionCount && count < limit; i++) {
            if (isChargeable(i)) {
                tempIds[count] = i;
                count++;
            }
        }

        // Create properly sized array
        chargeableIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            chargeableIds[i] = tempIds[i];
        }
    }

    /**
     * @notice Check if a subscription is chargeable
     * @param subscriptionId The ID of the subscription
     * @return True if the subscription can be charged
     */
    function isChargeable(uint256 subscriptionId) public view returns (bool) {
        if (subscriptionId >= _subscriptionCount) return false;

        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];

        // Must be Active or PastDue
        if (
            sub.status != SubBaseTypes.SubscriptionStatus.Active
                && sub.status != SubBaseTypes.SubscriptionStatus.PastDue
        ) {
            return false;
        }

        // Must be due for charge
        if (block.timestamp < sub.nextBillingTime) {
            return false;
        }

        // If PastDue, must not have exceeded max retry attempts
        if (sub.status == SubBaseTypes.SubscriptionStatus.PastDue) {
            if (_failedAttempts[subscriptionId] >= _maxRetryAttempts) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Retry charging a PastDue subscription
     * @param subscriptionId The ID of the subscription
     * @return success True if charge was successful
     */
    function retryCharge(uint256 subscriptionId) external returns (bool success) {
        if (subscriptionId >= _subscriptionCount) revert SubscriptionNotFound();

        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];

        if (sub.status != SubBaseTypes.SubscriptionStatus.PastDue) {
            revert SubscriptionNotActive();
        }

        if (_failedAttempts[subscriptionId] >= _maxRetryAttempts) {
            revert MaxRetryAttemptsReached();
        }

        return charge(subscriptionId);
    }

    /**
     * @notice Mark a subscription as suspended after max retry attempts
     * @param subscriptionId The ID of the subscription
     */
    function markSuspended(uint256 subscriptionId) external {
        if (subscriptionId >= _subscriptionCount) revert SubscriptionNotFound();

        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];

        if (sub.status != SubBaseTypes.SubscriptionStatus.PastDue) {
            revert SubscriptionNotActive();
        }

        if (_failedAttempts[subscriptionId] < _maxRetryAttempts) {
            revert MaxRetryAttemptsReached();
        }

        sub.status = SubBaseTypes.SubscriptionStatus.Suspended;
        emit SubscriptionSuspended(subscriptionId);
    }

    /**
     * @notice Reactivate a suspended subscription by paying outstanding amount
     * @param subscriptionId The ID of the subscription
     */
    function reactivate(uint256 subscriptionId) external {
        if (subscriptionId >= _subscriptionCount) revert SubscriptionNotFound();

        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];
        SubBaseTypes.Plan storage plan = _plans[sub.planId];

        if (sub.status != SubBaseTypes.SubscriptionStatus.Suspended) {
            revert SubscriptionNotActive();
        }

        // Pay outstanding amount
        require(
            IERC20(_usdc).transferFrom(msg.sender, plan.creator, plan.price),
            "Payment failed"
        );

        // Reset state and reactivate
        _failedAttempts[subscriptionId] = 0;
        _lastChargeAttempt[subscriptionId] = 0;
        _gracePeriodEnd[subscriptionId] = 0;
        sub.status = SubBaseTypes.SubscriptionStatus.Active;
        sub.nextBillingTime = block.timestamp + plan.billingPeriod;

        emit SubscriptionReactivated(subscriptionId);
    }

    /**
     * @notice Set the default grace period for failed payments
     * @param period Grace period in seconds
     */
    function setGracePeriod(uint256 period) external onlyOwner {
        if (period == 0) revert InvalidGracePeriod();
        uint256 oldPeriod = _defaultGracePeriod;
        _defaultGracePeriod = period;
        emit GracePeriodUpdated(oldPeriod, period);
    }

    /**
     * @notice Set the maximum retry attempts for failed charges
     * @param attempts Maximum number of retry attempts
     */
    function setMaxRetryAttempts(uint256 attempts) external onlyOwner {
        if (attempts == 0) revert InvalidMaxRetryAttempts();
        uint256 oldAttempts = _maxRetryAttempts;
        _maxRetryAttempts = attempts;
        emit MaxRetryAttemptsUpdated(oldAttempts, attempts);
    }

    /**
     * @notice Get grace period configuration
     * @return The default grace period in seconds
     */
    function getGracePeriod() external view returns (uint256) {
        return _defaultGracePeriod;
    }

    /**
     * @notice Get max retry attempts configuration
     * @return The maximum retry attempts
     */
    function getMaxRetryAttempts() external view returns (uint256) {
        return _maxRetryAttempts;
    }

    /**
     * @notice Get failed attempts for a subscription
     * @param subscriptionId The subscription ID
     * @return Number of failed charge attempts
     */
    function getFailedAttempts(uint256 subscriptionId) external view returns (uint256) {
        return _failedAttempts[subscriptionId];
    }

    /**
     * @notice Get grace period end time for a subscription
     * @param subscriptionId The subscription ID
     * @return Unix timestamp when grace period ends
     */
    function getGracePeriodEnd(uint256 subscriptionId) external view returns (uint256) {
        return _gracePeriodEnd[subscriptionId];
    }

    /**
     * @dev Handle failed charge attempt
     * @param subscriptionId The subscription ID
     * @param reason Failure reason
     * @return Always returns false
     */
    function _handleFailedCharge(uint256 subscriptionId, string memory reason)
        internal
        returns (bool)
    {
        SubBaseTypes.Subscription storage sub = _subscriptions[subscriptionId];

        _failedAttempts[subscriptionId]++;
        _lastChargeAttempt[subscriptionId] = block.timestamp;

        uint256 attempts = _failedAttempts[subscriptionId];

        // Mark as PastDue on first failure
        if (sub.status == SubBaseTypes.SubscriptionStatus.Active) {
            sub.status = SubBaseTypes.SubscriptionStatus.PastDue;
            _gracePeriodEnd[subscriptionId] = block.timestamp + _defaultGracePeriod;
            emit SubscriptionPastDue(subscriptionId, _gracePeriodEnd[subscriptionId]);
        }

        emit ChargeFailed(subscriptionId, attempts, reason);

        // Auto-suspend if max attempts reached
        if (attempts >= _maxRetryAttempts) {
            sub.status = SubBaseTypes.SubscriptionStatus.Suspended;
            emit SubscriptionSuspended(subscriptionId);
        }

        return false;
    }
}
