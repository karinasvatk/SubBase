// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract CheckStatusScript is Script {
    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        uint256 totalSubs = manager.subscriptionCount();
        address usdcAddr = address(manager.usdc());

        console.log("Total Subscriptions:", totalSubs);
        console.log("USDC Address:", usdcAddr);
    }
}
