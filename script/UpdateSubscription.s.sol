// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract UpdateSubscriptionScript is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 subscriptionId = vm.envUint("SUBSCRIPTION_ID");
        uint256 newAmount = vm.envUint("NEW_AMOUNT");
        uint256 newInterval = vm.envUint("NEW_INTERVAL");

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        vm.startBroadcast(userPrivateKey);

        manager.updateSubscription(subscriptionId, newAmount, newInterval);
        console.log("Updated subscription:", subscriptionId);
        console.log("New amount:", newAmount);
        console.log("New interval:", newInterval);

        vm.stopBroadcast();
    }
}
