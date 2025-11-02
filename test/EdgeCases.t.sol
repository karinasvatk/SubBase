// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract EdgeCasesTest is Test {
    SubscriptionManagerUpgradeable public manager;
    address public usdc = address(0x1);
    address public user = address(0x2);

    function setUp() public {
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

    function testCannotCreateWithZeroRecipient() public {
        vm.prank(user);
        vm.expectRevert();
        manager.createSubscription(address(0), 100e6, 30 days, "Test");
    }

    function testCannotCreateWithZeroAmount() public {
        vm.prank(user);
        vm.expectRevert();
        manager.createSubscription(address(0x3), 0, 30 days, "Test");
    }

    function testCannotCreateWithZeroInterval() public {
        vm.prank(user);
        vm.expectRevert();
        manager.createSubscription(address(0x3), 100e6, 0, "Test");
    }
}
