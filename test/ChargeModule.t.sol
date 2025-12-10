// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV2.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/errors/SubBaseErrors.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ChargeModuleTest is Test {
    SubBaseV2 public subbase;
    MockUSDC public usdc;

    address public creator = address(0x1);
    address public subscriber = address(0x2);

    uint256 public planId;
    uint256 public subId;

    event ChargeSuccessful(uint256 indexed subscriptionId, uint256 amount, uint256 nextBillingTime);
    event ChargeFailed(uint256 indexed subscriptionId, uint256 attempt, string reason);
    event SubscriptionPastDue(uint256 indexed subscriptionId, uint256 gracePeriodEnd);
    event SubscriptionSuspended(uint256 indexed subscriptionId);
    event SubscriptionReactivated(uint256 indexed subscriptionId);

    function setUp() public {
        usdc = new MockUSDC();

        // Deploy V1 implementation
        SubBaseV1 v1Implementation = new SubBaseV1();

        // Deploy V2 implementation
        SubBaseV2 v2Implementation = new SubBaseV2();

        // Deploy proxy with V1 initialization
        bytes memory initData = abi.encodeWithSelector(
            SubBaseV1.initialize.selector,
            address(usdc)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(v1Implementation),
            initData
        );

        // Upgrade to V2
        SubBaseV1 v1Proxy = SubBaseV1(address(proxy));
        v1Proxy.upgradeToAndCall(
            address(v2Implementation),
            abi.encodeWithSelector(
                SubBaseV2.initializeV2.selector,
                7 days, // grace period
                3       // max retries
            )
        );

        subbase = SubBaseV2(address(proxy));

        // Setup test subscription
        vm.prank(creator);
        planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        usdc.approve(address(subbase), type(uint256).max);

        vm.prank(subscriber);
        subId = subbase.subscribe(planId);
    }

    function testCharge_Success() public {
        // Fast forward to next billing time
        vm.warp(block.timestamp + 30 days);

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);
        SubBaseTypes.Subscription memory subBefore = subbase.getSubscription(subId);
        uint256 expectedNextBilling = block.timestamp + 30 days;

        vm.expectEmit(true, false, false, true);
        emit ChargeSuccessful(subId, 10e6, expectedNextBilling);

        bool success = subbase.charge(subId);

        assertTrue(success);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + 10e6);

        SubBaseTypes.Subscription memory subAfter = subbase.getSubscription(subId);
        assertEq(subAfter.nextBillingTime, block.timestamp + 30 days);
        assertEq(uint(subAfter.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(subbase.getFailedAttempts(subId), 0);
    }

    function testCharge_NotDueYet() public {
        // Try to charge before billing time
        vm.expectRevert(bytes4(keccak256("NotDueForCharge()")));
        subbase.charge(subId);
    }

    function testCharge_InsufficientBalance() public {
        // Fast forward to next billing time
        vm.warp(block.timestamp + 30 days);

        // Remove subscriber's balance
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        vm.expectEmit(true, false, false, false);
        emit ChargeFailed(subId, 1, "Insufficient balance");

        vm.expectEmit(true, false, false, false);
        emit SubscriptionPastDue(subId, block.timestamp + 7 days);

        bool success = subbase.charge(subId);

        assertFalse(success);
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
        assertEq(subbase.getFailedAttempts(subId), 1);
        assertEq(subbase.getGracePeriodEnd(subId), block.timestamp + 7 days);
    }

    function testCharge_UpdatesNextBillingTime() public {
        vm.warp(block.timestamp + 30 days);

        subbase.charge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        uint256 expectedNextBilling = block.timestamp + 30 days;
        assertEq(sub.nextBillingTime, expectedNextBilling);
    }

    function testBatchCharge_MultipleSubscriptions() public {
        // Create more subscriptions
        address sub2 = address(0x3);
        address sub3 = address(0x4);

        usdc.mint(sub2, 1000e6);
        usdc.mint(sub3, 1000e6);

        vm.prank(sub2);
        usdc.approve(address(subbase), type(uint256).max);
        vm.prank(sub3);
        usdc.approve(address(subbase), type(uint256).max);

        vm.prank(sub2);
        uint256 subId2 = subbase.subscribe(planId);
        vm.prank(sub3);
        uint256 subId3 = subbase.subscribe(planId);

        // Fast forward
        vm.warp(block.timestamp + 30 days);

        uint256[] memory subIds = new uint256[](3);
        subIds[0] = subId;
        subIds[1] = subId2;
        subIds[2] = subId3;

        (uint256 successCount, uint256 failCount) = subbase.batchCharge(subIds);

        assertEq(successCount, 3);
        assertEq(failCount, 0);
    }

    function testBatchCharge_PartialSuccess() public {
        // Create another subscription
        address sub2 = address(0x3);
        usdc.mint(sub2, 1000e6);
        vm.prank(sub2);
        usdc.approve(address(subbase), type(uint256).max);
        vm.prank(sub2);
        uint256 subId2 = subbase.subscribe(planId);

        // Fast forward
        vm.warp(block.timestamp + 30 days);

        // Remove balance from first subscriber
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        uint256[] memory subIds = new uint256[](2);
        subIds[0] = subId;
        subIds[1] = subId2;

        (uint256 successCount, uint256 failCount) = subbase.batchCharge(subIds);

        assertEq(successCount, 1);
        assertEq(failCount, 1);
    }

    function testGetChargeableSubscriptions() public {
        // Create more subscriptions
        address sub2 = address(0x3);
        usdc.mint(sub2, 1000e6);
        vm.prank(sub2);
        usdc.approve(address(subbase), type(uint256).max);
        vm.prank(sub2);
        uint256 subId2 = subbase.subscribe(planId);

        // Fast forward only first subscription
        vm.warp(block.timestamp + 30 days);

        uint256[] memory chargeable = subbase.getChargeableSubscriptions(10);

        assertEq(chargeable.length, 2); // Both subscriptions due
        assertEq(chargeable[0], subId);
        assertEq(chargeable[1], subId2);
    }

    function testRetryCharge_Success() public {
        // Fast forward and fail first charge
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        subbase.charge(subId);

        // Now give subscriber balance back
        usdc.mint(subscriber, 1000e6);

        // Retry should succeed
        bool success = subbase.retryCharge(subId);
        assertTrue(success);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(subbase.getFailedAttempts(subId), 0);
    }

    function testRetryCharge_MaxAttempts() public {
        // Fast forward
        vm.warp(block.timestamp + 30 days);

        // Remove balance
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        // Fail 3 times (max retries)
        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        // Status should be suspended
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        // 4th retry should revert
        vm.expectRevert(bytes4(keccak256("SubscriptionNotActive()")));
        subbase.retryCharge(subId);
    }

    function testMarkSuspended() public {
        // Fast forward and fail charges
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        // Fail 3 times
        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        // Should already be suspended after 3 attempts
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));
    }

    function testGracePeriod_Expiration() public {
        // Fast forward and fail charge
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        subbase.charge(subId);

        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);
        assertEq(gracePeriodEnd, block.timestamp + 7 days);

        // Warp past grace period
        vm.warp(gracePeriodEnd + 1);

        // Subscription should still be PastDue until max retries reached
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
    }

    function testReactivate_PaysOutstanding() public {
        // Fast forward and fail charges until suspended
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        // Fail 3 times to suspend
        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory subBefore = subbase.getSubscription(subId);
        assertEq(uint(subBefore.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        // Reactivate
        usdc.mint(subscriber, 1000e6);
        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        vm.prank(subscriber);
        vm.expectEmit(true, false, false, false);
        emit SubscriptionReactivated(subId);
        subbase.reactivate(subId);

        // Check payment was made
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + 10e6);

        // Check subscription is active
        SubBaseTypes.Subscription memory subAfter = subbase.getSubscription(subId);
        assertEq(uint(subAfter.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(subAfter.nextBillingTime, block.timestamp + 30 days);
        assertEq(subbase.getFailedAttempts(subId), 0);
        assertEq(subbase.getGracePeriodEnd(subId), 0);
    }

    function testSetGracePeriod() public {
        uint256 newGracePeriod = 14 days;
        subbase.setGracePeriod(newGracePeriod);
        assertEq(subbase.getGracePeriod(), newGracePeriod);
    }

    function testSetGracePeriod_ZeroReverts() public {
        vm.expectRevert(bytes4(keccak256("InvalidGracePeriod()")));
        subbase.setGracePeriod(0);
    }

    function testSetMaxRetryAttempts() public {
        uint256 newMaxRetries = 5;
        subbase.setMaxRetryAttempts(newMaxRetries);
        assertEq(subbase.getMaxRetryAttempts(), newMaxRetries);
    }

    function testSetMaxRetryAttempts_ZeroReverts() public {
        vm.expectRevert(bytes4(keccak256("InvalidMaxRetryAttempts()")));
        subbase.setMaxRetryAttempts(0);
    }

    function testIsChargeable_Active() public {
        // Not chargeable before due time
        assertFalse(subbase.isChargeable(subId));

        // Chargeable after due time
        vm.warp(block.timestamp + 30 days);
        assertTrue(subbase.isChargeable(subId));
    }

    function testIsChargeable_PastDue() public {
        // Make PastDue
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));
        subbase.charge(subId);

        // Should be chargeable while in PastDue
        assertTrue(subbase.isChargeable(subId));
    }

    function testIsChargeable_Suspended() public {
        // Suspend subscription
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        // Should not be chargeable when suspended
        assertFalse(subbase.isChargeable(subId));
    }

    function testIsChargeable_Cancelled() public {
        vm.prank(subscriber);
        subbase.cancel(subId);

        vm.warp(block.timestamp + 30 days);

        // Should not be chargeable when cancelled
        assertFalse(subbase.isChargeable(subId));
    }

    function testCharge_ReactivatesPastDue() public {
        // Make PastDue
        vm.warp(block.timestamp + 30 days);
        usdc.burn(subscriber, usdc.balanceOf(subscriber));
        subbase.charge(subId);

        SubBaseTypes.Subscription memory subBefore = subbase.getSubscription(subId);
        assertEq(uint(subBefore.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));

        // Give balance back and charge
        usdc.mint(subscriber, 1000e6);
        subbase.charge(subId);

        // Should be Active again
        SubBaseTypes.Subscription memory subAfter = subbase.getSubscription(subId);
        assertEq(uint(subAfter.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }
}
