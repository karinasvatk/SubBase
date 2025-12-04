// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SubBaseTypes} from "../types/SubBaseTypes.sol";

abstract contract SubBaseStorage {
    mapping(uint256 => SubBaseTypes.Plan) internal _plans;
    mapping(uint256 => SubBaseTypes.Subscription) internal _subscriptions;
    mapping(address => uint256[]) internal _userSubscriptions;

    uint256 internal _planCount;
    uint256 internal _subscriptionCount;

    address internal _usdc;

    // V2 storage additions
    mapping(uint256 => uint256) internal _failedAttempts;
    mapping(uint256 => uint256) internal _lastChargeAttempt;
    mapping(uint256 => uint256) internal _gracePeriodEnd;
    uint256 internal _defaultGracePeriod;
    uint256 internal _maxRetryAttempts;

    uint256[39] private __gap;
}
