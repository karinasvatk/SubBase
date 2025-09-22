// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeTest is Test {
    SubscriptionManagerUpgradeable public manager;
    address public usdc = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address public admin = address(1);

    function setUp() public {
        vm.prank(admin);
        SubscriptionManagerUpgradeable implementation = new SubscriptionManagerUpgradeable();

        bytes memory initData = abi.encodeWithSelector(
            SubscriptionManagerUpgradeable.initialize.selector,
            usdc
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        manager = SubscriptionManagerUpgradeable(address(proxy));
    }

    function testCanUpgrade() public {
        vm.prank(admin);
        SubscriptionManagerUpgradeable newImpl = new SubscriptionManagerUpgradeable();

        vm.prank(admin);
        manager.upgradeToAndCall(address(newImpl), "");

        assertTrue(true);
    }
}
