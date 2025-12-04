// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ChargeModule} from "./ChargeModule.sol";

/**
 * @title AutomationModule
 * @notice Chainlink Automation compatible module for automated subscription charging
 * @dev Implements checkUpkeep and performUpkeep for Chainlink Automation
 */
abstract contract AutomationModule is ChargeModule {
    uint256 private constant BATCH_SIZE = 50; // Maximum subscriptions to process per upkeep

    /**
     * @notice Check if upkeep is needed (Chainlink Automation compatible)
     * @param checkData Optional data for custom checks (unused)
     * @return upkeepNeeded True if there are subscriptions to charge
     * @return performData Encoded subscription IDs to charge
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        checkData; // Silence unused parameter warning

        uint256[] memory readySubscriptions = _getReadySubscriptions(BATCH_SIZE);

        upkeepNeeded = readySubscriptions.length > 0;
        performData = abi.encode(readySubscriptions);
    }

    /**
     * @notice Perform the upkeep (Chainlink Automation compatible)
     * @param performData Encoded subscription IDs to charge
     */
    function performUpkeep(bytes calldata performData) external {
        uint256[] memory subscriptionIds = abi.decode(performData, (uint256[]));

        // Validate and charge each subscription
        for (uint256 i = 0; i < subscriptionIds.length; i++) {
            uint256 subId = subscriptionIds[i];

            // Double-check subscription is still chargeable
            if (isChargeable(subId)) {
                try this.charge(subId) {} catch {
                    // Continue even if individual charge fails
                    continue;
                }
            }
        }
    }

    /**
     * @dev Get subscriptions ready for charging
     * @param limit Maximum number of subscriptions to return
     * @return Array of subscription IDs ready to charge
     */
    function _getReadySubscriptions(uint256 limit)
        internal
        view
        returns (uint256[] memory)
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
        uint256[] memory readyIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            readyIds[i] = tempIds[i];
        }

        return readyIds;
    }
}
