// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV2.sol";
import "../src/SubBaseV1.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/errors/SubBaseErrors.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BoundaryConditionsTest is Test {
    SubBaseV2 public subbase;
    MockUSDC public usdc;

    address public creator = address(0x1);
    address public subscriber = address(0x2);

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

        usdc.mint(subscriber, type(uint128).max);
        vm.prank(subscriber);
        usdc.approve(address(subbase), type(uint256).max);
    }

    function testPlan_ZeroPrice_Reverts() public {
        vm.prank(creator);
        vm.expectRevert(bytes4(keccak256("InvalidPrice()")));
        subbase.createPlan(0, 30 days, "Zero Price Plan");
    }

    function testPlan_ZeroBillingPeriod_Reverts() public {
        vm.prank(creator);
        vm.expectRevert(bytes4(keccak256("InvalidBillingPeriod()")));
        subbase.createPlan(10e6, 0, "Zero Period Plan");
    }

    function testPlan_MinimalBillingPeriod() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(1e6, 1 seconds, "1 Second Plan");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.billingPeriod, 1 seconds);
        assertEq(plan.price, 1e6);
    }

    function testPlan_MinimalPrice() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(1, 30 days, "1 Wei Plan");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.price, 1);
    }

    function testPlan_LargeBillingPeriod() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 365 days, "Yearly Plan");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.billingPeriod, 365 days);
    }

    function testPlan_VeryLargeBillingPeriod() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 3650 days, "10 Year Plan");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.billingPeriod, 3650 days);
    }

    function testPlan_MaxPrice() public {
        usdc.mint(creator, type(uint256).max);
        vm.prank(creator);
        usdc.approve(address(subbase), type(uint256).max);

        vm.prank(creator);
        uint256 planId = subbase.createPlan(type(uint128).max, 30 days, "Max Price Plan");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.price, type(uint128).max);
    }

    function testCharge_ExactlyAtBillingTime() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        uint256 nextBilling = sub.nextBillingTime;

        vm.warp(nextBilling);

        assertTrue(subbase.isChargeable(subId));
        bool success = subbase.charge(subId);
        assertTrue(success);
    }

    function testCharge_OneSecondBeforeBillingTime() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        uint256 nextBilling = sub.nextBillingTime;

        vm.warp(nextBilling - 1);

        assertFalse(subbase.isChargeable(subId));
        vm.expectRevert(bytes4(keccak256("NotDueForCharge()")));
        subbase.charge(subId);
    }

    function testCharge_OneSecondAfterBillingTime() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        uint256 nextBilling = sub.nextBillingTime;

        vm.warp(nextBilling + 1);

        assertTrue(subbase.isChargeable(subId));
        bool success = subbase.charge(subId);
        assertTrue(success);
    }

    function testSubscription_MultipleBillingCycles() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 7 days, "Weekly Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        uint256 initialBalance = usdc.balanceOf(creator);

        for (uint256 i = 1; i <= 5; i++) {
            vm.warp(block.timestamp + 7 days);
            bool success = subbase.charge(subId);
            assertTrue(success);

            SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
            assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));
            assertEq(usdc.balanceOf(creator), initialBalance + (10e6 * i));
        }
    }

    function testSubscription_ShortBillingPeriod() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(1e6, 1 minutes, "Minute Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        for (uint256 i = 1; i <= 10; i++) {
            vm.warp(block.timestamp + 1 minutes);
            bool success = subbase.charge(subId);
            assertTrue(success);
        }

        SubBaseTypes.Subscription memory sub = subbase.getSubscription(subId);
        assertEq(uint(sub.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }

    function testPlan_EmptyMetadata() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "");

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.metadata, "");
    }

    function testPlan_LongMetadata() public {
        string memory longMeta = "This is a very long metadata string that contains a lot of information about the plan. "
            "It includes details about features, benefits, terms and conditions, and other important information. "
            "This tests the boundary of metadata storage.";

        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, longMeta);

        SubBaseTypes.Plan memory plan = subbase.getPlan(planId);
        assertEq(plan.metadata, longMeta);
    }

    function testSubscription_ImmediatelyAfterCreation() public {
        vm.prank(creator);
        uint256 planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        vm.prank(subscriber);
        uint256 subId = subbase.subscribe(planId);

        assertFalse(subbase.isChargeable(subId));
        vm.expectRevert(bytes4(keccak256("NotDueForCharge()")));
        subbase.charge(subId);
    }

    function testGetPlan_NonExistentPlan_Reverts() public {
        vm.expectRevert(bytes4(keccak256("PlanNotFound()")));
        subbase.getPlan(999);
    }

    function testGetSubscription_NonExistentSubscription_Reverts() public {
        vm.expectRevert(bytes4(keccak256("SubscriptionNotFound()")));
        subbase.getSubscription(999);
    }
}
