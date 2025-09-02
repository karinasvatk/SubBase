// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionManagerUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC20Simple {
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
}

contract AccessControlTest is Test {
    SubscriptionManagerUpgradeable public manager;
    MockERC20Simple public usdc;

    address public admin = address(1);
    address public executor = address(2);
    address public user = address(3);

    function setUp() public {
        usdc = new MockERC20Simple();

        vm.prank(admin);
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
    }

    function testAdminHasAdminRole() public {
        assertTrue(manager.hasRole(manager.ADMIN_ROLE(), admin));
    }

    function testAdminHasExecutorRole() public {
        assertTrue(manager.hasRole(manager.EXECUTOR_ROLE(), admin));
    }

    function testGrantRole() public {
        vm.prank(admin);
        manager.grantRole(manager.EXECUTOR_ROLE(), executor);

        assertTrue(manager.hasRole(manager.EXECUTOR_ROLE(), executor));
    }

    function testRevokeRole() public {
        vm.prank(admin);
        manager.grantRole(manager.EXECUTOR_ROLE(), executor);

        vm.prank(admin);
        manager.revokeRole(manager.EXECUTOR_ROLE(), executor);

        assertFalse(manager.hasRole(manager.EXECUTOR_ROLE(), executor));
    }

    function testCannotGrantRoleWithoutAdmin() public {
        vm.prank(user);
        vm.expectRevert("Access denied");
        manager.grantRole(manager.EXECUTOR_ROLE(), executor);
    }
}
