// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

contract VerifyScript is Script {
    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        console.log("Verifying contracts at:", proxyAddress);
    }
}
