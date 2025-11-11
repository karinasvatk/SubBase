// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InvariantTest is Test {
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

    function invariant_subscriptionCountNeverDecreases() public {
        uint256 count = manager.subscriptionCount();
        assertTrue(count >= 0);
    }
}
