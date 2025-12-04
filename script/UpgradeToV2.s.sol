// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubBaseV1.sol";
import "../src/SubBaseV2.sol";

contract UpgradeToV2Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        // Default configuration values
        uint256 gracePeriod = vm.envOr("GRACE_PERIOD", uint256(7 days));
        uint256 maxRetries = vm.envOr("MAX_RETRIES", uint256(3));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy V2 implementation
        SubBaseV2 v2Implementation = new SubBaseV2();

        console.log("V2 Implementation deployed:", address(v2Implementation));

        // Upgrade proxy to V2 and initialize
        SubBaseV1 proxy = SubBaseV1(proxyAddress);
        proxy.upgradeToAndCall(
            address(v2Implementation),
            abi.encodeWithSelector(
                SubBaseV2.initializeV2.selector,
                gracePeriod,
                maxRetries
            )
        );

        console.log("Proxy upgraded to V2");
        console.log("Grace Period:", gracePeriod);
        console.log("Max Retries:", maxRetries);

        // Verify upgrade
        SubBaseV2 v2Proxy = SubBaseV2(proxyAddress);
        console.log("Version:", v2Proxy.version());
        console.log("Grace Period configured:", v2Proxy.getGracePeriod());
        console.log("Max Retry Attempts configured:", v2Proxy.getMaxRetryAttempts());

        vm.stopBroadcast();
    }
}
