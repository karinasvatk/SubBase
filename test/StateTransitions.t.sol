// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV2.sol";
import "../src/SubBaseV1.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StateTransitionsTest is Test {
    SubBaseV2 public subbase;
    MockUSDC public usdc;

    address public creator = address(0x1);
    address public subscriber = address(0x2);

    uint256 public planId;
    uint256 public subId;

    event SubscriptionCancelled(uint256 indexed subscriptionId, address indexed subscriber);
    event SubscriptionPastDue(uint256 indexed subscriptionId, uint256 gracePeriodEnd);
    event SubscriptionSuspended(uint256 indexed subscriptionId);
    event SubscriptionReactivated(uint256 indexed subscriptionId);
    event ChargeSuccessful(uint256 indexed subscriptionId, uint256 amount, uint256 nextBillingTime);

    function setUp() public {
        usdc = new MockUSDC();

        SubBaseV1 v1Implementation = new SubBaseV1();
        SubBaseV2 v2Implementation = new SubBaseV2();

        bytes memory initData = abi.encodeWithSelector(
            SubBaseV1.initialize.selector,
            address(usdc)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(v1Implementation),
            initData
        );

        SubBaseV1 v1Proxy = SubBaseV1(address(proxy));
        v1Proxy.upgradeToAndCall(
            address(v2Implementation),
            abi.encodeWithSelector(
                SubBaseV2.initializeV2.selector,
                7 days,
                3
            )
        );

        subbase = SubBaseV2(address(proxy));

        vm.prank(creator);
        planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        usdc.approve(address(subbase), type(uint256).max);

        vm.prank(subscriber);
        subId = subbase.subscribe(planId);
    }

    function testTransition_ActiveToCancelled() public {
        SubBaseTypes.Subscription memory subBefore = subbase.getSubscription(subId);
        assertEq(uint(subBefore.status), uint(SubBaseTypes.SubscriptionStatus.Active));

        vm.prank(subscriber);
        vm.expectEmit(true, true, false, false);
        emit SubscriptionCancelled(subId, subscriber);
        subbase.cancel(subId);

        SubBaseTypes.Subscription memory subAfter = subbase.getSubscription(subId);
        assertEq(uint(subAfter.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));
    }

    function testTransition_CancelledCannotBeCharged() public {
        vm.prank(subscriber);
        subbase.cancel(subId);

        vm.warp(block.timestamp + 30 days);

        assertFalse(subbase.isChargeable(subId));
        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.charge(subId);
    }

    function testTransition_CancelledCannotBeCancelledAgain() public {
        vm.prank(subscriber);
        subbase.cancel(subId);

        vm.prank(subscriber);
        vm.expectRevert(SubBaseV2.AlreadyCancelled.selector);
        subbase.cancel(subId);
    }

    function testTransition_CancelledCannotBeReactivated() public {
        vm.prank(subscriber);
        subbase.cancel(subId);

        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.reactivate(subId);
    }

    function testTransition_ActiveToPastDue() public {
        vm.warp(block.timestamp + 30 days);

        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        vm.expectEmit(true, false, false, false);
        emit SubscriptionPastDue(subId, block.timestamp + 7 days);

        bool success = subbase.charge(subId);
        assertFalse(success);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
        assertEq(subbase.getFailedAttempts(subId), 1);
        assertEq(subbase.getGracePeriodEnd(subId), block.timestamp + 7 days);
    }

    function testTransition_PastDueToActive() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));
        subbase.charge(subId);

        SubBaseTypes.Subscription memory subPastDue = subbase.getSubscription(subId);
        assertEq(uint(subPastDue.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));

        usdc.mint(subscriber, 1000e6);
        bool success = subbase.charge(subId);
        assertTrue(success);

        SubBaseTypes.Subscription memory subActive = subbase.getSubscription(subId);
        assertEq(uint(subActive.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(subbase.getFailedAttempts(subId), 0);
        assertEq(subbase.getGracePeriodEnd(subId), 0);
    }

    function testTransition_PastDueToCancelled() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));
        subbase.charge(subId);

        SubBaseTypes.Subscription memory subPastDue = subbase.getSubscription(subId);
        assertEq(uint(subPastDue.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));

        vm.prank(subscriber);
        subbase.cancel(subId);

        SubBaseTypes.Subscription memory subCancelled = subbase.getSubscription(subId);
        assertEq(uint(subCancelled.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));
    }

    function testTransition_PastDueToSuspended() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);

        vm.expectEmit(true, false, false, false);
        emit SubscriptionSuspended(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));
        assertEq(subbase.getFailedAttempts(subId), 3);
    }

    function testTransition_SuspendedCannotBeCharged() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        assertFalse(subbase.isChargeable(subId));
        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.charge(subId);
    }

    function testTransition_SuspendedToActive() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory subSuspended = subbase.getSubscription(subId);
        assertEq(uint(subSuspended.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        usdc.mint(subscriber, 1000e6);

        vm.prank(subscriber);
        vm.expectEmit(true, false, false, false);
        emit SubscriptionReactivated(subId);
        subbase.reactivate(subId);

        SubBaseTypes.Subscription memory subActive = subbase.getSubscription(subId);
        assertEq(uint(subActive.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(subActive.nextBillingTime, block.timestamp + 30 days);
        assertEq(subbase.getFailedAttempts(subId), 0);
        assertEq(subbase.getGracePeriodEnd(subId), 0);
    }

    function testTransition_SuspendedToCancelled() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory subSuspended = subbase.getSubscription(subId);
        assertEq(uint(subSuspended.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        vm.prank(subscriber);
        subbase.cancel(subId);

        SubBaseTypes.Subscription memory subCancelled = subbase.getSubscription(subId);
        assertEq(uint(subCancelled.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));
    }

    function testTransition_ActiveCannotBeReactivated() public {
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));

        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.reactivate(subId);
    }

    function testTransition_PastDueCannotBeReactivated() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));
        subbase.charge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));

        usdc.mint(subscriber, 1000e6);
        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.reactivate(subId);
    }

    function testTransition_OnlySubscriberCanCancel() public {
        address notSubscriber = address(0x999);

        vm.prank(notSubscriber);
        vm.expectRevert(SubBaseV2.NotSubscriber.selector);
        subbase.cancel(subId);
    }

    function testTransition_FullLifecycle() public {
        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(subId);
        assertEq(uint(sub1.status), uint(SubBaseTypes.SubscriptionStatus.Active));

        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(subId);
        assertEq(uint(sub2.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));

        subbase.retryCharge(subId);
        subbase.retryCharge(subId);
        SubBaseTypes.Subscription memory sub3 = subbase.getSubscription(subId);
        assertEq(uint(sub3.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        subbase.reactivate(subId);
        SubBaseTypes.Subscription memory sub4 = subbase.getSubscription(subId);
        assertEq(uint(sub4.status), uint(SubBaseTypes.SubscriptionStatus.Active));

        vm.prank(subscriber);
        subbase.cancel(subId);
        SubBaseTypes.Subscription memory sub5 = subbase.getSubscription(subId);
        assertEq(uint(sub5.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));
    }
}
