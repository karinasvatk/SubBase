// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubBaseV1.sol";

contract UpgradeV1Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SubBaseV1 newImplementation = new SubBaseV1();

        SubBaseV1 proxy = SubBaseV1(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("New implementation:", address(newImplementation));
        console.log("Proxy upgraded");

        vm.stopBroadcast();
    }
}
