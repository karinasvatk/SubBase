// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC20 is Test {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        return true;
    }
}

contract SubscriptionManagerTest is Test {
    SubscriptionManagerUpgradeable public manager;
    MockERC20 public usdc;

    address public owner = address(1);
    address public subscriber = address(2);
    address public recipient = address(3);

    function setUp() public {
        usdc = new MockERC20();

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

        usdc.mint(subscriber, 1000e6);
        vm.prank(subscriber);
        usdc.approve(address(manager), type(uint256).max);
    }

    function testCreateSubscription() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        (
            address subOwner,
            address subRecipient,
            uint256 amount,
            uint256 interval,
            ,

        ) = manager.subscriptions(subId);

        assertEq(subOwner, subscriber);
        assertEq(subRecipient, recipient);
        assertEq(amount, 100e6);
        assertEq(interval, 30 days);
    }

    function testActivateSubscription() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        vm.prank(subscriber);
        manager.activateSubscription(subId);

        (, , , , , SubscriptionManagerUpgradeable.SubscriptionStatus status) = manager
            .subscriptions(subId);

        assertEq(
            uint256(status),
            uint256(SubscriptionManagerUpgradeable.SubscriptionStatus.Active)
        );
    }

    function testPauseSubscription() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        vm.prank(subscriber);
        manager.activateSubscription(subId);

        vm.prank(subscriber);
        manager.pauseSubscription(subId);

        (, , , , , SubscriptionManagerUpgradeable.SubscriptionStatus status) = manager
            .subscriptions(subId);

        assertEq(
            uint256(status),
            uint256(SubscriptionManagerUpgradeable.SubscriptionStatus.Paused)
        );
    }

    function testCancelSubscription() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        vm.prank(subscriber);
        manager.cancelSubscription(subId);

        (, , , , , SubscriptionManagerUpgradeable.SubscriptionStatus status) = manager
            .subscriptions(subId);

        assertEq(
            uint256(status),
            uint256(SubscriptionManagerUpgradeable.SubscriptionStatus.Cancelled)
        );
    }

    function testExecuteSubscription() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        vm.prank(subscriber);
        manager.activateSubscription(subId);

        vm.warp(block.timestamp + 30 days);

        manager.executeSubscription(subId);

        assertEq(usdc.balanceOf(recipient), 100e6);
        assertEq(usdc.balanceOf(subscriber), 900e6);
    }

    function testCannotExecuteInactiveSubscription() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        vm.warp(block.timestamp + 30 days);

        vm.expectRevert("Not active");
        manager.executeSubscription(subId);
    }

    function testCannotExecuteTooEarly() public {
        vm.prank(subscriber);
        uint256 subId = manager.createSubscription(recipient, 100e6, 30 days);

        vm.prank(subscriber);
        manager.activateSubscription(subId);

        vm.expectRevert("Too early to charge");
        manager.executeSubscription(subId);
    }
}
