// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract EventsTest is Test {
    SubscriptionManagerUpgradeable public manager;
    address public usdc = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);

    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed owner,
        address indexed recipient,
        uint256 amount,
        uint256 interval,
        string description
    );

    event SubscriptionActivated(uint256 indexed subscriptionId);

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

    function testSubscriptionCreatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit SubscriptionCreated(0, user, recipient, 100e6, 30 days, "Test");

        vm.prank(user);
        manager.createSubscription(recipient, 100e6, 30 days, "Test");
    }

    function testSubscriptionActivatedEvent() public {
        vm.prank(user);
        uint256 subId = manager.createSubscription(
            recipient,
            100e6,
            30 days,
            "Test"
        );

        vm.expectEmit(true, false, false, false);
        emit SubscriptionActivated(subId);

        vm.prank(user);
        manager.activateSubscription(subId);
    }
}
