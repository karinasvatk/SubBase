// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SubscriptionManagerUpgradeable implementation = new SubscriptionManagerUpgradeable();

        bytes memory initData = abi.encodeWithSelector(
            SubscriptionManagerUpgradeable.initialize.selector,
            usdcAddress
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        console.log("Implementation deployed at:", address(implementation));
        console.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
