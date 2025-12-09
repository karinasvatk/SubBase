// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV2.sol";
import "../src/SubBaseV1.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GracePeriodEdgeCasesTest is Test {
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

    function testGracePeriod_SetOnFirstFailure() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 failureTime = block.timestamp;
        subbase.charge(subId);

        assertEq(subbase.getGracePeriodEnd(subId), failureTime + 7 days);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
    }

    function testGracePeriod_ExactExpiration() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);

        vm.warp(gracePeriodEnd);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
    }

    function testGracePeriod_OneSecondBeforeExpiration() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);

        vm.warp(gracePeriodEnd - 1);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
    }

    function testGracePeriod_OneSecondAfterExpiration() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);

        vm.warp(gracePeriodEnd + 1);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));
    }

    function testGracePeriod_MultipleFailuresDuringGracePeriod() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 firstFailureTime = block.timestamp;
        subbase.charge(subId);
        uint256 initialGracePeriodEnd = subbase.getGracePeriodEnd(subId);
        assertEq(initialGracePeriodEnd, firstFailureTime + 7 days);

        vm.warp(block.timestamp + 2 days);
        subbase.retryCharge(subId);
        assertEq(subbase.getGracePeriodEnd(subId), initialGracePeriodEnd);

        vm.warp(block.timestamp + 2 days);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));
    }

    function testGracePeriod_ClearedOnSuccessfulCharge() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        assertGt(subbase.getGracePeriodEnd(subId), 0);

        usdc.mint(subscriber, 1000e6);
        subbase.charge(subId);

        assertEq(subbase.getGracePeriodEnd(subId), 0);
        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }

    function testGracePeriod_ClearedOnReactivation() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        subbase.retryCharge(subId);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory subSuspended = subbase.getSubscription(subId);
        assertEq(uint(subSuspended.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));
        assertGt(subbase.getGracePeriodEnd(subId), 0);

        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        subbase.reactivate(subId);

        assertEq(subbase.getGracePeriodEnd(subId), 0);
        SubBaseTypes.Subscription memory subActive = subbase.getSubscription(subId);
        assertEq(uint(subActive.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }

    function testGracePeriod_UpdateDefaultGracePeriod() public {
        uint256 oldGracePeriod = subbase.getGracePeriod();
        assertEq(oldGracePeriod, 7 days);

        subbase.setGracePeriod(14 days);
        assertEq(subbase.getGracePeriod(), 14 days);

        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 failureTime = block.timestamp;
        subbase.charge(subId);

        assertEq(subbase.getGracePeriodEnd(subId), failureTime + 14 days);
    }

    function testGracePeriod_ExistingSubscriptionsNotAffectedByConfigChange() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 failureTime = block.timestamp;
        subbase.charge(subId);
        uint256 originalGracePeriodEnd = subbase.getGracePeriodEnd(subId);
        assertEq(originalGracePeriodEnd, failureTime + 7 days);

        subbase.setGracePeriod(14 days);

        assertEq(subbase.getGracePeriodEnd(subId), originalGracePeriodEnd);
    }

    function testGracePeriod_RetryWithinGracePeriod() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);

        vm.warp(block.timestamp + 3 days);
        assertTrue(block.timestamp < gracePeriodEnd);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.PastDue));

        assertTrue(subbase.isChargeable(subId));
    }

    function testGracePeriod_MaxRetriesReachedBeforeExpiration() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 failureTime = block.timestamp;
        subbase.charge(subId);
        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);
        assertEq(gracePeriodEnd, failureTime + 7 days);

        vm.warp(block.timestamp + 1 days);
        subbase.retryCharge(subId);

        vm.warp(block.timestamp + 1 days);
        subbase.retryCharge(subId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        assertTrue(block.timestamp < gracePeriodEnd);
    }

    function testGracePeriod_SuccessfulRetryResetsGracePeriod() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        subbase.charge(subId);
        assertEq(subbase.getFailedAttempts(subId), 1);
        uint256 gracePeriodEnd = subbase.getGracePeriodEnd(subId);
        assertGt(gracePeriodEnd, 0);

        usdc.mint(subscriber, 1000e6);
        subbase.retryCharge(subId);

        assertEq(subbase.getFailedAttempts(subId), 0);
        assertEq(subbase.getGracePeriodEnd(subId), 0);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }

    function testGracePeriod_MinimalGracePeriod() public {
        subbase.setGracePeriod(1);

        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 failureTime = block.timestamp;
        subbase.charge(subId);

        assertEq(subbase.getGracePeriodEnd(subId), failureTime + 1);
    }

    function testGracePeriod_LargeGracePeriod() public {
        subbase.setGracePeriod(365 days);

        vm.warp(block.timestamp + 30 days);
        vm.prank(subscriber);
        usdc.transfer(address(0x999), usdc.balanceOf(subscriber));

        uint256 failureTime = block.timestamp;
        subbase.charge(subId);

        assertEq(subbase.getGracePeriodEnd(subId), failureTime + 365 days);
    }
}
