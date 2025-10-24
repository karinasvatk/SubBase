// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract ExecuteDueScript is Script {
    function run() external {
        uint256 executorPrivateKey = vm.envUint("EXECUTOR_PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 limit = vm.envOr("LIMIT", uint256(100));

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        vm.startBroadcast(executorPrivateKey);

        uint256[] memory dueSubs = manager.getDueSubscriptions(limit);

        console.log("Found", dueSubs.length, "due subscriptions");

        if (dueSubs.length > 0) {
            manager.batchExecuteSubscriptions(dueSubs);
            console.log("Executed", dueSubs.length, "subscriptions");
        }

        vm.stopBroadcast();
    }
}
