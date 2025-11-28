// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SubBaseStorage} from "../storage/SubBaseStorage.sol";
import {SubBaseEvents} from "../events/SubBaseEvents.sol";
import {SubBaseErrors} from "../errors/SubBaseErrors.sol";
import {SubBaseTypes} from "../types/SubBaseTypes.sol";

abstract contract PlanModule is SubBaseStorage, SubBaseEvents, SubBaseErrors {
    function createPlan(
        uint256 price,
        uint256 billingPeriod,
        string calldata metadata
    ) external returns (uint256) {
        if (price == 0) revert InvalidPrice();
        if (billingPeriod == 0) revert InvalidBillingPeriod();

        uint256 planId = _planCount++;

        _plans[planId] = SubBaseTypes.Plan({
            id: planId,
            creator: msg.sender,
            price: price,
            billingPeriod: billingPeriod,
            metadata: metadata,
            active: true,
            createdAt: block.timestamp
        });

        emit PlanCreated(planId, msg.sender, price, billingPeriod, metadata);

        return planId;
    }

    function getPlan(uint256 planId)
        external
        view
        returns (SubBaseTypes.Plan memory)
    {
        if (planId >= _planCount) revert PlanNotFound();
        return _plans[planId];
    }
}
