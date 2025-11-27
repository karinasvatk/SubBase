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

    uint256[44] private __gap;
}
