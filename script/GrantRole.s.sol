// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";

contract GrantRoleScript is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address newExecutor = vm.envAddress("NEW_EXECUTOR");

        SubscriptionManagerUpgradeable manager = SubscriptionManagerUpgradeable(
            proxyAddress
        );

        vm.startBroadcast(adminPrivateKey);

        bytes32 executorRole = manager.EXECUTOR_ROLE();
        manager.grantRole(executorRole, newExecutor);

        console.log("Granted EXECUTOR_ROLE to:", newExecutor);

        vm.stopBroadcast();
    }
}
