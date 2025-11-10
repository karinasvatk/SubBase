// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract IntegrationTest is Test {
    SubscriptionManagerUpgradeable public manager;
    MockUSDC public usdc;

    address public user = address(0x1);
    address public recipient = address(0x2);

    function setUp() public {
        usdc = new MockUSDC();

        SubscriptionManagerUpgradeable implementation = new SubscriptionManagerUpgradeable();

        bytes memory initData = abi.encodeWithSelector(
            SubscriptionManagerUpgradeable.initialize.selector,
            address(usdc)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        manager = SubscriptionManagerUpgradeable(address(proxy));

        usdc.mint(user, 10000e6);
        vm.prank(user);
        usdc.approve(address(manager), type(uint256).max);
    }

    function testFullSubscriptionLifecycle() public {
        vm.prank(user);
        uint256 subId = manager.createSubscription(
            recipient,
            100e6,
            30 days,
            "Monthly"
        );

        vm.prank(user);
        manager.activateSubscription(subId);

        vm.warp(block.timestamp + 30 days);

        manager.executeSubscription(subId);

        assertEq(usdc.balanceOf(recipient), 100e6);
        assertEq(usdc.balanceOf(user), 9900e6);

        assertTrue(manager.isSubscriptionDue(subId) == false);
    }
}
