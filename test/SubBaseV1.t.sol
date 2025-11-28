// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV1.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SubBaseV1Test is Test {
    SubBaseV1 public subbase;
    MockUSDC public usdc;

    address public creator = address(0x1);
    address public subscriber = address(0x2);

    function setUp() public {
        usdc = new MockUSDC();

        SubBaseV1 implementation = new SubBaseV1();

        bytes memory initData = abi.encodeWithSelector(
            SubBaseV1.initialize.selector,
            address(usdc)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        subbase = SubBaseV1(address(proxy));

        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        usdc.approve(address(subbase), type(uint256).max);
    }

    function testCreatePlan() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Premium Plan");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);

        assertEq(plan.id, 0);
        assertEq(plan.creator, creator);
        assertEq(plan.price, 10e6);
        assertEq(plan.billingPeriod, 30 days);
        assertEq(plan.metadata, "Premium Plan");
        assertTrue(plan.active);
    }

    function testSubscribe() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Premium Plan");

        uint256 balanceBefore = usdc.balanceOf(creator);

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        assertEq(usdc.balanceOf(creator), balanceBefore + 10e6);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(sub.planId, planId);
        assertEq(sub.subscriber, subscriber);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }

    function testCancel() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Premium Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        vm.prank(subscriber);
        subbase.cancel(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));
    }

    function testGetUserSubscriptions() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Premium Plan");

        vm.prank(subscriber);
        subbase.subscribe(planId);

        uint256[] memory subs = subbase.getUserSubscriptions(subscriber);
        assertEq(subs.length, 1);
        assertEq(subs[0], 0);
    }
}
