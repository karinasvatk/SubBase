// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract CreateSubscriptionScript is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 interval = vm.envUint("INTERVAL");
        string memory description = vm.envString("DESCRIPTION");

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        vm.startBroadcast(userPrivateKey);

        uint256 subId = manager.createSubscription(
            recipient,
            amount,
            interval,
            description
        );

        console.log("Created subscription:", subId);

        vm.stopBroadcast();
    }
}
