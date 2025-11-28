// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SubBaseV1.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployV1Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SubBaseV1 implementation = new SubBaseV1();

        bytes memory initData = abi.encodeWithSelector(
            SubBaseV1.initialize.selector,
            usdcAddress
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        console.log("SubBaseV1 Implementation:", address(implementation));
        console.log("SubBaseV1 Proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
