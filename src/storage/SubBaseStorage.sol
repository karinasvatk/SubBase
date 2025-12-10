// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SubBaseTypes} from "../types/SubBaseTypes.sol";

/**
 * @title SubBaseStorage
 * @notice Storage layout for SubBase protocol
 * @dev This contract defines the storage layout used by all SubBase modules.
 *      Storage slots are carefully managed to ensure upgrade safety.
 *
 * Storage Layout (V1):
 * - Slot 0: _plans mapping
 * - Slot 1: _subscriptions mapping
 * - Slot 2: _userSubscriptions mapping
 * - Slot 3: _planCount
 * - Slot 4: _subscriptionCount
 * - Slot 5: _usdc
 *
 * Storage Layout (V2 additions):
 * - Slot 6: _failedAttempts mapping
 * - Slot 7: _lastChargeAttempt mapping
 * - Slot 8: _gracePeriodEnd mapping
 * - Slot 9: _defaultGracePeriod
 * - Slot 10: _maxRetryAttempts
 * - Slots 11-49: __gap (39 slots reserved for future upgrades)
 *
 * Total storage slots used: 11
 * Reserved gap slots: 39
 * Total allocated: 50 slots
 */
abstract contract SubBaseStorage {
    /**
     * @dev Mapping of plan ID to Plan struct
     * @notice Stores all subscription plans created in the protocol
     * Storage Slot: 0
     */
    mapping(uint256 => SubBaseTypes.Plan) internal _plans;

    /**
     * @dev Mapping of subscription ID to Subscription struct
     * @notice Stores all active and historical subscriptions
     * Storage Slot: 1
     */
    mapping(uint256 => SubBaseTypes.Subscription) internal _subscriptions;

    /**
     * @dev Mapping of user address to array of subscription IDs
     * @notice Allows querying all subscriptions for a given user
     * Storage Slot: 2
     */
    mapping(address => uint256[]) internal _userSubscriptions;

    /**
     * @dev Total number of plans created
     * @notice Monotonically increasing counter, used as plan ID generator
     * Storage Slot: 3
     */
    uint256 internal _planCount;

    /**
     * @dev Total number of subscriptions created
     * @notice Monotonically increasing counter, used as subscription ID generator
     * Storage Slot: 4
     */
    uint256 internal _subscriptionCount;

    /**
     * @dev Address of the USDC token contract
     * @notice Payment token for all subscriptions (6 decimals)
     * Storage Slot: 5
     */
    address internal _usdc;

    /**
     * @dev V2 Storage Additions
     * @notice Added in V2 upgrade to support grace periods and retry logic
     */

    /**
     * @dev Mapping of subscription ID to failed charge attempts count
     * @notice Tracks how many times a charge has failed for a subscription
     * @notice Reset to 0 on successful charge or reactivation
     * Storage Slot: 6
     */
    mapping(uint256 => uint256) internal _failedAttempts;

    /**
     * @dev Mapping of subscription ID to last charge attempt timestamp
     * @notice Records when the last charge attempt was made
     * @notice Used for retry logic and analytics
     * Storage Slot: 7
     */
    mapping(uint256 => uint256) internal _lastChargeAttempt;

    /**
     * @dev Mapping of subscription ID to grace period end timestamp
     * @notice Set when subscription enters PastDue status
     * @notice Cleared when subscription becomes Active or is reactivated
     * Storage Slot: 8
     */
    mapping(uint256 => uint256) internal _gracePeriodEnd;

    /**
     * @dev Default grace period duration in seconds
     * @notice Applied to new PastDue subscriptions (default: 7 days)
     * @notice Can be updated by contract owner
     * Storage Slot: 9
     */
    uint256 internal _defaultGracePeriod;

    /**
     * @dev Maximum number of retry attempts before suspension
     * @notice After this many failed attempts, subscription is auto-suspended (default: 3)
     * @notice Can be updated by contract owner
     * Storage Slot: 10
     */
    uint256 internal _maxRetryAttempts;

    /**
     * @dev Storage gap for future upgrades
     * @notice Reserved slots to allow adding new state variables in future upgrades
     * @notice DO NOT remove or modify this gap without careful analysis
     * @notice Current gap: 39 slots (total allocated: 50 slots)
     * Storage Slots: 11-49
     */
    uint256[39] private __gap;
}
