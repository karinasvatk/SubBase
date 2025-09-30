// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library SubscriptionHelpers {
    function calculateNextChargeTime(uint256 currentTime, uint256 interval)
        internal
        pure
        returns (uint256)
    {
        return currentTime + interval;
    }

    function isIntervalValid(uint256 interval)
        internal
        pure
        returns (bool)
    {
        return interval >= 1 days && interval <= 365 days;
    }

    function isAmountValid(uint256 amount)
        internal
        pure
        returns (bool)
    {
        return amount > 0 && amount <= 1000000e6;
    }
}
