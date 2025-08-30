// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SubscriptionManagerUpgradeable newImplementation = new SubscriptionManagerUpgradeable();

        SubscriptionManagerUpgradeable proxy = SubscriptionManagerUpgradeable(
            proxyAddress
        );
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("New implementation deployed at:", address(newImplementation));
        console.log("Proxy upgraded successfully");

        vm.stopBroadcast();
    }
}
