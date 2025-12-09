// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV2.sol";
import "../src/SubBaseV1.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract IdempotencyReplayTest is Test {
    SubBaseV2 public subbase;
    MockUSDC public usdc;

    address public creator = address(0x1);
    address public subscriber = address(0x2);

    uint256 public planId;
    uint256 public subId;

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

    function testIdempotency_CannotChargeBeforeNextBillingTime() public {
        vm.warp(block.timestamp + 30 days);

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);
        bool success1 = subbase.charge(subId);
        assertTrue(success1);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + 10e6);

        uint256 creatorBalanceAfter = usdc.balanceOf(creator);
        vm.expectRevert(SubBaseV2.NotDueForCharge.selector);
        subbase.charge(subId);

        assertEq(usdc.balanceOf(creator), creatorBalanceAfter);
    }

    function testIdempotency_CannotChargeImmediatelyAfterSuccessfulCharge() public {
        vm.warp(block.timestamp + 30 days);

        subbase.charge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(sub.nextBillingTime, block.timestamp + 30 days);

        vm.expectRevert(SubBaseV2.NotDueForCharge.selector);
        subbase.charge(subId);
    }

    function testIdempotency_NextBillingTimeUpdatedCorrectly() public {
        vm.warp(block.timestamp + 30 days);
        uint256 firstBillingTime = block.timestamp;

        subbase.charge(subId);
        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(subId);
        assertEq(sub1.nextBillingTime, firstBillingTime + 30 days);

        vm.warp(firstBillingTime + 30 days);
        subbase.charge(subId);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(subId);
        assertEq(sub2.nextBillingTime, firstBillingTime + 60 days);

        vm.warp(firstBillingTime + 60 days);
        subbase.charge(subId);
        SubBaseTypes.Subscription memory sub3 = subbase.getSubscription(subId);
        assertEq(sub3.nextBillingTime, firstBillingTime + 90 days);
    }

    function testIdempotency_MultipleSubscriptionsToSamePlan() public {
        address subscriber2 = address(0x3);
        usdc.mint(subscriber2, 1000e6);
        vm.prank(subscriber2);
        usdc.approve(address(subbase), type(uint256).max);

        vm.prank(subscriber);
        uint256 subId1 = subbase.subscribe(planId);

        vm.prank(subscriber2);
        uint256 subId2 = subbase.subscribe(planId);

        assertEq(subId1, 0);
        assertEq(subId2, 1);

        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(subId1);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(subId2);

        assertEq(sub1.subscriber, subscriber);
        assertEq(sub2.subscriber, subscriber2);
        assertEq(sub1.planId, planId);
        assertEq(sub2.planId, planId);
    }

    function testIdempotency_SameUserCanSubscribeToSamePlanMultipleTimes() public {
        vm.prank(subscriber);
        uint256 subId1 = subbase.subscribe(planId);

        vm.prank(subscriber);
        uint256 subId2 = subbase.subscribe(planId);

        assertEq(subId1, 0);
        assertEq(subId2, 1);

        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(subId1);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(subId2);

        assertEq(sub1.subscriber, subscriber);
        assertEq(sub2.subscriber, subscriber);
        assertEq(sub1.planId, planId);
        assertEq(sub2.planId, planId);
    }

    function testIdempotency_ConcurrentChargeAttempts() public {
        vm.warp(block.timestamp + 30 days);

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        bool success1 = subbase.charge(subId);
        assertTrue(success1);

        bool success2;
        try subbase.charge(subId) returns (bool result) {
            success2 = result;
        } catch {
            success2 = false;
        }

        assertFalse(success2);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + 10e6);
    }

    function testIdempotency_BatchChargeDoesNotDoubleBill() public {
        vm.warp(block.timestamp + 30 days);

        uint256[] memory subIds = new uint256[](3);
        subIds[0] = subId;
        subIds[1] = subId;
        subIds[2] = subId;

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        (uint256 successCount, uint256 failCount) = subbase.batchCharge(subIds);

        assertEq(successCount, 1);
        assertEq(failCount, 2);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + 10e6);
    }

    function testReplay_CannotRetryActiveSubscription() public {
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));

        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.retryCharge(subId);
    }

    function testReplay_CannotRetrySuspendedSubscription() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.retryCharge(subId);
    }

    function testReplay_CannotRetryCancelledSubscription() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);

        vm.prank(subscriber);
        subbase.cancel(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));

        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.retryCharge(subId);
    }

    function testReplay_MaxRetryEnforced() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        assertEq(subbase.getFailedAttempts(subId), 1);

        subbase.retryCharge(subId);
        assertEq(subbase.getFailedAttempts(subId), 2);

        subbase.retryCharge(subId);
        assertEq(subbase.getFailedAttempts(subId), 3);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        vm.expectRevert(SubBaseV2.SubscriptionNotActive.selector);
        subbase.retryCharge(subId);
    }

    function testIdempotency_ChargeOnlyWhenDue() public {
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        uint256 nextBilling = sub.nextBillingTime;

        for (uint256 i = 0; i < 30 days - 1; i += 1 days) {
            vm.warp(block.timestamp + 1 days);

            if (block.timestamp < nextBilling) {
                vm.expectRevert(SubBaseV2.NotDueForCharge.selector);
                subbase.charge(subId);
            }
        }

        vm.warp(nextBilling);
        bool success = subbase.charge(subId);
        assertTrue(success);
    }

    function testIdempotency_FailedAttemptsPersistAcrossRetries() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        assertEq(subbase.getFailedAttempts(subId), 1);

        subbase.retryCharge(subId);
        assertEq(subbase.getFailedAttempts(subId), 2);

        usdc.mint(subscriber, 1000e6);
        subbase.retryCharge(subId);
        assertEq(subbase.getFailedAttempts(subId), 0);
    }
}
