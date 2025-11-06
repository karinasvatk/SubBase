// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FuzzTest is Test {
    SubscriptionManagerUpgradeable public manager;
    address public usdc = address(0x1);

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

    function testFuzzCreateSubscription(
        address recipient,
        uint256 amount,
        uint256 interval
    ) public {
        vm.assume(recipient != address(0));
        vm.assume(amount > 0 && amount < type(uint96).max);
        vm.assume(interval > 0 && interval < 365 days);

        manager.createSubscription(recipient, amount, interval, "Fuzz");
        assertEq(manager.subscriptionCount(), 1);
    }
}
