// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract QueryHelpersTest is Test {
    SubscriptionManagerUpgradeable public manager;
    address public usdc = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public recipient = address(0x4);

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

    function testGetUserSubscriptions() public {
        vm.prank(user1);
        manager.createSubscription(recipient, 100e6, 30 days, "Sub1");

        vm.prank(user1);
        manager.createSubscription(recipient, 200e6, 60 days, "Sub2");

        uint256[] memory subs = manager.getUserSubscriptions(user1);

        assertEq(subs.length, 2);
        assertEq(subs[0], 0);
        assertEq(subs[1], 1);
    }
}
