// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library SubscriptionTypes {
    enum Status {
        Created,
        Active,
        Paused,
        Cancelled,
        Executed
    }

    struct Data {
        address owner;
        address recipient;
        uint256 amount;
        uint256 interval;
        uint256 nextChargeTime;
        Status status;
        string description;
        uint256 createdAt;
        uint256 totalCharged;
    }
}
