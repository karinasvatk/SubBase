// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PlanModule} from "./modules/PlanModule.sol";
import {SubscriptionModule} from "./modules/SubscriptionModule.sol";

contract SubBaseV1 is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PlanModule,
    SubscriptionModule
{
    address internal _owner;

    modifier onlyOwner() virtual {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    function initialize(address usdcToken) public initializer {
        if (usdcToken == address(0)) revert InvalidUSDCAddress();

        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _owner = msg.sender;
        _usdc = usdcToken;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function owner() external view returns (address) {
        return _owner;
    }

    function usdc() external view returns (address) {
        return _usdc;
    }
}
