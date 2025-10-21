// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract GetSubscriptionScript is Script {
    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 subscriptionId = vm.envUint("SUBSCRIPTION_ID");

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        (
            address owner,
            address recipient,
            uint256 amount,
            uint256 interval,
            uint256 nextChargeTime,

        ) = manager.getSubscription(subscriptionId);

        console.log("Owner:", owner);
        console.log("Recipient:", recipient);
        console.log("Amount:", amount);
        console.log("Interval:", interval);
        console.log("Next Charge:", nextChargeTime);
    }
}
