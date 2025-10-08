// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockToken {
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
        require(allowance[from][msg.sender] >= amount);
        require(balanceOf[from] >= amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract BatchExecutionTest is Test {
    SubscriptionManagerUpgradeable public manager;
    MockToken public usdc;

    address public owner = address(1);
    address public subscriber1 = address(2);
    address public subscriber2 = address(3);
    address public recipient = address(4);

    function setUp() public {
        usdc = new MockToken();

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

        usdc.mint(subscriber1, 1000e6);
        usdc.mint(subscriber2, 1000e6);

        vm.prank(subscriber1);
        usdc.approve(address(manager), type(uint256).max);

        vm.prank(subscriber2);
        usdc.approve(address(manager), type(uint256).max);
    }

    function testBatchExecution() public {
        vm.prank(subscriber1);
        uint256 sub1 = manager.createSubscription(
            recipient,
            100e6,
            30 days,
            "Sub1"
        );

        vm.prank(subscriber2);
        uint256 sub2 = manager.createSubscription(
            recipient,
            200e6,
            30 days,
            "Sub2"
        );

        vm.prank(subscriber1);
        manager.activateSubscription(sub1);

        vm.prank(subscriber2);
        manager.activateSubscription(sub2);

        vm.warp(block.timestamp + 30 days);

        uint256[] memory subs = new uint256[](2);
        subs[0] = sub1;
        subs[1] = sub2;

        manager.batchExecuteSubscriptions(subs);

        assertEq(usdc.balanceOf(recipient), 300e6);
    }
}
