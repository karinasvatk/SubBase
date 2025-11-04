// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract CancelSubscriptionScript is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 subscriptionId = vm.envUint("SUBSCRIPTION_ID");

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        vm.startBroadcast(userPrivateKey);

        manager.cancelSubscription(subscriptionId);
        console.log("Cancelled subscription:", subscriptionId);

        vm.stopBroadcast();
    }
}
