// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SubBaseV1} from "./SubBaseV1.sol";
import {AutomationModule} from "./modules/AutomationModule.sol";

/**
 * @title SubBaseV2
 * @notice V2 upgrade with auto-charge billing engine
 * @dev Adds ChargeModule and AutomationModule capabilities to V1
 */
contract SubBaseV2 is SubBaseV1, AutomationModule {
    function _onlyOwner() private view {
        if (msg.sender != _owner) revert Unauthorized();
    }

    modifier onlyOwner() override(SubBaseV1, ChargeModule) {
        _onlyOwner();
        _;
    }

    /**
     * @notice Initialize V2 with grace period and retry settings
     * @param gracePeriod Grace period in seconds for failed payments
     * @param maxRetries Maximum retry attempts before suspension
     */
    function initializeV2(uint256 gracePeriod, uint256 maxRetries)
        external
        reinitializer(2)
    {
        if (gracePeriod == 0) revert InvalidGracePeriod();
        if (maxRetries == 0) revert InvalidMaxRetryAttempts();

        _defaultGracePeriod = gracePeriod;
        _maxRetryAttempts = maxRetries;
    }

    /**
     * @notice Get the version of the contract
     * @return Version number
     */
    function version() external pure returns (uint256) {
        return 2;
    }
}
