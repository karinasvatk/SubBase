// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Access denied");
        _;
    }

    function hasRole(bytes32 role, address account)
        public
        view
        returns (bool)
    {
        return _roles[role][account];
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function grantRole(bytes32 role, address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        _revokeRole(role, account);
    }
}
