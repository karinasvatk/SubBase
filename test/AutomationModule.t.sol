// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubBaseV2.sol";
import "../src/types/SubBaseTypes.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AutomationModuleTest is Test {
    SubBaseV2 public subbase;
    MockUSDC public usdc;

    address public creator = address(0x1);
    address public subscriber1 = address(0x2);
    address public subscriber2 = address(0x3);
    address public subscriber3 = address(0x4);

    uint256 public planId;

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

        // Setup test plan
        vm.prank(creator);
        planId = subbase.createPlan(10e6, 30 days, "Test Plan");

        // Setup subscribers
        _setupSubscriber(subscriber1);
        _setupSubscriber(subscriber2);
        _setupSubscriber(subscriber3);
    }

    function _setupSubscriber(address subscriber) internal {
        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        usdc.approve(address(subbase), type(uint256).max);
        vm.prank(subscriber);
        subbase.subscribe(planId);
    }

    function testCheckUpkeep_NoSubscriptionsDue() public {
        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");

        assertFalse(upkeepNeeded);

        uint256[] memory subIds = abi.decode(performData, (uint256[]));
        assertEq(subIds.length, 0);
    }

    function testCheckUpkeep_ReturnsReadySubscriptions() public {
        // Fast forward to make all subscriptions due
        vm.warp(block.timestamp + 30 days);

        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");

        assertTrue(upkeepNeeded);

        uint256[] memory subIds = abi.decode(performData, (uint256[]));
        assertEq(subIds.length, 3); // All 3 subscriptions
        assertEq(subIds[0], 0);
        assertEq(subIds[1], 1);
        assertEq(subIds[2], 2);
    }

    function testCheckUpkeep_PartiallydueSubscriptions() public {
        // Fast forward only 30 days (first subscription due)
        vm.warp(block.timestamp + 30 days);

        // Cancel one subscription
        vm.prank(subscriber2);
        subbase.cancel(1);

        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");

        assertTrue(upkeepNeeded);

        uint256[] memory subIds = abi.decode(performData, (uint256[]));
        assertEq(subIds.length, 2); // Only 2 active subscriptions due
    }

    function testPerformUpkeep_ChargesAll() public {
        // Fast forward
        vm.warp(block.timestamp + 30 days);

        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded);

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        // Perform upkeep
        subbase.performUpkeep(performData);

        // All charges should succeed
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + (10e6 * 3));

        // All subscriptions should have updated billing times
        SubBaseTypes.Subscription memory sub0 = subbase.getSubscription(0);
        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(1);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(2);

        assertEq(sub0.nextBillingTime, 5184001);  // 2592001 + 30 days
        assertEq(sub1.nextBillingTime, 5184001);
        assertEq(sub2.nextBillingTime, 5184001);
    }

    function testPerformUpkeep_PartialSuccess() public {
        // Fast forward
        vm.warp(block.timestamp + 30 days);

        // Remove balance from one subscriber
        usdc.burn(subscriber2, usdc.balanceOf(subscriber2));

        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded);

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        // Perform upkeep
        subbase.performUpkeep(performData);

        // Two charges should succeed, one should fail
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + (10e6 * 2));

        // Check statuses
        SubBaseTypes.Subscription memory sub0 = subbase.getSubscription(0);
        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(1);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(2);

        assertEq(uint(sub0.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(uint(sub1.status), uint(SubBaseTypes.SubscriptionStatus.PastDue)); // Failed
        assertEq(uint(sub2.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }

    function testPerformUpkeep_SkipsNonChargeableSubscriptions() public {
        // Fast forward
        vm.warp(block.timestamp + 30 days);

        // Cancel one subscription
        vm.prank(subscriber2);
        subbase.cancel(1);

        // Create perform data with all subscription IDs including cancelled
        uint256[] memory allSubIds = new uint256[](3);
        allSubIds[0] = 0;
        allSubIds[1] = 1; // Cancelled
        allSubIds[2] = 2;
        bytes memory performData = abi.encode(allSubIds);

        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        // Perform upkeep
        subbase.performUpkeep(performData);

        // Only 2 charges should succeed (cancelled one skipped)
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + (10e6 * 2));

        // Cancelled subscription should remain cancelled
        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(1);
        assertEq(uint(sub1.status), uint(SubBaseTypes.SubscriptionStatus.Cancelled));
    }

    function testAutomationWorkflow_MultipleCycles() public {
        uint256 creatorBalanceBefore = usdc.balanceOf(creator);
        uint256 startTime = block.timestamp;

        // Cycle 1: First billing
        vm.warp(startTime + 30 days);
        (bool upkeepNeeded1, bytes memory performData1) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded1);
        subbase.performUpkeep(performData1);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + (10e6 * 3));

        // Cycle 2: Second billing
        vm.warp(startTime + 60 days);
        (bool upkeepNeeded2, bytes memory performData2) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded2);
        subbase.performUpkeep(performData2);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + (10e6 * 6));

        // Cycle 3: Third billing
        vm.warp(startTime + 90 days);
        (bool upkeepNeeded3, bytes memory performData3) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded3);
        subbase.performUpkeep(performData3);
        assertEq(usdc.balanceOf(creator), creatorBalanceBefore + (10e6 * 9));
    }

    function testCheckUpkeep_IgnoresSuspendedSubscriptions() public {
        // Fast forward
        vm.warp(block.timestamp + 30 days);

        // Remove balance from subscriber2 and fail charges to suspend
        usdc.burn(subscriber2, usdc.balanceOf(subscriber2));

        // Fail charges 3 times to suspend
        subbase.charge(1);
        subbase.retryCharge(1);
        subbase.retryCharge(1);

        // Check that subscription is suspended
        SubBaseTypes.Subscription memory sub1 = subbase.getSubscription(1);
        assertEq(uint(sub1.status), uint(SubBaseTypes.SubscriptionStatus.Suspended));

        // checkUpkeep should only return 2 subscriptions (not the suspended one)
        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded);

        uint256[] memory subIds = abi.decode(performData, (uint256[]));
        assertEq(subIds.length, 2);
        assertEq(subIds[0], 0);
        assertEq(subIds[1], 2);
    }

    function testPerformUpkeep_HandlesEmptyArray() public {
        uint256[] memory emptyArray = new uint256[](0);
        bytes memory performData = abi.encode(emptyArray);

        // Should not revert
        subbase.performUpkeep(performData);
    }

    function testPerformUpkeep_ContinuesOnIndividualFailure() public {
        // Fast forward
        vm.warp(block.timestamp + 30 days);

        // Remove balance from middle subscriber
        usdc.burn(subscriber2, usdc.balanceOf(subscriber2));

        (bool upkeepNeeded, bytes memory performData) = subbase.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // Should process all 3 even though middle one fails
        subbase.performUpkeep(performData);

        // Verify first and third succeeded
        SubBaseTypes.Subscription memory sub0 = subbase.getSubscription(0);
        SubBaseTypes.Subscription memory sub2 = subbase.getSubscription(2);

        assertEq(uint(sub0.status), uint(SubBaseTypes.SubscriptionStatus.Active));
        assertEq(uint(sub2.status), uint(SubBaseTypes.SubscriptionStatus.Active));
    }
}
